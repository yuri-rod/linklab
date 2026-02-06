#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_URL="${REPO_URL:-}"
REVISION="${REVISION:-main}"

if [[ -z "${REPO_URL}" ]]; then
  echo "erro: defina REPO_URL com a URL do seu repo Git (ex.: https://github.com/<user>/linklab.git)" >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "erro: comando 'kubectl' nao encontrado" >&2
  exit 1
fi

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd wait deploy/argocd-server --for=condition=available --timeout=300s

app_file="$(mktemp)"
sed \
  -e "s#REPLACE_REPO_URL#${REPO_URL}#g" \
  -e "s#REPLACE_REVISION#${REVISION}#g" \
  "${ROOT_DIR}/k8s/argocd/linklab-app-local.yaml" > "${app_file}"
kubectl apply -f "${app_file}"
rm -f "${app_file}"

echo "argocd pronto."
echo "UI: kubectl -n argocd port-forward svc/argocd-server 8082:80"
echo "Senha inicial: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
