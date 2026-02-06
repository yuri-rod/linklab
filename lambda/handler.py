import json
import os
import urllib.request

import boto3
from botocore.config import Config

S3_ENDPOINT_URL = os.environ.get("AWS_ENDPOINT_URL") or os.environ.get("S3_ENDPOINT_URL")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
BUCKET = os.environ.get("BUCKET", "linklab-previews")

client_kwargs = {
    "region_name": AWS_REGION,
    "config": Config(s3={"addressing_style": "path"}),
}
if S3_ENDPOINT_URL:
    client_kwargs["endpoint_url"] = S3_ENDPOINT_URL

s3 = boto3.client("s3", **client_kwargs)


def handler(event, context):
    try:
        body = event.get("body")
        if isinstance(body, str):
            body = json.loads(body)
        url = body["url"]
        code = body["code"]
    except Exception as exc:  # noqa: BLE001
        return {"statusCode": 400, "body": f"payload inválido: {exc}"}

    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            html = resp.read().decode(errors="ignore")[:5000]
    except Exception as exc:  # noqa: BLE001
        return {"statusCode": 500, "body": str(exc)}

    s3.put_object(
        Bucket=BUCKET,
        Key=f"previews/{code}.json",
        Body=json.dumps({"url": url, "code": code, "preview": html}),
    )

    return {"statusCode": 200, "body": "ok"}
