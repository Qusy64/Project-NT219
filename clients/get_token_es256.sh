#!/usr/bin/env bash
set -euo pipefail

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
