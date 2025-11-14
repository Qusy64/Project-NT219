from fastapi import FastAPI, Request, Header
from typing import Optional
from datetime import datetime
import os

app = FastAPI(
    title="Secure Backend API",
    description="Demo backend protected by Kong + Keycloak (JWT RS256)",
    version="1.1.0",
)

# Root endpoint
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
        "message": "✅ Auth success via Kong (Keycloak introspection)",
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