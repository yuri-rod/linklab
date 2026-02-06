# LinkLab - Documentacao PT-BR

Este repositorio contem um lab pratico de SRE/DevOps com:
- API em Go
- Worker em Python
- Frontend web (HTML/CSS/JS via Nginx)
- Banco PostgreSQL, Redis, LocalStack, Prometheus e Grafana
- Perfis Kubernetes locais com `kind` e `k3d`
- Fluxo GitOps local com Argo CD

Guias:
- Uso da aplicacao: `docs/GUIA-APP.pt-BR.md`
- Repositorio Git: `docs/GIT-REPO.pt-BR.md`

## 1. Subir tudo local com Docker

```bash
make compose-up
```

URLs principais:
- Frontend: `http://localhost:8088`
- API: `http://localhost:8080`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`
- LocalStack: `http://localhost:4566`

Para validar Lambda + S3 local:

```bash
make localstack-status
make lambda-test
```

Para desligar:

```bash
make compose-down
```

## 2. Kubernetes local

Profile `kind`:

```bash
make k8s-kind-up
make k8s-status
make k8s-smoke
make k8s-kind-down
```

Profile `k3d`:

```bash
make k8s-k3d-up
make k8s-status
make k8s-k3d-down
```

## 3. GitOps local (Argo CD)

```bash
REPO_URL=https://github.com/<seu-usuario>/linklab.git make gitops-bootstrap
make argocd-ui
make argocd-password
```

## 4. Frontend

O frontend local:
- usa `/api/*` para proxy da API Go
- usa `/r/<codigo>` para redirecionamento curto
- exibe status da API, cria links e consulta stats

Arquivos:
- `frontend/index.html`
- `frontend/styles.css`
- `frontend/app.js`
- `frontend/nginx.conf`
