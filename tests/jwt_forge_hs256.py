import jwt
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

fake_secret = "hello123"

token = jwt.encode(
    {"sub": "attacker", "iss": "fake-issuer", "exp": 9999999999},
    fake_secret,
    algorithm="HS256"
)

print("Forged token:", token)

r = requests.get(
    "https://localhost:8443/api/hello",
    headers={"Authorization": f"Bearer {token}"},
    verify=False
)

print("Status:", r.status_code)
print("Response:", r.text)
