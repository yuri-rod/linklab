#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-linklab}"

if command -v k3d >/dev/null 2>&1; then
  if k3d cluster get "${CLUSTER_NAME}" >/dev/null 2>&1; then
    k3d cluster delete "${CLUSTER_NAME}"
  fi
fi
