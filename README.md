# LinkLab — Encurtador de Links + Analytics

Projeto hands-on baseado no guia "LAB SRE / DEVOPS". Inclui API em Go, worker de analytics em Python, frontend web, CLI em Bash, Lambda de preview, manifests Kubernetes, Helm chart, Terraform/Terragrunt, Ansible e Packer.

## Rodar tudo local (sem AWS)
1. Suba o stack completo:
   ```bash
   make compose-up
   ```
2. (Opcional) garanta as tabelas:
   ```bash
   make db-init
   ```
3. Teste API + worker:
   ```bash
   bash cli/linklab.sh shorten https://exemplo.com
   curl -I http://localhost:8080/<CODIGO>
   ```
4. Verifique LocalStack (S3 + Lambda local):
   ```bash
   make localstack-status
   make lambda-test
   ```
5. Derrube tudo:
   ```bash
   make compose-down
   ```

## URLs locais
- Frontend: `http://localhost:8088`
- API: `http://localhost:8080`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000` (`admin` / `admin`)
- LocalStack (AWS local): `http://localhost:4566`

## Serviços
- **API (Go)**: endpoints `/shorten`, `/health`, `/stats/{code}`, redirect `/<code>`. Usa PostgreSQL e Redis.
- **Worker (Python)**: consome lista `clicks` no Redis e grava eventos na tabela `clicks`.
- **CLI (Bash)**: wrapper para chamar a API (`shorten`, `stats`, `health`).
- **Frontend (Nginx + JS)**: interface web local para encurtar links e consultar stats.
- **Lambda (Python)**: gera preview e grava no bucket S3 local (LocalStack).
- **Prometheus**: coleta métricas da API (`/metrics`) e aplica regras de alerta.
- **Grafana**: dashboard local com datasource Prometheus provisionado automaticamente.
- **LocalStack**: emula S3/Lambda para continuar o lab sem conta AWS disponível.

## Docker Compose
Arquivo `docker-compose.yml` fornece o stack local completo. Imagens são construídas automaticamente no `make compose-up`.

## Documentacao PT-BR
- Guia principal: `docs/README.pt-BR.md`
- Guia da aplicacao: `docs/GUIA-APP.pt-BR.md`
- Guia Git: `docs/GIT-REPO.pt-BR.md`

## Mapeamento AWS -> Local
- **RDS PostgreSQL** -> container `postgres`
- **ElastiCache Redis** -> container `redis`
- **Lambda** -> LocalStack Lambda (`linklab-preview`)
- **S3** -> LocalStack S3 (`linklab-previews`)
- **CloudWatch/Prometheus stack** -> `prometheus` + `grafana`
- **ECR (build local)** -> imagens Docker locais

## Kubernetes Local (Fases 4-7)
### Pré-requisitos
- `docker`
- `kubectl`
- `helm`
- `kind` ou `k3d`

### Profile `kind`
1. Suba cluster + deploy Helm local:
   ```bash
   make k8s-kind-up
   ```
2. Verifique workloads:
   ```bash
   make k8s-status
   ```
3. Smoke test:
   ```bash
   make k8s-smoke
   ```
4. Derrube cluster:
   ```bash
   make k8s-kind-down
   ```

### Profile `k3d`
1. Suba cluster + deploy Helm local:
   ```bash
   make k8s-k3d-up
   ```
2. Verifique workloads:
   ```bash
   make k8s-status
   ```
3. Derrube cluster:
   ```bash
   make k8s-k3d-down
   ```

### GitOps local (Argo CD)
1. Instale Argo CD e aplique Application:
   ```bash
   REPO_URL=https://github.com/<user>/linklab.git make gitops-bootstrap
   ```
2. Abra a UI:
   ```bash
   make argocd-ui
   ```
3. Pegue senha inicial:
   ```bash
   make argocd-password
   ```

Notas:
- O profile local usa `k8s/helm/linklab/values-local.yaml`.
- `values-local.yaml` habilita PostgreSQL e Redis dentro do cluster.
- API local no Kubernetes fica em `http://localhost:8081`.

## Kubernetes / EKS (Fases 4-5)
- Manifests crús em `k8s/*.yaml`.
- Chart Helm em `k8s/helm/linklab` com `values-dev.yaml`, `values-prod.yaml` e `values-local.yaml`.
- Exemplo de VirtualService Istio em `k8s/istio/virtual-service.yaml`.
- Argo CD Application em `k8s/argocd/linklab-app.yaml`, profile local em `k8s/argocd/linklab-app-local.yaml`, e Crossplane S3 em `k8s/crossplane/s3-bucket.yaml`.

## IaC (Fase 6)
- Módulos Terraform em `infra/modules` para VPC, EKS, RDS, S3, Lambda, ECR.
- Terragrunt em `infra/environments/{dev,prod}`. Rode, por exemplo:
  ```bash
  cd infra/environments/dev/vpc && terragrunt apply
  ```

## Observabilidade (Fase 8)
- Alertas Prometheus em `monitoring/alerts.yaml`.
- Config Thanos S3 em `monitoring/thanos-s3.yaml`.

## CI/CD (Fase 7)
- GitHub Actions pipeline em `.github/workflows/ci.yml` (testes Go/Python, build e push para ECR, atualização de Helm).

## Variáveis / Credenciais
- API/Worker esperam `DATABASE_URL` e `REDIS_URL`.
- Lambda local aceita `AWS_ENDPOINT_URL`/`S3_ENDPOINT_URL` para apontar para LocalStack/MinIO.
- Helm/K8s usam Secret `linklab-secrets` (substitua valores antes de aplicar).
- Substitua `REPLACE_ECR` e `REPLACE_USER` nos manifests com seu registry e repositório.

## Próximos passos
- Quando AWS estiver disponível, mover para módulos Terraform em `infra/modules`.
- Popular secrets no cluster e atualizar `values*.yaml` com URLs reais do RDS/ElastiCache.
- Trocar endpoint LocalStack por S3/Lambda reais no deploy cloud.
