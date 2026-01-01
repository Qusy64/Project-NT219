import jwt
import requests
<<<<<<< HEAD
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
=======
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40

fake_secret = "hello123"

token = jwt.encode(
<<<<<<< HEAD
    {"sub": "attacker", "iss": "fake-issuer", "exp": 9999999999},
=======
    {
        "sub": "attacker",
        "iss": "fake-issuer",
        "exp": 9999999999
    },
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40
    fake_secret,
    algorithm="HS256"
)

print("Forged token:", token)

r = requests.get(
<<<<<<< HEAD
    "https://localhost:8443/api/hello",
    headers={"Authorization": f"Bearer {token}"},
    verify=False
=======
    "http://localhost:8000/api/hello",
    headers={"Authorization": f"Bearer {token}"}
>>>>>>> d9551c40136259999dfbd956f9f41f09b508db40
)

print("Status:", r.status_code)
print("Response:", r.text)
