#!/bin/sh
set -e

echo "[localstack-init] waiting for APIs..."
awslocal sts get-caller-identity >/dev/null

echo "[localstack-init] creating S3 bucket..."
awslocal s3api create-bucket --bucket linklab-previews >/dev/null 2>&1 || true

echo "[localstack-init] packaging lambda..."
python3 - <<'PY'
import zipfile

with zipfile.ZipFile("/tmp/linklab-preview.zip", "w") as zf:
    zf.write("/workspace/lambda/handler.py", arcname="handler.py")
PY

echo "[localstack-init] deploying lambda..."
if awslocal lambda get-function --function-name linklab-preview >/dev/null 2>&1; then
  awslocal lambda update-function-code \
    --function-name linklab-preview \
    --zip-file fileb:///tmp/linklab-preview.zip >/dev/null
else
  awslocal lambda create-function \
    --function-name linklab-preview \
    --runtime python3.12 \
    --handler handler.handler \
    --role arn:aws:iam::000000000000:role/linklab-lambda-role \
    --timeout 15 \
    --memory-size 128 \
    --zip-file fileb:///tmp/linklab-preview.zip \
    --environment "Variables={BUCKET=linklab-previews,AWS_ENDPOINT_URL=http://localstack:4566,AWS_REGION=us-east-1,AWS_ACCESS_KEY_ID=test,AWS_SECRET_ACCESS_KEY=test}" >/dev/null
fi

echo "[localstack-init] done."
