#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-linklab-kind}"
NAMESPACE="${NAMESPACE:-linklab}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "erro: comando '$1' nao encontrado" >&2
    exit 1
  fi
}

require_cmd docker
require_cmd kind
require_cmd kubectl
require_cmd helm

if ! kind get clusters | grep -qx "${CLUSTER_NAME}"; then
  kind create cluster --name "${CLUSTER_NAME}" --config "${ROOT_DIR}/k8s/profiles/kind/cluster.yaml"
fi

docker build -t linklab-api:local "${ROOT_DIR}/api"
docker build -t linklab-worker:local "${ROOT_DIR}/worker"

kind load docker-image linklab-api:local --name "${CLUSTER_NAME}"
kind load docker-image linklab-worker:local --name "${CLUSTER_NAME}"

kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install linklab "${ROOT_DIR}/k8s/helm/linklab" \
  --namespace "${NAMESPACE}" \
  -f "${ROOT_DIR}/k8s/helm/linklab/values.yaml" \
  -f "${ROOT_DIR}/k8s/helm/linklab/values-local.yaml"

kubectl -n "${NAMESPACE}" rollout status deploy/linklab-postgres --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deploy/linklab-redis --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deploy/linklab-api --timeout=180s
kubectl -n "${NAMESPACE}" rollout status deploy/linklab-worker --timeout=180s

echo "cluster kind pronto. API: http://localhost:8081/health"
