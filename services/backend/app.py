from fastapi import FastAPI, Request, Header, Depends, HTTPException, status
from typing import Optional
from datetime import datetime
import os
import httpx

app = FastAPI(
    title="Secure Backend API",
    description="Demo backend protected by Kong + Keycloak (JWT RS256)",
    version="1.1.0",
)

REALM = os.getenv("KEYCLOAK_REALM", "secure")
KEYCLOAK_BASE_URL = os.getenv("KEYCLOAK_BASE_URL", "http://keycloak:8080")
INTROSPECT_URL = f"{KEYCLOAK_BASE_URL}/realms/{REALM}/protocol/openid-connect/token/introspect"

CLIENT_ID = os.getenv("KEYCLOAK_INTROSPECT_CLIENT_ID", "backend-service-id")
CLIENT_SECRET = os.getenv("KEYCLOAK_INTROSPECT_CLIENT_SECRET", "")


async def introspect_token(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
        )

    token = authorization.split(" ", 1)[1].strip()

    # 👇 Gửi giống hệt introspection_direct.sh
    data = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "token": token,
    }

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.post(INTROSPECT_URL, data=data)
    except httpx.RequestError as e:
        print("=== INTROSPECT NETWORK ERROR ===")
        print("URL:", INTROSPECT_URL)
        print("CLIENT_ID:", CLIENT_ID)
        print("ERROR:", repr(e))
        print("================================")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to contact Keycloak introspection endpoint",
        )

    print("=== INTROSPECT DEBUG ===")
    print("URL:", INTROSPECT_URL)
    print("CLIENT_ID:", CLIENT_ID)
    print("STATUS:", resp.status_code)
    print("BODY:", resp.text)
    print("========================")

    if resp.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token introspection failed",
        )

    try:
        body = resp.json()
    except Exception as e:
        print("=== INTROSPECT JSON ERROR ===")
        print("RAW BODY:", resp.text)
        print("ERROR:", repr(e))
        print("=============================")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Invalid JSON from introspection endpoint",
        )

    if not body.get("active"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is inactive (revoked or expired)",
        )

    return body


@app.get("/revocation-demo")
async def revocation_demo(token_info: dict = Depends(introspect_token)):
    return {
        "message": "Access granted (revocation-aware endpoint)",
        "sub": token_info.get("sub"),
        "active": token_info.get("active"),
    }

@app.get("/")
def index():
    return {
        "service": "Secure Backend API",
        "status": "running",
        "time": datetime.utcnow().isoformat() + "Z",
        "version": app.version,
        "docs": "/docs",
        "openapi": "/openapi.json",
    }

# API protected route
@app.get("/api")
async def read_root(
    request: Request,
    authorization: Optional[str] = Header(None),
    x_user: Optional[str] = Header(None),
    x_client_id: Optional[str] = Header(None),
):
    """
    API endpoint được bảo vệ bởi Kong JWT plugin.
    Kong sẽ verify JWT, sau đó forward request tới backend.
    """
    info = {
        "message": "Auth success via Kong (Keycloak introspection)",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "headers": {
            "x-user": x_user,
            "x-client-id": x_client_id,
        },
        "from": request.client.host,
    }
    if authorization:
        info["jwt_token_prefix"] = authorization[:30] + "..."
    return info


# Echo endpoint
@app.post("/api/echo")
async def echo(request: Request):
    """
    Trả lại payload client gửi để test body forwarding qua Kong.
    """
    data = await request.json()
    return {
        "echo": data,
        "received_at": datetime.utcnow().isoformat() + "Z",
    }

# Health check endpoint

@app.get("/health")
def health():
    return {"status": "ok", "time": datetime.utcnow().isoformat() + "Z"}


# System info endpoint
@app.get("/info")
def system_info():
    return {
        "hostname": os.getenv("HOSTNAME", "unknown"),
        "python_version": os.sys.version,
        "env_vars": {
            k: v
            for k, v in os.environ.items()
            if k.startswith("KONG") or k.startswith("KEYCLOAK")
        },
    }

@app.get("/hello")
async def hello(req: Request):
    sub = req.headers.get("x-user-sub", "anonymous")
    scope = req.headers.get("x-user-scope", "")
    return {"message": f"hello {sub}", "scope": scope}