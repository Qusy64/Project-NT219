from fastapi import FastAPI, Request, Header, Depends, HTTPException, status
from typing import Optional
from datetime import datetime
import os

from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt

app = FastAPI(
    title="Secure Backend API",
    description="Demo backend protected by Kong + Keycloak (JWT RS256)",
    version="1.1.0",
)

security = HTTPBearer(auto_error=False)

def get_current_token(
    credentials: HTTPAuthorizationCredentials = Depends(security),
):
    """
    Lấy và decode payload JWT từ header Authorization.
    KHÔNG verify chữ ký vì Kong đã verify rồi.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )

    token = credentials.credentials
    try:
        # decode nhưng tắt verify signature
        payload = jwt.decode(token, options={"verify_signature": False})
    except jwt.PyJWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}",
        )

    return payload

def require_role(role: str):
    """
    Dependency kiểm tra role trong realm_access.roles (Keycloak).
    Dùng cho endpoint admin.
    """
    def wrapper(payload=Depends(get_current_token)):
        roles = payload.get("realm_access", {}).get("roles", [])
        if role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Required role: {role}",
            )
        return payload

    return wrapper

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

@app.get("/api/hello")
async def hello_user(payload=Depends(get_current_token)):
    """
    Endpoint user-level: chỉ cần token hợp lệ (user / admin đều truy cập được).
    """
    sub = payload.get("sub", "anonymous")
    preferred_username = payload.get("preferred_username", "")
    roles = payload.get("realm_access", {}).get("roles", [])
    scope = payload.get("scope", "")

    return {
        "message": f"hello {sub}",
        "preferred_username": preferred_username,
        "roles": roles,
        "scope": scope,
        "time": datetime.utcnow().isoformat() + "Z",
    }

@app.get("/api/admin/hello")
async def hello_admin(payload=Depends(require_role("api_admin"))):
    """
    Endpoint admin-level: yêu cầu role api_admin trong realm_access.roles.
    """
    sub = payload.get("sub", "anonymous")
    preferred_username = payload.get("preferred_username", "")
    roles = payload.get("realm_access", {}).get("roles", [])

    return {
        "message": f"hello admin {sub}",
        "preferred_username": preferred_username,
        "roles": roles,
        "time": datetime.utcnow().isoformat() + "Z",
    }
