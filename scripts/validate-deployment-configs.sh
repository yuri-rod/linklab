#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERRORS=0

echo "==> Validating LinkLab deployment configurations..."

# 1. Terragrunt fail-closed validation
TERRAGRUNT_FILE="$ROOT_DIR/infra/environments/dev/rds/terragrunt.hcl"
if [ -f "$TERRAGRUNT_FILE" ]; then
    if grep -E 'get_env\("DB_PASSWORD",\s*".*"\)' "$TERRAGRUNT_FILE" >/dev/null; then
        echo "FAIL: Terragrunt still has a fallback default password in $TERRAGRUNT_FILE"
        ERRORS=$((ERRORS + 1))
    elif grep 'get_env("DB_PASSWORD")' "$TERRAGRUNT_FILE" >/dev/null; then
        echo "PASS: Terragrunt requires DB_PASSWORD environment variable (fail closed)"
    else
        echo "FAIL: Terragrunt does not reference DB_PASSWORD properly in $TERRAGRUNT_FILE"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 2. Docker Compose fail-closed validation
DOCKER_COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
    if grep -E 'POSTGRES_PASSWORD:\s*\$\{POSTGRES_PASSWORD:\?' "$DOCKER_COMPOSE_FILE" >/dev/null \
       && grep -E 'DATABASE_URL:\s*\$\{DATABASE_URL:\?' "$DOCKER_COMPOSE_FILE" >/dev/null; then
        echo "PASS: Docker Compose enforces required environment variables with :? (fail closed)"
    else
        echo "FAIL: Docker Compose does not enforce required environment variables"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 3. Helm templates and values fail-closed validation
HELM_DIR="$ROOT_DIR/k8s/helm/linklab"
if [ -d "$HELM_DIR" ]; then
    if grep -E 'required.*databaseURL' "$HELM_DIR/templates/api-deployment.yaml" >/dev/null \
       && grep -E 'required.*databaseURL' "$HELM_DIR/templates/worker-deployment.yaml" >/dev/null; then
        echo "PASS: Helm templates enforce required databaseURL (fail closed)"
    else
        echo "FAIL: Helm templates do not enforce required databaseURL"
        ERRORS=$((ERRORS + 1))
    fi

    if grep -E 'databaseURL:\s*"postgres://linklab:linklab123' "$HELM_DIR/values.yaml" >/dev/null \
       || grep -E 'databaseURL:\s*"postgres://linklab:linklab123' "$HELM_DIR/values-dev.yaml" >/dev/null; then
        echo "FAIL: Helm values still contain hardcoded test credentials"
        ERRORS=$((ERRORS + 1))
    else
        echo "PASS: Helm base and dev values contain no hardcoded credentials"
    fi
fi

# 4. Kubernetes Secret manifest validation
K8S_SECRET_FILE="$ROOT_DIR/k8s/secrets.yaml"
if [ -f "$K8S_SECRET_FILE" ]; then
    if grep -E 'CHANGEME|linklab123' "$K8S_SECRET_FILE" >/dev/null; then
        echo "FAIL: $K8S_SECRET_FILE still contains committed placeholder or test credentials"
        ERRORS=$((ERRORS + 1))
    else
        echo "PASS: Kubernetes Secret manifest contains no committed credentials or raw placeholders"
    fi
fi

if [ "$ERRORS" -gt 0 ]; then
    echo "==> Validation failed with $ERRORS error(s)"
    exit 1
fi

echo "==> All deployment configuration validation checks passed successfully."
exit 0
