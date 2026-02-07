"""
EduGrade AI - Python Backend
FastAPI server với Multi-Fallback AI (Gemini → Grok → OpenAI)
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os

# 1. Load environment first
load_dotenv()

# 2. Initialize Firebase BEFORE anything else
# This ensures that when routers are imported, the singleton is already ready
from services.firebase_service import firebase_service

firebase_service.initialize()

# 3. Import routers only after initialization
from routers import (
    ai_router,
    auth_router,
    users_router,
    classes_router,
    exams_router,
    settings_router,
)

# 4. Service Type Check (For Microservices)
SERVICE_TYPE = os.getenv("SERVICE_TYPE", "ALL").upper()

from contextlib import asynccontextmanager


@asynccontextmanager
async def lifespan(app: FastAPI):
    # --- STARTUP LOGIC ---
    print("\n" + "=" * 60)
    print(f"[STARTUP] EduGrade AI Backend ({SERVICE_TYPE}) Starting...")
    print("=" * 60)

    # Initialize state
    app.state.firebase_db = None

    # 1. Initialize Firebase (Blocking)
    if firebase_service.initialize():
        print("[FIREBASE] Connected Successfully")
        # Assign to app state as requested
        app.state.firebase_db = firebase_service.db
    else:
        print("[FIREBASE] FAILED TO CONNECT - Check serviceAccountKey.json")

    print(f"[SERVER] Running Type: {SERVICE_TYPE}")

    # In ra tất cả các routes đăng ký để debug
    print("\n[ROUTES] Registered Endpoints:")
    for route in app.routes:
        methods = ", ".join(getattr(route, "methods", ["GET"]))
        print(f"  {methods.ljust(15)} {route.path}")
    print("=" * 60 + "\n")

    yield

    # --- SHUTDOWN LOGIC ---
    print(f"[SHUTDOWN] Cleaning up {SERVICE_TYPE} resources...")


# Initialize FastAPI with lifespan
app = FastAPI(
    title=f"EduGrade AI {SERVICE_TYPE} Service",
    description="API Backend cho hệ thống quản lý giáo dục & khảo thí thông minh",
    version="1.0.0",
    lifespan=lifespan,
)


# Middleware Logging - Giúp debug lỗi 404
@app.middleware("http")
async def log_requests(request: Request, call_next):
    path = request.url.path
    method = request.method
    print(f"[DEBUG] Incoming Request: {method} {path}")

    try:
        response = await call_next(request)
        print(f"[DEBUG] Response Status: {response.status_code} for {method} {path}")
        return response
    except Exception as e:
        print(f"[ERROR] Middleware caught error: {str(e)}")
        raise e


origins = [
    "https://edugrade-frontend.onrender.com",  # Link FE Render của ông
    "http://localhost",
    "*",  # Cho phép tất cả (dùng cách này nếu muốn nhanh nhất để test)
]
# CORS Middleware - Cho phép Flutter app kết nối
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount routers based on Service Type
if SERVICE_TYPE in ["AUTH", "ALL"]:
    print("[INIT] Mounting AUTH & USERS routes")
    app.include_router(auth_router.router, prefix="/api/auth", tags=["Authentication"])
    app.include_router(users_router.router, prefix="/api/users", tags=["Users"])

if SERVICE_TYPE in ["CORE", "ALL"]:
    print("[INIT] Mounting CLASSES, EXAMS & SETTINGS routes")
    app.include_router(classes_router.router, prefix="/api/classes", tags=["Classes"])
    app.include_router(exams_router.router, prefix="/api/exams", tags=["Exams"])
    app.include_router(
        settings_router.router, prefix="/api/settings", tags=["Settings"]
    )

if SERVICE_TYPE in ["AI", "ALL"]:
    print("[INIT] Mounting AI routes")
    app.include_router(ai_router.router, prefix="/api/ai", tags=["AI"])


@app.get("/")
async def root():
    return {
        "message": "EduGrade AI Backend is running!",
        "version": "1.0.0",
        "docs": "/docs",
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok", "service": "edugrade-ai-backend"}


@app.get("/api/ping")
async def api_ping():
    """Verify /api prefix reachability"""
    return {"status": "api_prefix_ok"}


from starlette.exceptions import HTTPException as StarletteHTTPException


@app.exception_handler(StarletteHTTPException)
async def custom_http_exception_handler(request: Request, exc: StarletteHTTPException):
    if exc.status_code == 404:
        print(f"[404 ERROR] Path: {request.url.path} | Method: {request.method}")
        return JSONResponse(
            status_code=404,
            content={
                "detail": "Path not found in EduGrade AI Backend",
                "requested_path": request.url.path,
                "method": request.method,
                "tip": "Check for double slashes //, missing /api prefix, or trailing slashes /",
                "available_prefixes": [
                    "/api/ai",
                    "/api/auth",
                    "/api/users",
                    "/api/classes",
                    "/api/exams",
                    "/api/settings",
                ],
                "server_time": str(firebase_service._get_server_timestamp()),
            },
        )
    return await http_exception_handler(request, exc)


# Fallback for any other 404s
@app.exception_handler(404)
async def custom_404_handler(request: Request, exc):
    """Deep Diagnostic for 404 errors"""
    return JSONResponse(
        status_code=404,
        content={
            "detail": "Path not found in EduGrade AI Backend (Global Handler)",
            "requested_path": request.url.path,
            "method": request.method,
            "tip": "The requested endpoint does not exist on this server.",
        },
    )


from fastapi.exception_handlers import http_exception_handler


if __name__ == "__main__":
    import uvicorn

    # Sử dụng biến môi trường để Docker có thể cấu hình được
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", 8000))
    print(f"[SERVER] Running on {host}:{port}...")
    uvicorn.run(app, host=host, port=port)
