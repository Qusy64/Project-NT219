#!/bin/bash

echo "[1] Get token normally..."
RAW=$(curl -s \
  -d "client_id=api-client" \
  -d "client_secret=api-secret" \
  -d "grant_type=client_credentials" \
  http://localhost:8080/realms/secure/protocol/openid-connect/token)

TOKEN=$(echo $RAW | jq -r .access_token)

echo "[2] Decode payload and modify iss..."
HEADER=$(echo $TOKEN | cut -d . -f1)
PAYLOAD=$(echo $TOKEN | cut -d . -f2 | base64 -d | jq '.iss="https://fake-issuer"' | base64 -w 0)

# Signature không còn hợp lệ (故意)
FORGED="$HEADER.$PAYLOAD.fake"

echo "[3] Call API with wrong issuer..."
curl -k -i -H "Authorization: Bearer $FORGED" https://localhost:8443/api/hello
