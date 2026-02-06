# Guia da Aplicacao (PT-BR)

Este guia mostra como usar o LinkLab no dia a dia, do zero ate a validacao de analytics.

## 1. Subir o ambiente

No diretorio do projeto:

```bash
make compose-up
```

URLs:
- Frontend: `http://localhost:8088`
- API: `http://localhost:8080`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`

## 2. Fluxo principal no Frontend

Abra `http://localhost:8088`.

### 2.1 Verificar saude da API
- No card superior, observe o status `API: ok`.
- Se aparecer `indisponivel`, veja a secao de troubleshooting.

### 2.2 Criar link curto
1. Em `Criar link curto`, informe uma URL longa.
2. Clique em `Encurtar`.
3. O app retorna o link no formato:
   - `http://localhost:8088/r/<codigo>`
4. Clique em `Copiar` para copiar o link curto.

### 2.3 Testar redirecionamento
- Abra o link curto gerado (`/r/<codigo>`).
- O navegador deve redirecionar para a URL original.

### 2.4 Consultar analytics
1. No bloco `Consultar stats`, informe o codigo.
2. Clique em `Buscar`.
3. Campos principais do retorno:
   - `code`: codigo curto
   - `url`: URL original
   - `clicks`: total de cliques
   - `last_click`: ultimo clique registrado

## 3. Fluxo via CLI (opcional)

```bash
bash cli/linklab.sh health
bash cli/linklab.sh shorten https://exemplo.com
bash cli/linklab.sh stats <codigo>
```

## 4. Fluxo via API (opcional)

```bash
curl -s http://localhost:8080/health
curl -s -X POST http://localhost:8080/shorten -H "Content-Type: application/json" -d '{"url":"https://exemplo.com"}'
curl -s http://localhost:8080/stats/<codigo>
```

## 5. Observabilidade

### 5.1 Prometheus
- Acesse `http://localhost:9090`
- Query util:
  - `linklab_links_created_total`
  - `histogram_quantile(0.95, rate(linklab_redirect_duration_seconds_bucket[5m]))`

### 5.2 Grafana
- Acesse `http://localhost:3000` (usuario/senha: `admin` / `admin`)
- O datasource Prometheus ja vem provisionado automaticamente.

## 6. Validar Lambda + S3 local (LocalStack)

```bash
make localstack-status
make lambda-test
```

Se estiver ok, a resposta da Lambda retorna `statusCode: 200` e o objeto aparece no bucket local.

## 7. Troubleshooting rapido

### API indisponivel no frontend
```bash
docker-compose ps
docker-compose logs --tail=100 api frontend
```

### Erro no banco/worker
```bash
docker-compose logs --tail=100 postgres worker
```

### Reiniciar stack
```bash
make compose-down
make compose-up
```

## 8. Encerrar ambiente

```bash
make compose-down
```
