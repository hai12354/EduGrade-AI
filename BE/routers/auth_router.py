"""
Auth Router - Authentication endpoints
"""

from fastapi import APIRouter, HTTPException, Header, Request
from typing import Optional
from models.schemas import TokenVerifyRequest, TokenVerifyResponse, UserLoginRequest, UserCreateRequest, PasswordUpdateRequest, UserCheckRequest
from services.firebase_service import firebase_service

router = APIRouter()


@router.get("/ping")
async def auth_ping():
    """Kiểm tra xem router có hoạt động không"""
    return {"status": "auth_router_online"}


@router.post("/login")
async def login_user(request: Request, login_data: UserLoginRequest):
    """
    Login tập trung qua Backend (BE-First)
    Xử lý: Kiểm tra username/password từ Firestore của Backend
    """
    try:
        db = request.app.state.firebase_db
    except AttributeError:
        db = None

    if not db:
        raise HTTPException(status_code=503, detail="Firebase DB not initialized in Backend")

    try:
        username_raw = login_data.username.lower().strip()
        
        # 1. Tìm user theo username
        # Thử 3 trường hợp: Khớp chính xác, stripping domain nếu là email, hoặc khớp với field email
        query = db.collection('users').where('username', '==', username_raw).limit(1).get()
        user_docs = list(query)
        
        if not user_docs and "@" in username_raw:
             # Thử tìm theo phần tên trước @ (ví dụ: admin@gmail.com -> tìm doc có username 'admin')
             username_prefix = username_raw.split("@")[0]
             query = db.collection('users').where('username', '==', username_prefix).limit(1).get()
             user_docs = list(query)
             
             if not user_docs:
                  # Thử tìm theo field email (nếu doc có lưu email riêng)
                  query = db.collection('users').where('email', '==', username_raw).limit(1).get()
                  user_docs = list(query)

        if not user_docs:
            raise HTTPException(status_code=401, detail="Tên đăng nhập không chính xác hoặc tài khoản chưa được thiết lập hồ sơ")

        user_data = user_docs[0].to_dict()
        role = user_data.get('role', 'student')

        # 2. Nếu là Admin, yêu cầu xác thực Firebase qua ID Token
        if role == 'admin':
            return {
                "success": False,
                "require_firebase_auth": True,
                "message": "Tài khoản Admin yêu cầu xác thực qua Firebase (ID Token)"
            }

        # 3. Nếu là Student/Teacher, kiểm tra mật khẩu thông thường
        if user_data.get('password') != login_data.password:
             raise HTTPException(status_code=401, detail="Mật khẩu không chính xác")

        return {
            "success": True,
            "user": {
                "uid": user_data.get('uid', user_docs[0].id),
                "username": user_data.get('username'),
                "fullName": user_data.get('fullName'),
                "role": role,
                "classId": user_data.get('classId', ''),
                "currentSemester": user_data.get('currentSemester', ''),
            },
            "message": "Đăng nhập Backend thành công"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi Backend: {str(e)}")


@router.post("/register")
async def register_user(request: Request, user_data: UserCreateRequest):
    """
    Đăng ký User mới tập trung qua Backend (BE-First)
    """
    try:
        db = request.app.state.firebase_db
    except AttributeError:
        db = None

    if not db:
        raise HTTPException(status_code=503, detail="Firebase DB not initialized in Backend")

    try:
        # CHĂN: Không cho phép đăng ký Admin qua API này
        if user_data.role == 'admin':
             raise HTTPException(status_code=400, detail="Chỉ Admin hệ thống mới có quyền tạo tài khoản Quản trị viên")

        # Kiểm tra username tồn tại
        existing = db.collection('users').where('username', '==', user_data.username.lower().strip()).get()
        if len(list(existing)) > 0:
            raise HTTPException(status_code=400, detail="Tên đăng nhập đã tồn tại")

        # Tạo document mới
        new_user = {
            'username': user_data.username.lower().strip(),
            'fullName': user_data.fullName,
            'password': user_data.password,
            'role': user_data.role,
            'classId': user_data.class_id or "",
            'registeredClassIds': [],
            'createdAt': firebase_service._get_server_timestamp(),
        }

        doc_ref = db.collection('users').document()
        new_user['uid'] = doc_ref.id
        doc_ref.set(new_user)

        return {
            "success": True,
            "uid": doc_ref.id,
            "message": f"Đăng ký tài khoản {user_data.role} thành công"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi đăng ký Backend: {str(e)}")


@router.post("/verify-token", response_model=TokenVerifyResponse)
async def verify_token(request: TokenVerifyRequest):
    """
    Verify Firebase ID token
    
    - **id_token**: Firebase ID token từ Flutter client
    
    Returns user info nếu token valid
    """
    result = await firebase_service.verify_token(request.id_token)
    
    if "error" in result:
        return TokenVerifyResponse(
            success=False,
            message=result["error"]
        )
    
    # Get user role from Firestore
    role = await firebase_service.get_user_role(result.get("uid", ""))
    
    return TokenVerifyResponse(
        success=True,
        uid=result.get("uid"),
        email=result.get("email"),
        role=role,
        message="Token verified successfully"
    )


@router.get("/me")
async def get_current_user(authorization: Optional[str] = Header(None)):
    """
    Get current user info từ Authorization header
    
    Header: Authorization: Bearer <firebase_token>
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")
    
    token = authorization.replace("Bearer ", "")
    result = await firebase_service.verify_token(token)
    
    if "error" in result:
        raise HTTPException(status_code=401, detail=result["error"])
    
    role = await firebase_service.get_user_role(result.get("uid", ""))
    
    return {
        "uid": result.get("uid"),
        "email": result.get("email"),
        "role": role
    }


@router.put("/password/update")
async def update_password(request: Request, password_data: PasswordUpdateRequest):
    """Update password by username (Tập trung qua /auth/)"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        users = db.collection('users').where('username', '==', password_data.username.lower().strip()).limit(1).get()
        user_docs = list(users)
        if not user_docs:
            raise HTTPException(status_code=404, detail="Username not found")
        
        user_docs[0].reference.update({
            'password': password_data.newPassword,
            'updatedAt': firebase_service._get_server_timestamp()
        })
        
        return {"success": True, "message": "Password updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/status")
async def auth_status():
    """Kiểm tra trạng thái Firebase connection"""
    return {
        "firebase_initialized": firebase_service._initialized,
        "message": "Firebase Admin SDK status"
    }


@router.post("/check-username")
async def check_username_exists(request: Request, user_data: UserCheckRequest):
    """Check if username already exists"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
        
        users = db.collection('users').where('username', '==', user_data.username.lower().strip()).limit(1).get()
        exists = len(list(users)) > 0
        
        return {"exists": exists}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
@router.post("/login-firebase")
async def login_firebase(request: Request, verify_data: TokenVerifyRequest):
    """
    Login dành riêng cho Admin bằng Firebase ID Token
    """
    try:
        db = request.app.state.firebase_db
    except AttributeError:
        db = None

    if not db:
        raise HTTPException(status_code=503, detail="Firebase DB not initialized in Backend")

    # 1. Verify token
    result = await firebase_service.verify_token(verify_data.id_token)
    if "error" in result:
        raise HTTPException(status_code=401, detail=f"Token không hợp lệ: {result['error']}")

    uid = result.get("uid")
    email = result.get("email")

    # 2. Tìm user trong Firestore
    # Ưu tiên: Document ID khớp UID (Chuẩn nhất)
    user_doc = db.collection('users').document(uid).get()
    
    if not user_doc.exists:
        # Thử tìm: Document có field 'uid' == uid
        query = db.collection('users').where('uid', '==', uid).limit(1).get()
        docs = list(query)
        
        if docs:
            user_doc = docs[0]
            # Cập nhật ID tài liệu thành UID để chuẩn hóa
            # (Note: Cloud Firestore doesn't support renaming doc IDs, 
            # but we can keep using this doc object)
        else:
            # --- TỰ ĐỘNG TẠO HỒ SƠ ADMIN NẾU CHƯA CÓ ---
            # Không lưu username và email vào database theo yêu cầu mới
            new_admin = {
                'uid': uid,
                'role': 'admin',
                'fullName': "Administrator",
                'createdAt': firebase_service._get_server_timestamp(),
            }
            db.collection('users').document(uid).set(new_admin)
            user_doc = db.collection('users').document(uid).get()

    user_data = user_doc.to_dict()
    # Kiểm tra Role
    if user_data.get('role') != 'admin':
        raise HTTPException(status_code=403, detail="Truy cập bị từ chối: Tài khoản này không có quyền Admin")

    return {
        "success": True,
        "user": {
            "uid": uid,
            "username": result.get('email', 'admin'), # Lấy tạm từ Token để UI hiển thị
            "fullName": user_data.get('fullName', 'Administrator'),
            "role": 'admin',
            "classId": user_data.get('classId', ''),
            "currentSemester": user_data.get('currentSemester', ''),
        },
        "message": "Admin đăng nhập thành công"
    }
