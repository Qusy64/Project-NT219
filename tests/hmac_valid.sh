#!/bin/bash

API_KEY="client-1"
SECRET="super-secret-123"
<<<<<<< HEAD
URL="https://localhost:8443/hmac/hello"
=======
URL="http://localhost:8000/hmac/hello"
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40

echo "[1] Tính chữ ký..."
TS=$(date +%s)
NONCE=$RANDOM
SIG=$(printf "GET\n/hmac/hello\n\n$TS\n$NONCE\n$(printf "" | openssl dgst -sha256 | awk '{print $2}')" \
      | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

echo "[2] Gửi request..."
<<<<<<< HEAD
curl -k -i "$URL" \
=======
curl -i "$URL" \
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40
  -H "X-Api-Key: $API_KEY" \
  -H "X-Timestamp: $TS" \
  -H "X-Nonce: $NONCE" \
  -H "X-Signature: $SIG"
