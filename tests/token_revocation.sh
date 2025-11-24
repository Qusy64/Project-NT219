#!/bin/bash
set -e

REALM="secure"
KC_HOST="localhost:8080"   # Keycloak publish ra host
CLIENT_ID="backend-service-id"
CLIENT_SECRET="7Ylsarb9Fbz7Q4hBbQQuMcXzyWdEo9cR"

# ĐIỀN user demo của bạn ở đây
USERNAME="user1-demo-token-revocation"
PASSWORD="user1-demo"

BASE_URL="http://$KC_HOST/realms/$REALM/protocol/openid-connect"
API_URL="http://localhost:8000/revocation-demo"

echo "[1] Lấy access token..."
RESP=$(curl -s -X POST "$BASE_URL/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD" \
  -d "scope=openid")

# echo "$RESP"      # cho dễ debug nếu cần
ACCESS_TOKEN=$(echo "$RESP" | jq -r '.access_token')
if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo
  echo "Không lấy được access token, RESP ở trên."
  exit 1
fi


if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Không lấy được access token, RESP:"
  echo "$RESP"
  exit 1
fi

echo
echo "[2] Gọi API trước khi revoke (expect 200)..."
curl -i -H "Authorization: Bearer $ACCESS_TOKEN" "$API_URL"
echo
echo

echo "[3] Revoke access token bên Keycloak..."
curl -i -X POST "$BASE_URL/revoke" \
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=$ACCESS_TOKEN" \
  -d "token_type_hint=access_token"
echo
echo

echo "[4] Gọi lại API với cùng token (expect 401 vì đã revoke)..."
curl -i -H "Authorization: Bearer $ACCESS_TOKEN" "$API_URL"
echo
