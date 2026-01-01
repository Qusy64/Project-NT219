#!/usr/bin/env bash
set -euo pipefail

KONG_API_URL="http://localhost:8002/api"
TOKEN_ES256=$(./get_token_es256.sh)

echo "[1/3] TOKEN_ES256: ${TOKEN_ES256:0:50}..."

echo "[2/3] Gọi API qua Kong..."
curl -i "${KONG_API_URL}" \
  -H "Authorization: Bearer ${TOKEN_ES256}" \
  -H "Accept: application/json"

echo ""
echo "[3/3] Hoàn tất"
