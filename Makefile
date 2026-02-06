COMPOSE ?= docker-compose
AWS_LOCAL ?= AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localhost:4566
KIND_CLUSTER_NAME ?= linklab-kind
K3D_CLUSTER_NAME ?= linklab
K8S_NAMESPACE ?= linklab
REVISION ?= main

compose-up:
	$(COMPOSE) down --remove-orphans >/dev/null 2>&1 || true
	$(COMPOSE) up -d --build

compose-down:
	$(COMPOSE) down -v

compose-logs:
	$(COMPOSE) logs -f --tail=100

api-test:
	cd api && go test ./...

worker-lint:
	cd worker && python3 -m compileall .

db-init:
	$(COMPOSE) exec -T postgres psql -U linklab -d linklab < sql/init.sql

localstack-status:
	$(AWS_LOCAL) s3 ls
	$(AWS_LOCAL) lambda list-functions --query "Functions[].FunctionName" --output text

lambda-test:
	$(AWS_LOCAL) lambda invoke \
		--function-name linklab-preview \
		--cli-binary-format raw-in-base64-out \
		--payload '{"body":"{\"url\":\"https://example.com\",\"code\":\"demo\"}"}' \
		/tmp/linklab-lambda-response.json >/dev/null
	cat /tmp/linklab-lambda-response.json; echo
	$(AWS_LOCAL) s3api list-objects-v2 --bucket linklab-previews --prefix previews/ --query "Contents[].Key" --output text

k8s-kind-up:
	CLUSTER_NAME=$(KIND_CLUSTER_NAME) NAMESPACE=$(K8S_NAMESPACE) ./scripts/k8s/kind-up.sh

k8s-kind-down:
	CLUSTER_NAME=$(KIND_CLUSTER_NAME) ./scripts/k8s/kind-down.sh

k8s-k3d-up:
	CLUSTER_NAME=$(K3D_CLUSTER_NAME) NAMESPACE=$(K8S_NAMESPACE) ./scripts/k8s/k3d-up.sh

k8s-k3d-down:
	CLUSTER_NAME=$(K3D_CLUSTER_NAME) ./scripts/k8s/k3d-down.sh

k8s-status:
	kubectl -n $(K8S_NAMESPACE) get pods,svc

k8s-smoke:
	curl -fsS http://localhost:8081/health

gitops-bootstrap:
	@test -n "$(REPO_URL)" || (echo "erro: use REPO_URL=https://github.com/<user>/linklab.git make gitops-bootstrap" && exit 1)
	REPO_URL=$(REPO_URL) REVISION=$(REVISION) ./scripts/k8s/gitops-bootstrap.sh

argocd-password:
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

argocd-ui:
	kubectl -n argocd port-forward svc/argocd-server 8082:80

.PHONY: compose-up compose-down compose-logs api-test worker-lint db-init localstack-status lambda-test \
	k8s-kind-up k8s-kind-down k8s-k3d-up k8s-k3d-down k8s-status k8s-smoke \
	gitops-bootstrap argocd-password argocd-ui
