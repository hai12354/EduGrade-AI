from fastapi import APIRouter, HTTPException, Request
from typing import Optional, List
from models.schemas import UserCreateRequest, UserUpdateRequest, PasswordUpdateRequest
from services.firebase_service import firebase_service

router = APIRouter()


@router.get("/")
async def get_all_users(request: Request):
    """
    Get all users (Admin only logic should be here)
    """
    try:
        db = request.app.state.firebase_db
        if not db:
             raise HTTPException(status_code=503, detail="Firebase not initialized")
        
        users = db.collection('users').get()
        return {"success": True, "users": [doc.to_dict() for doc in users]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{uid}")
async def get_user(request: Request, uid: str):
    """Get user by UID or Username (Matched with Dashboard logic)"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        # 1. Try UID first
        doc = db.collection('users').document(uid).get()
        if doc.exists:
            return {"success": True, "user": doc.to_dict()}
            
        # 2. Try Username fallback
        query = db.collection('users').where('username', '==', uid.lower().strip()).limit(1).get()
        user_docs = list(query)
        
        user_data = None
        if user_docs:
            user_data = user_docs[0].to_dict()
            if 'uid' not in user_data:
                user_data['uid'] = user_docs[0].id
        elif doc.exists:
            user_data = doc.to_dict()

        if user_data:
            # --- JOIN EXTRA INFO FOR STUDENTS ---
            if user_data.get('role') == 'student' and user_data.get('classId'):
                c_id = user_data['classId']
                class_doc = db.collection('classes').document(c_id).get()
                if class_doc.exists:
                    c_data = class_doc.to_dict()
                    user_data['className'] = c_data.get('className', c_data.get('name', ''))
                    user_data['teacherName'] = c_data.get('teacherName', c_data.get('teacher', ''))
            
            return {"success": True, "user": user_data}
            
        raise HTTPException(status_code=404, detail="User not found (Tried UID and Username)")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{uid}")
async def update_user(request: Request, uid: str, user_data: UserUpdateRequest):
    """Update user profile"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        doc_ref = db.collection('users').document(uid)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Build update data
        update_data = {}
        if user_data.fullName is not None: update_data['fullName'] = user_data.fullName
        if user_data.classId is not None: update_data['classId'] = user_data.classId
        if user_data.currentSemester is not None: update_data['currentSemester'] = user_data.currentSemester
        if user_data.phone is not None: update_data['phone'] = user_data.phone
        if user_data.birthDate is not None: update_data['birthDate'] = user_data.birthDate
        if user_data.department is not None: update_data['department'] = user_data.department
        
        update_data['updatedAt'] = firebase_service._get_server_timestamp()
        doc_ref.update(update_data)
        
        return {"success": True, "message": "User updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


        return {"success": True, "teachers": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/teachers/list")
async def get_teachers(request: Request):
    """
    Lấy danh sách người dùng có role là teacher
    """
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        teachers = db.collection('users').where('role', '==', 'teacher').get()
        
        result = []
        for doc in teachers:
            data = doc.to_dict()
            result.append({
                "uid": data.get('uid', doc.id),
                "username": data.get('username'),
                "fullName": data.get('fullName'),
                "role": 'teacher',
            })
            
        return {"success": True, "teachers": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{uid}")
async def delete_user(request: Request, uid: str):
    """Delete a user (Admin only ideally)"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        db.collection('users').document(uid).delete()
        return {"success": True, "message": "User deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))





