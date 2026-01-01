#!/usr/bin/env bash
set -euo pipefail

<<<<<<< HEAD
REALM="secure"
KC_URL="http://localhost:8080"
CLIENT_ID="api-client-ES256"
CLIENT_SECRET="q0kdlxMjNWreaEMVGXqcC1WJEmpo9sfK"

RESP=$(curl -s \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" \
  "${KC_URL}/realms/${REALM}/protocol/openid-connect/token")

ACCESS_TOKEN=$(echo "$RESP" | jq -r '.access_token // empty')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "[ERROR] Keycloak did not return access_token. Full response:" >&2
  echo "$RESP" | jq -r '.' >&2 || echo "$RESP" >&2
  exit 1
fi

echo "$ACCESS_TOKEN"
=======
REALM="secure"             # sửa lại đúng tên realm của bạn
KC_URL="http://localhost:8080"

CLIENT_ID="api-client-ES256"   # ĐÚNG tên client mới tạo
CLIENT_SECRET="q0kdlxMjNWreaEMVGXqcC1WJEmpo9sfK"  # DÁN secret lấy ở tab Credentials

TOKEN=$(curl -s \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "grant_type=client_credentials" \
  "${KC_URL}/realms/${REALM}/protocol/openid-connect/token" \
  | jq -r .access_token)

echo "$TOKEN"
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40
