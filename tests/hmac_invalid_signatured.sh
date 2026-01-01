#!/bin/bash
<<<<<<< HEAD
set -euo pipefail

API_KEY="client-1"
SECRET="WRONG_SECRET"
URL="https://localhost:8443/hmac/hello"
=======

API_KEY="client-1"
SECRET="WRONG_SECRET"
URL="http://localhost:8000/hmac/hello"
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40

echo "[1] Tính chữ ký sai..."
TS=$(date +%s)
NONCE=$RANDOM
<<<<<<< HEAD

# SỬA NHẸ: body hash ổn định
BODY_HASH=$(printf "" | openssl dgst -sha256 -r | awk '{print $1}')

SIG=$(printf "GET\n/hmac/hello\n\n$TS\n$NONCE\n$BODY_HASH" \
      | openssl dgst -sha256 -hmac "$SECRET" -r | awk '{print $1}')

echo "[2] Gửi request..."
curl -k -i "$URL" \
=======
SIG=$(printf "GET\n/hmac/hello\n\n$TS\n$NONCE\n$(printf "" | openssl dgst -sha256 | awk '{print $2}')" \
      | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

echo "[2] Gửi request..."
curl -i "$URL" \
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40
  -H "X-Api-Key: $API_KEY" \
  -H "X-Timestamp: $TS" \
  -H "X-Nonce: $NONCE" \
  -H "X-Signature: $SIG"
