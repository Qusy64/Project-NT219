#!/bin/bash

API_KEY="client-1"
SECRET="super-secret-123"
URL="http://localhost:8000/hmac/hello"

TS=$(date +%s)
NONCE="replay123"

echo "[1] Tính chữ ký..."
SIG=$(printf "GET\n/hmac/hello\n\n$TS\n$NONCE\n$(printf "" | openssl dgst -sha256 | awk '{print $2}')" \
      | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

echo "[2] Gửi request lần 1..."
curl -i "$URL" -H "X-Api-Key: $API_KEY" -H "X-Timestamp: $TS" -H "X-Nonce: $NONCE" -H "X-Signature: $SIG"

echo
echo "[3] Gửi lại lần 2 (replay)..."
curl -i "$URL" -H "X-Api-Key: $API_KEY" -H "X-Timestamp: $TS" -H "X-Nonce: $NONCE" -H "X-Signature: $SIG"
