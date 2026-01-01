#!/bin/bash
set -euo pipefail

API_KEY="client-1"
SECRET="WRONG_SECRET"
URL="https://localhost:8443/hmac/hello"

echo "[1] Tính chữ ký sai..."
TS=$(date +%s)
NONCE=$RANDOM

# SỬA NHẸ: body hash ổn định
BODY_HASH=$(printf "" | openssl dgst -sha256 -r | awk '{print $1}')

SIG=$(printf "GET\n/hmac/hello\n\n$TS\n$NONCE\n$BODY_HASH" \
      | openssl dgst -sha256 -hmac "$SECRET" -r | awk '{print $1}')

echo "[2] Gửi request..."
curl -k -i "$URL" \
  -H "X-Api-Key: $API_KEY" \
  -H "X-Timestamp: $TS" \
  -H "X-Nonce: $NONCE" \
  -H "X-Signature: $SIG"
