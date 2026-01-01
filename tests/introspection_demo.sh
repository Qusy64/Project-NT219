#!/usr/bin/env bash
set -euo pipefail

REALM="secure"
<<<<<<< HEAD
KC_HOST="localhost:8080"   # SỬA: Keycloak vẫn HTTP như cũ
=======
KC_HOST="localhost:8080"
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40
CLIENT_ID="backend-service-id"
CLIENT_SECRET="7Ylsarb9Fbz7Q4hBbQQuMcXzyWdEo9cR"

USERNAME="user1-demo-token-revocation"
PASSWORD="user1-demo"

<<<<<<< HEAD
BASE_URL="http://$KC_HOST/realms/$REALM/protocol/openid-connect"   # SỬA: http
=======
BASE_URL="http://$KC_HOST/realms/$REALM/protocol/openid-connect"
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40
TOKEN_ENDPOINT="$BASE_URL/token"
INTROSPECT_ENDPOINT="$BASE_URL/token/introspect"

echo "[1] Lấy access token..."
RESP=$(curl -s -X POST "$TOKEN_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD" \
  -d "scope=openid")

echo "[DEBUG] RAW TOKEN RESP = $RESP"
ACCESS_TOKEN=$(echo "$RESP" | jq -r '.access_token')
if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "[ERROR] Không lấy được access token"
  exit 1
fi

echo "[DEBUG] ACCESS_TOKEN (rút gọn) = ${ACCESS_TOKEN:0:30}..."
echo

echo "[2] Gọi /token/introspect với token đúng (expect active=true nếu config ok)..."
curl -s -X POST "$INTROSPECT_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "token=$ACCESS_TOKEN" | jq .
echo
echo

BAD_TOKEN="${ACCESS_TOKEN}X"
echo "[3] Gọi /token/introspect với token sai (expect active=false)..."
curl -s -X POST "$INTROSPECT_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "token=$BAD_TOKEN" | jq .
echo
