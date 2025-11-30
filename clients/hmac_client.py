import hashlib
import hmac
import time
import uuid
import requests

API_KEY = "client-1"
API_SECRET = b"super-secret-123"  

BASE_URL = "http://localhost:8000"
PATH = "/hmac/hello"
QUERY_STRING = "debug=true"

def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def build_canonical_string(method, path, query, timestamp, nonce, body_bytes):
    return "\n".join([
        method.upper(),
        path,
        query,
        str(timestamp),
        nonce,
        sha256_hex(body_bytes),
    ])

def sign_request(method, path, query, body_bytes):
    timestamp = int(time.time())
    nonce = str(uuid.uuid4())

    canonical = build_canonical_string(
        method, path, query, timestamp, nonce, body_bytes
    )

    signature = hmac.new(
        API_SECRET,
        canonical.encode("utf-8"),
        hashlib.sha256
    ).hexdigest() 

    headers = {
        "X-Api-Key": API_KEY,
        "X-Timestamp": str(timestamp),
        "X-Nonce": nonce,
        "X-Signature": signature,
        "Content-Type": "application/json",
    }

    return headers

if __name__ == "__main__":
    method = "GET"
    body = b'{"message":"hi"}'

    headers = sign_request(method, PATH, QUERY_STRING, body)

    url = f"{BASE_URL}{PATH}?{QUERY_STRING}"
    resp = requests.get(url, headers=headers, data=body)

    print(resp.status_code, resp.text)
