#!/usr/bin/env bash
set -euo pipefail

KONG_API_URL="http://localhost:8002/api"
<<<<<<< HEAD
TOKEN_ES256=$(./get_token_es256.sh)
=======
TOKEN_ES256=$(clients/get_token_es256.sh)
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40

echo "[1/3] TOKEN_ES256: ${TOKEN_ES256:0:50}..."

echo "[2/3] Gọi API qua Kong..."
curl -i "${KONG_API_URL}" \
  -H "Authorization: Bearer ${TOKEN_ES256}" \
  -H "Accept: application/json"

echo ""
echo "[3/3] Hoàn tất"
