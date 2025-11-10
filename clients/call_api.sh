#!/usr/bin/env bash
set -euo pipefail

# Config

REALM="secure"
KC_URL="http://localhost:8080/realms/${REALM}"
KC_TOKEN_URL="${KC_URL}/protocol/openid-connect/token"
CLIENT_ID="api-client"
CLIENT_SECRET="api-secret"
KONG_API_URL="http://localhost:8002/api"

# Lấy Access Token (Client Credentials)
echo "[1/3] Requesting access token from Keycloak..."

ACCESS_TOKEN=$(curl -s -X POST "$KC_TOKEN_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" | jq -r '.access_token')

if [[ -z "${ACCESS_TOKEN}" || "${ACCESS_TOKEN}" == "null" ]]; then
  echo " Failed to get access token. Check Keycloak or client credentials."
  exit 1
fi

echo "[2/3] Got token successfully"
echo "      (truncated) $(echo "${ACCESS_TOKEN}" | cut -c1-40)..."

# Gọi API qua Kong Gateway

echo "[3/3] Calling API via Kong..."
curl -i "${KONG_API_URL}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json"

echo ""
echo "Done"
