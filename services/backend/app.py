from fastapi import (
    FastAPI, Request, Depends, Form, UploadFile, File,
    HTTPException, status
)
from fastapi.responses import HTMLResponse, RedirectResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from starlette.middleware.sessions import SessionMiddleware

from sqlmodel import SQLModel, Field, Relationship, Session as DBSession, create_engine, select

from typing import Optional, List
from pathlib import Path
import shutil
import hashlib
import os
from datetime import datetime, timedelta
import secrets

# =========================
# Config
# =========================

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "studyhub.db"
UPLOAD_DIR = BASE_DIR / "uploads"

UPLOAD_DIR.mkdir(exist_ok=True)

DATABASE_URL = f"sqlite:///{DB_PATH}"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})

app = FastAPI(title="Study Hub")

# Session (để login đơn giản)
app.add_middleware(SessionMiddleware, secret_key="CHANGE_ME_TO_A_RANDOM_SECRET")

# Static & Templates
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))

if (BASE_DIR / "static").exists():
    app.mount("/static", StaticFiles(directory=str(BASE_DIR / "static")), name="static")


# =========================
# Models
# =========================

class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(index=True, unique=True)
    email: str = Field(index=True, unique=True)
    password_hash: str
    is_active: bool = Field(default=False)  # chỉ true sau khi xác minh email
    verification_code: Optional[str] = None
    verification_expires_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

    documents: List["Document"] = Relationship(back_populates="owner")
    comments: List["Comment"] = Relationship(back_populates="user")


class Document(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    title: str
    description: Optional[str] = ""
    subject: str
    tags: Optional[str] = ""
    filename: str
    original_filename: str
    content_type: str
    size: int
    uploaded_at: datetime = Field(default_factory=datetime.utcnow)
    owner_id: Optional[int] = Field(default=None, foreign_key="user.id")
    is_public: bool = Field(default=True)

    owner: Optional[User] = Relationship(back_populates="documents")
    comments: List["Comment"] = Relationship(back_populates="document")


class Favorite(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(foreign_key="user.id")
    document_id: int = Field(foreign_key="document.id")


class Comment(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    document_id: int = Field(foreign_key="document.id")
    user_id: int = Field(foreign_key="user.id")
    content: str
    created_at: datetime = Field(default_factory=datetime.utcnow)

    user: Optional[User] = Relationship(back_populates="comments")
    document: Optional[Document] = Relationship(back_populates="comments")


# =========================
# DB helpers
# =========================

def create_db_and_tables():
    SQLModel.metadata.create_all(engine)


def get_session():
    with DBSession(engine) as session:
        yield session


# =========================
# Auth helpers
# =========================

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def verify_password(password: str, password_hash: str) -> bool:
    return hash_password(password) == password_hash


def get_current_user(request: Request, session: DBSession = Depends(get_session)) -> Optional[User]:
    user_id = request.session.get("user_id")
    if not user_id:
        return None
    return session.get(User, user_id)


def login_required(user: Optional[User]):
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Login required")


def generate_verification_code() -> str:
    # 6 chữ số, ví dụ: 493201
    return f"{secrets.randbelow(1_000_000):06d}"


def send_verification_email(email: str, code: str):
    """
    Hàm giả lập gửi email.
    Thực tế: nối vào SMTP / dịch vụ gửi mail.
    Demo: chỉ print ra console.
    """
    print("========== VERIFY EMAIL ==========")
    print(f"Gửi mã xác nhận tới {email}: {code}")
    print("==================================")


# =========================
# Utility
# =========================

SUBJECT_CHOICES = ["Toán", "CNTT", "Ngoại ngữ", "Triết", "Mạng máy tính", "Lập trình", "Khác"]


def save_upload_file(upload_file: UploadFile, destination: Path) -> int:
    with destination.open("wb") as buffer:
        shutil.copyfileobj(upload_file.file, buffer)
    return destination.stat().st_size


def is_pdf(content_type: str, filename: str) -> bool:
    return "pdf" in (content_type or "").lower() or filename.lower().endswith(".pdf")


# =========================
# Routes: Auth
# =========================

@app.get("/register", response_class=HTMLResponse)
async def register_page(request: Request):
    return templates.TemplateResponse("auth_register.html", {"request": request})


@app.post("/register", response_class=HTMLResponse)
async def register(
    request: Request,
    username: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    session: DBSession = Depends(get_session),
):
    # Check username/email tồn tại
    existing_username = session.exec(select(User).where(User.username == username)).first()
    existing_email = session.exec(select(User).where(User.email == email)).first()
    if existing_username:
        return templates.TemplateResponse(
            "auth_register.html",
            {"request": request, "error": "Username đã tồn tại"},
            status_code=400,
        )
    if existing_email:
        return templates.TemplateResponse(
            "auth_register.html",
            {"request": request, "error": "Email đã được sử dụng"},
            status_code=400,
        )

    code = generate_verification_code()
    expires = datetime.utcnow() + timedelta(minutes=15)

    user = User(
        username=username,
        email=email,
        password_hash=hash_password(password),
        is_active=False,
        verification_code=code,
        verification_expires_at=expires,
    )
    session.add(user)
    session.commit()
    session.refresh(user)

    # Gửi mail (demo)
    send_verification_email(email, code)

    # Lưu user_id để bước verify biết ai
    request.session["pending_user_id"] = user.id

    return RedirectResponse(url="/verify", status_code=302)


@app.get("/verify", response_class=HTMLResponse)
async def verify_page(request: Request, session: DBSession = Depends(get_session)):
    pending_id = request.session.get("pending_user_id")
    user = session.get(User, pending_id) if pending_id else None
    if not user:
        msg = "Không tìm thấy tài khoản đang chờ xác minh. Hãy đăng ký lại."
        return templates.TemplateResponse("auth_verify.html", {"request": request, "error": msg})

    return templates.TemplateResponse(
        "auth_verify.html",
        {"request": request, "email": user.email},
    )


@app.post("/verify", response_class=HTMLResponse)
async def verify_code(
    request: Request,
    code: str = Form(...),
    session: DBSession = Depends(get_session),
):
    pending_id = request.session.get("pending_user_id")
    user = session.get(User, pending_id) if pending_id else None
    if not user:
        msg = "Không tìm thấy tài khoản đang chờ xác minh. Hãy đăng ký lại."
        return templates.TemplateResponse("auth_verify.html", {"request": request, "error": msg})

    now = datetime.utcnow()
    if not user.verification_code or not user.verification_expires_at:
        error = "Tài khoản không có mã xác minh. Hãy đăng ký lại."
    elif now > user.verification_expires_at:
        error = "Mã xác nhận đã hết hạn. Hãy đăng ký lại."
    elif code.strip() != user.verification_code:
        error = "Mã xác nhận không đúng."

    else:
        # OK
        user.is_active = True
        user.verification_code = None
        user.verification_expires_at = None
        session.add(user)
        session.commit()
        # Đưa vào session login luôn
        request.session.pop("pending_user_id", None)
        request.session["user_id"] = user.id
        return RedirectResponse(url="/", status_code=302)

    return templates.TemplateResponse(
        "auth_verify.html",
        {"request": request, "error": error, "email": user.email},
        status_code=400,
    )


@app.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    return templates.TemplateResponse("auth_login.html", {"request": request})


@app.post("/login")
async def login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    session: DBSession = Depends(get_session),
):
    user = session.exec(select(User).where(User.username == username)).first()
    if not user or not verify_password(password, user.password_hash):
        return templates.TemplateResponse(
            "auth_login.html",
            {"request": request, "error": "Sai username hoặc password"},
            status_code=400,
        )

    if not user.is_active:
        # chưa verify email
        request.session["pending_user_id"] = user.id
        return RedirectResponse(url="/verify", status_code=302)

    request.session["user_id"] = user.id
    return RedirectResponse(url="/", status_code=302)


@app.get("/logout")
async def logout(request: Request):
    request.session.clear()
    return RedirectResponse(url="/", status_code=302)


# =========================
# Routes: Home + Search
# =========================

@app.get("/", response_class=HTMLResponse)
async def index(
    request: Request,
    q: Optional[str] = None,
    subject: Optional[str] = None,
    session: DBSession = Depends(get_session),
    current_user: Optional[User] = Depends(get_current_user),
):
    stmt = select(Document).order_by(Document.uploaded_at.desc())
    if q:
        like = f"%{q}%"
        stmt = stmt.where(
            (Document.title.ilike(like))
            | (Document.description.ilike(like))
            | (Document.tags.ilike(like))
            | (Document.subject.ilike(like))
        )
    if subject:
        stmt = stmt.where(Document.subject == subject)

    documents = session.exec(stmt.limit(50)).all()

    return templates.TemplateResponse(
        "index.html",
        {
            "request": request,
            "documents": documents,
            "subjects": SUBJECT_CHOICES,
            "q": q or "",
            "subject_filter": subject or "",
            "current_user": current_user,
        },
    )


# =========================
# Routes: Upload & Document
# =========================

@app.get("/upload", response_class=HTMLResponse)
async def upload_page(
    request: Request,
    current_user: Optional[User] = Depends(get_current_user),
):
    login_required(current_user)
    return templates.TemplateResponse(
        "upload.html",
        {"request": request, "subjects": SUBJECT_CHOICES, "current_user": current_user},
    )


@app.post("/upload")
async def upload_document(
    request: Request,
    file: UploadFile = File(...),
    title: str = Form(...),
    description: str = Form(""),
    subject: str = Form("Khác"),
    tags: str = Form(""),
    is_public: bool = Form(False),
    session: DBSession = Depends(get_session),
    current_user: Optional[User] = Depends(get_current_user),
):
    login_required(current_user)

    safe_name = f"{datetime.utcnow().timestamp()}_{file.filename}"
    dest_path = UPLOAD_DIR / safe_name
    size = save_upload_file(file, dest_path)

    doc = Document(
        title=title or file.filename,
        description=description,
        subject=subject,
        tags=tags,
        filename=safe_name,
        original_filename=file.filename,
        content_type=file.content_type or "",
        size=size,
        owner_id=current_user.id,
        is_public=is_public,
    )
    session.add(doc)
    session.commit()
    session.refresh(doc)

    return RedirectResponse(url=f"/documents/{doc.id}", status_code=302)


@app.get("/documents/{doc_id}", response_class=HTMLResponse)
async def document_detail(
    doc_id: int,
    request: Request,
    session: DBSession = Depends(get_session),
    current_user: Optional[User] = Depends(get_current_user),
):
    doc = session.get(Document, doc_id)
    if not doc:
        raise HTTPException(404, "Document not found")

    is_favorite = False
    if current_user:
        fav = session.exec(
            select(Favorite).where(
                Favorite.user_id == current_user.id, Favorite.document_id == doc.id
            )
        ).first()
        is_favorite = fav is not None

    comments = session.exec(
        select(Comment)
        .where(Comment.document_id == doc.id)
        .order_by(Comment.created_at.desc())
    ).all()

    related = session.exec(
        select(Document)
        .where(Document.subject == doc.subject, Document.id != doc.id)
        .order_by(Document.uploaded_at.desc())
        .limit(5)
    ).all()

    return templates.TemplateResponse(
        "document_detail.html",
        {
            "request": request,
            "doc": doc,
            "current_user": current_user,
            "is_favorite": is_favorite,
            "comments": comments,
            "related_docs": related,
            "is_pdf": is_pdf(doc.content_type, doc.original_filename),
        },
    )


@app.get("/files/{filename}")
async def serve_file(filename: str):
    file_path = UPLOAD_DIR / filename
    if not file_path.exists():
        raise HTTPException(404, "File not found")
    return FileResponse(str(file_path))


# =========================
# Routes: Favorite, Comment, Share
# =========================

@app.post("/documents/{doc_id}/favorite")
async def toggle_favorite(
    doc_id: int,
    request: Request,
    session: DBSession = Depends(get_session),
    current_user: Optional[User] = Depends(get_current_user),
):
    login_required(current_user)
    doc = session.get(Document, doc_id)
    if not doc:
        raise HTTPException(404, "Document not found")

    fav = session.exec(
        select(Favorite).where(
            Favorite.user_id == current_user.id, Favorite.document_id == doc.id
        )
    ).first()

    if fav:
        session.delete(fav)
    else:
        session.add(Favorite(user_id=current_user.id, document_id=doc.id))

    session.commit()
    return RedirectResponse(url=f"/documents/{doc.id}", status_code=302)


@app.post("/documents/{doc_id}/comment")
async def add_comment(
    doc_id: int,
    request: Request,
    content: str = Form(...),
    session: DBSession = Depends(get_session),
    current_user: Optional[User] = Depends(get_current_user),
):
    login_required(current_user)
    doc = session.get(Document, doc_id)
    if not doc:
        raise HTTPException(404, "Document not found")

    cmt = Comment(document_id=doc.id, user_id=current_user.id, content=content)
    session.add(cmt)
    session.commit()
    return RedirectResponse(url=f"/documents/{doc.id}", status_code=302)


@app.get("/share/{doc_id}", response_class=HTMLResponse)
async def share_readonly(
    doc_id: int,
    request: Request,
    session: DBSession = Depends(get_session),
):
    doc = session.get(Document, doc_id)
    if not doc:
        raise HTTPException(404, "Document not found")

    comments = session.exec(
        select(Comment)
        .where(Comment.document_id == doc.id)
        .order_by(Comment.created_at.desc())
    ).all()

    return templates.TemplateResponse(
        "document_detail.html",
        {
            "request": request,
            "doc": doc,
            "current_user": None,
            "is_favorite": False,
            "comments": comments,
            "related_docs": [],
            "is_pdf": is_pdf(doc.content_type, doc.original_filename),
            "readonly": True,
        },
    )


# =========================
# Routes: AI demo
# =========================

def fake_ai_summary(doc: Document) -> str:
    return f"Đây là bản tóm tắt giả lập cho tài liệu '{doc.title}'. Bạn có thể thay bằng gọi API AI thật."


@app.post("/documents/{doc_id}/ai/summary", response_class=HTMLResponse)
async def ai_summary(
    doc_id: int,
    request: Request,
    session: DBSession = Depends(get_session),
    current_user: Optional[User] = Depends(get_current_user),
):
    doc = session.get(Document, doc_id)
    if not doc:
        raise HTTPException(404, "Document not found")

    summary = fake_ai_summary(doc)
    comments = session.exec(
        select(Comment) 
        .where(Comment.document_id == doc.id)
        .order_by(Comment.created_at.desc())
    ).all()

    related = session.exec(
        select(Document)
        .where(Document.subject == doc.subject, Document.id != doc.id)
        .order_by(Document.uploaded_at.desc())
        .limit(5)
    ).all()

    return templates.TemplateResponse(
        "document_detail.html",
        {
            "request": request,
            "doc": doc,
            "current_user": current_user,
            "is_favorite": False,
            "comments": comments,
            "related_docs": related,
            "is_pdf": is_pdf(doc.content_type, doc.original_filename),
            "ai_summary": summary,
        },
    )


@app.on_event("startup")
def on_startup():
    create_db_and_tables()
