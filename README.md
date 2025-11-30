# Simple Secure API Gateway Demo (Kong + Keycloak)

A minimal, ready-to-run demo:
- Keycloak (realm `secure`, client `api-client` using **Client Credentials**)
- Kong (OSS) with **oauth2-introspection** plugin
- Backend (FastAPI) behind Kong

## Run
```bash
docker compose -f infra/docker-compose.yml up -d --build
# wait ~45-60s for Keycloak to import realm
bash clients/call_api.sh
```

**Expected:** `200 OK` from `http://localhost:8000/api` with JSON body:
```json
{"message":"✅ Auth success via Kong (Keycloak introspection)"}
```

## Notes
- Default Keycloak admin: `admin` / `admin` at http://localhost:8080
- Client configured: `api-client` with secret `api-secret` (confidential)
- Kong validates access tokens by calling Keycloak's `/token/introspect` endpoint, so it works with default RS256-signature tokens.
