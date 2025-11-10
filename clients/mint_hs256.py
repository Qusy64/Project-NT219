import jwt, time
secret = "super-very-secret"
payload = {
  "iss": "hs-client",
  "aud": "backend",
  "sub": "service-a",
  "exp": int(time.time()) + 300
}
token = jwt.encode(payload, secret, algorithm="HS256", headers={"kid":"hs-client-kid"})
print(token)
