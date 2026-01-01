#!/bin/bash

API_KEY="client-1"
SECRET="super-secret-123"
URL="https://localhost:8443/hmac/hello"

echo "[1] Tính chữ ký..."
TS=$(date +%s)
NONCE=$RANDOM
SIG=$(printf "GET\n/hmac/hello\n\n$TS\n$NONCE\n$(printf "" | openssl dgst -sha256 | awk '{print $2}')" \
      | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

echo "[2] Gửi request..."
curl -k -i "$URL" \
  -H "X-Api-Key: $API_KEY" \
  -H "X-Timestamp: $TS" \
  -H "X-Nonce: $NONCE" \
  -H "X-Signature: $SIG"
