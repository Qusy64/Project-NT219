import jwt
import requests

fake_secret = "hello123"

token = jwt.encode(
    {
        "sub": "attacker",
        "iss": "fake-issuer",
        "exp": 9999999999
    },
    fake_secret,
    algorithm="HS256"
)

print("Forged token:", token)

r = requests.get(
    "http://localhost:8000/api/hello",
    headers={"Authorization": f"Bearer {token}"}
)

print("Status:", r.status_code)
print("Response:", r.text)
