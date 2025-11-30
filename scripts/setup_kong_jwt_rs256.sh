#!/usr/bin/env bash
set -euo pipefail

# [0/5] Lấy JWKS từ Keycloak và trích PEM
REALM="secure"
ISS="http://localhost:8080/realms/${REALM}"
JWKS_URL="${ISS}/protocol/openid-connect/certs"

# PEM sẽ nằm cùng thư mục với script
CERT_PEM="kc_cert.pem"
PUB_PEM="kc_pub.pem"

echo "[0/5] Lấy JWKS từ Keycloak..."
JWKS=$(curl -s "${JWKS_URL}")
X5C=$(printf "%s" "$JWKS" | jq -r '.keys[0].x5c[0]')

if [ -z "${X5C:-}" ] || [ "${X5C}" = "null" ]; then
  echo "Không thấy x5c trong JWKS. Hãy đợi Keycloak sẵn sàng hoặc bật x5c trong Keycloak."
  exit 1
fi

cat > "${CERT_PEM}" <<EOF
-----BEGIN CERTIFICATE-----
${X5C}
-----END CERTIFICATE-----
EOF

echo "[0/5] Trích public key PEM..."
openssl x509 -in "${CERT_PEM}" -pubkey -noout > "${PUB_PEM}"

echo "[0/5] Đã ghi:"
echo "      - $(realpath ${CERT_PEM})"
echo "      - $(realpath ${PUB_PEM})"

# [1/5] Lấy Access Token (Client Credentials)

KC_TOKEN_URL="${ISS}/protocol/openid-connect/token"
CLIENT_ID="api-client"
CLIENT_SECRET="api-secret"
KONG_API_URL="http://localhost:8002/api"

echo "[1/5] Lấy access_token từ Keycloak..."
ACCESS_TOKEN=$(curl -s -X POST "$KC_TOKEN_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_secret=${CLIENT_SECRET}" | jq -r '.access_token')

if [[ -z "${ACCESS_TOKEN}" || "${ACCESS_TOKEN}" == "null" ]]; then
  echo " Không lấy được token. Kiểm tra lại Keycloak hoặc client credentials."
  exit 1
fi

echo "[2/5] Token nhận được (rút gọn): $(echo "$ACCESS_TOKEN" | cut -c1-40)..."

# [3/5] Gọi API qua Kong Gateway

echo "[3/5] Gọi API qua Kong..."
curl -i "${KONG_API_URL}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json" || true

echo ""
echo "[4/5] Hoàn tất gọi API"

# [5/5] Tóm tắt kết quả

echo ""
echo "=== Tóm tắt ==="
echo "Token: ${ACCESS_TOKEN:0:40}..."
echo "Cert PEM: $(realpath ${CERT_PEM})"
echo "Public PEM: $(realpath ${PUB_PEM})"
echo "==============="
