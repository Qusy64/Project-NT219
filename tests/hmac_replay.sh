#!/bin/bash
set -euo pipefail

API_KEY="client-1"
SECRET="super-secret-123"
URL="https://localhost:8443/hmac/hello"

TS=$(date +%s)
NONCE="replay123"

echo "[1] Tính chữ ký..."
BODY_HASH=$(printf "" | openssl dgst -sha256 -r | awk '{print $1}')
SIG=$(printf "GET\n/hmac/hello\n\n$TS\n$NONCE\n$BODY_HASH" \
      | openssl dgst -sha256 -hmac "$SECRET" -r | awk '{print $1}')

echo "[2] Gửi request lần 1..."
curl -k -i "$URL" -H "X-Api-Key: $API_KEY" -H "X-Timestamp: $TS" -H "X-Nonce: $NONCE" -H "X-Signature: $SIG"

echo
echo "[3] Gửi lại lần 2 (replay)..."
curl -k -i "$URL" -H "X-Api-Key: $API_KEY" -H "X-Timestamp: $TS" -H "X-Nonce: $NONCE" -H "X-Signature: $SIG"
