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
<<<<<<< HEAD
curl -k -i -H "Authorization: Bearer $TOKEN" https://localhost:8443/api/hello
=======
curl -i -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/hello
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40
