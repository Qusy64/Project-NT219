#!/bin/bash

echo "[1] Get valid token..."
RAW=$(curl -s \
  -d "client_id=api-client" \
  -d "client_secret=api-secret" \
  -d "grant_type=client_credentials" \
  http://localhost:8080/realms/secure/protocol/openid-connect/token)

TOKEN=$(echo $RAW | jq -r .access_token)

echo "[2] Modify audience..."
HEADER=$(echo $TOKEN | cut -d . -f1)
PAYLOAD=$(echo $TOKEN | cut -d . -f2 | base64 -d | jq '.aud="wrong-audience"' | base64 -w 0)

FORGED="$HEADER.$PAYLOAD.fake"

echo "[3] Call API with wrong audience..."
<<<<<<< HEAD
curl -k -i -H "Authorization: Bearer $FORGED" https://localhost:8443/api/hello
=======
curl -i -H "Authorization: Bearer $FORGED" http://localhost:8000/api/hello
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40
