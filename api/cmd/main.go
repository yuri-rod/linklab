package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"log"
	"math/rand"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/lib/pq"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/redis/go-redis/v9"
)

var (
	db  *sql.DB
	rdb *redis.Client

	linksCreated = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "linklab_links_created_total",
		Help: "Total de links encurtados",
	})

	redirectLatency = prometheus.NewHistogram(prometheus.HistogramOpts{
		Name:    "linklab_redirect_duration_seconds",
		Help:    "Latência dos redirects",
		Buckets: []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1},
	})
)

type shortenRequest struct {
	URL string `json:"url"`
}

type shortenResponse struct {
	Short string `json:"short"`
	URL   string `json:"url"`
}

type statsResponse struct {
	Code      string     `json:"code"`
	URL       string     `json:"url"`
	CreatedAt *time.Time `json:"created_at"`
	Clicks    int64      `json:"clicks"`
	LastClick *time.Time `json:"last_click"`
}

func main() {
	prometheus.MustRegister(linksCreated, redirectLatency)

	var err error
	db, err = sql.Open("postgres", mustGetEnv("DATABASE_URL"))
	if err != nil {
		log.Fatalf("failed to open database: %v", err)
	}
	db.SetMaxOpenConns(10)
	db.SetConnMaxLifetime(5 * time.Minute)

	if err = db.Ping(); err != nil {
		log.Fatalf("failed to ping database: %v", err)
	}

	rdb = newRedisClient(mustGetEnv("REDIS_URL"))
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		log.Fatalf("failed to connect to redis: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", handleHealth)
	mux.HandleFunc("/shorten", handleShorten)
	mux.HandleFunc("/stats/", handleStats)
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/", handleRedirect)

	srv := &http.Server{
		Addr:         ":8080",
		Handler:      mux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	log.Println("API rodando na porta 8080")
	log.Fatal(srv.ListenAndServe())
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func handleShorten(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "use POST", http.StatusMethodNotAllowed)
		return
	}

	var req shortenRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "corpo inválido", http.StatusBadRequest)
		return
	}
	req.URL = strings.TrimSpace(req.URL)
	if req.URL == "" {
		http.Error(w, "url obrigatória", http.StatusBadRequest)
		return
	}

	code, err := createShortLink(r.Context(), req.URL)
	if err != nil {
		log.Printf("erro ao encurtar: %v", err)
		http.Error(w, "erro ao salvar", http.StatusInternalServerError)
		return
	}

	linksCreated.Inc()
	writeJSON(w, shortenResponse{Short: code, URL: req.URL}, http.StatusOK)
}

func handleRedirect(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	code := strings.Trim(strings.TrimPrefix(r.URL.Path, "/"), " ")
	if code == "" || code == "favicon.ico" || strings.HasPrefix(code, "metrics") || strings.HasPrefix(code, "health") || strings.HasPrefix(code, "stats") {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("linklab api"))
		return
	}

	url, err := fetchURL(r.Context(), code)
	if errors.Is(err, sql.ErrNoRows) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		log.Printf("erro ao buscar url: %v", err)
		http.Error(w, "erro interno", http.StatusInternalServerError)
		return
	}

	if err := rdb.LPush(r.Context(), "clicks", code).Err(); err != nil {
		log.Printf("erro ao enfileirar click: %v", err)
	}

	http.Redirect(w, r, url, http.StatusMovedPermanently)
	redirectLatency.Observe(time.Since(start).Seconds())
}

func handleStats(w http.ResponseWriter, r *http.Request) {
	code := strings.TrimPrefix(r.URL.Path, "/stats/")
	if code == "" {
		http.Error(w, "code obrigatório", http.StatusBadRequest)
		return
	}

	stat, err := fetchStats(r.Context(), code)
	if errors.Is(err, sql.ErrNoRows) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		log.Printf("erro ao buscar stats: %v", err)
		http.Error(w, "erro interno", http.StatusInternalServerError)
		return
	}

	writeJSON(w, stat, http.StatusOK)
}

func createShortLink(ctx context.Context, url string) (string, error) {
	for i := 0; i < 5; i++ {
		code := generateCode(6)
		_, err := db.ExecContext(ctx,
			"INSERT INTO links (code, url, created_at) VALUES ($1, $2, $3)",
			code, url, time.Now(),
		)
		if err == nil {
			return code, nil
		}
		if pqErr, ok := err.(*pq.Error); ok && pqErr.Code == "23505" {
			continue // collision, try again
		}
		return "", err
	}
	return "", errors.New("falha ao gerar código único")
}

func fetchURL(ctx context.Context, code string) (string, error) {
	var url string
	err := db.QueryRowContext(ctx, "SELECT url FROM links WHERE code=$1", code).Scan(&url)
	return url, err
}

func fetchStats(ctx context.Context, code string) (*statsResponse, error) {
	var res statsResponse
	res.Code = code
	err := db.QueryRowContext(ctx,
		"SELECT url, created_at FROM links WHERE code=$1", code,
	).Scan(&res.URL, &res.CreatedAt)
	if err != nil {
		return nil, err
	}

	err = db.QueryRowContext(ctx,
		"SELECT COUNT(*), MAX(clicked_at) FROM clicks WHERE code=$1",
		code,
	).Scan(&res.Clicks, &res.LastClick)
	if err != nil {
		return nil, err
	}

	return &res, nil
}

func writeJSON(w http.ResponseWriter, v interface{}, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func generateCode(n int) string {
	const chars = "abcdefghijkmnpqrstuvwxyz23456789"
	rand.Seed(time.Now().UnixNano())
	b := make([]byte, n)
	for i := range b {
		b[i] = chars[rand.Intn(len(chars))]
	}
	return string(b)
}

func newRedisClient(url string) *redis.Client {
	opt, err := redis.ParseURL(url)
	if err != nil {
		// fallback: if user passed host:port
		opt = &redis.Options{Addr: url}
	}
	return redis.NewClient(opt)
}

func mustGetEnv(key string) string {
	val := strings.TrimSpace(os.Getenv(key))
	if val == "" {
		log.Fatalf("variável de ambiente %s não definida", key)
	}
	return val
}
