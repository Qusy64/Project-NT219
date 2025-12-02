<<<<<<< HEAD
#!/usr/bin/env bash
set -euo pipefail

REALM="secure"
KC_HOST="localhost:8080"   # Keycloak publish ra host

# Client dùng để LẤY TOKEN + REVOKE (phải là confidential client, có client secret)
CLIENT_ID="backend-service-id"
CLIENT_SECRET="7Ylsarb9Fbz7Q4hBbQQuMcXzyWdEo9cR"

# User demo để test password grant
=======
#!/bin/bash
set -e

REALM="secure"
KC_HOST="localhost:8080"   # Keycloak publish ra host
CLIENT_ID="backend-service-id"
CLIENT_SECRET="7Ylsarb9Fbz7Q4hBbQQuMcXzyWdEo9cR"

# ĐIỀN user demo của bạn ở đây
>>>>>>> e121e45603e7969203ed06f36fc56209dcf99d20
USERNAME="user1-demo-token-revocation"
PASSWORD="user1-demo"

BASE_URL="http://$KC_HOST/realms/$REALM/protocol/openid-connect"
<<<<<<< HEAD
TOKEN_ENDPOINT="$BASE_URL/token"
REVOCATION_ENDPOINT="$BASE_URL/revoke"
USERINFO_ENDPOINT="$BASE_URL/userinfo"

echo "[1] Lấy access token..."
RESP=$(curl -s -X POST "$TOKEN_ENDPOINT" \
=======
API_URL="http://localhost:8000/revocation-demo"

echo "[1] Lấy access token..."
RESP=$(curl -s -X POST "$BASE_URL/token" \
>>>>>>> e121e45603e7969203ed06f36fc56209dcf99d20
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD" \
  -d "scope=openid")

<<<<<<< HEAD
# Debug nếu cần
# echo "[DEBUG] TOKEN RESPONSE = $RESP"

ACCESS_TOKEN=$(echo "$RESP" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo
  echo "[ERROR] Không lấy được access token, RESP:"
=======
# echo "$RESP"      # cho dễ debug nếu cần
ACCESS_TOKEN=$(echo "$RESP" | jq -r '.access_token')
if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo
  echo "Không lấy được access token, RESP ở trên."
  exit 1
fi


if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Không lấy được access token, RESP:"
>>>>>>> e121e45603e7969203ed06f36fc56209dcf99d20
  echo "$RESP"
  exit 1
fi

<<<<<<< HEAD
echo "[DEBUG] ACCESS_TOKEN (rút gọn) = ${ACCESS_TOKEN:0:30}..."
echo

echo "[2] Gọi Keycloak /userinfo trước khi revoke (expect 200)..."
curl -i "$USERINFO_ENDPOINT" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
=======
echo
echo "[2] Gọi API trước khi revoke (expect 200)..."
curl -i -H "Authorization: Bearer $ACCESS_TOKEN" "$API_URL"
>>>>>>> e121e45603e7969203ed06f36fc56209dcf99d20
echo
echo

echo "[3] Revoke access token bên Keycloak..."
<<<<<<< HEAD
curl -i -X POST "$REVOCATION_ENDPOINT" \
=======
curl -i -X POST "$BASE_URL/revoke" \
>>>>>>> e121e45603e7969203ed06f36fc56209dcf99d20
  -u "$CLIENT_ID:$CLIENT_SECRET" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=$ACCESS_TOKEN" \
  -d "token_type_hint=access_token"
echo
echo

<<<<<<< HEAD
echo "[4] Gọi lại /userinfo với cùng token (expect 401/403 hoặc error)..."
curl -i "$USERINFO_ENDPOINT" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
=======
echo "[4] Gọi lại API với cùng token (expect 401 vì đã revoke)..."
curl -i -H "Authorization: Bearer $ACCESS_TOKEN" "$API_URL"
>>>>>>> e121e45603e7969203ed06f36fc56209dcf99d20
echo
