#!/usr/bin/env bash
set -euo pipefail

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
