#!/bin/bash

echo "[1] Get token..."
TOKEN=$(curl -s \
  -d "client_id=api-client" \
  -d "client_secret=api-secret" \
  -d "grant_type=client_credentials" \
  http://localhost:8080/realms/secure/protocol/openid-connect/token \
  | jq -r .access_token)

echo "Token: $TOKEN"
echo "[2] Sleeping 65s for token to expire..."
sleep 65

echo "[3] Calling API..."
curl -i -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/hello
