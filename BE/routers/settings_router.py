"""
Settings Router - System settings endpoints
Handles registration deadlines and other system configurations
"""

from models.schemas import RegistrationSettingsRequest
from fastapi import APIRouter, HTTPException, Request
from typing import Optional
from services.firebase_service import firebase_service

router = APIRouter()
@router.get("/dashboard-stats")
async def get_dashboard_stats(request: Request):
    """Get aggregate stats for dashboard (BE-First)"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        # Count users by role and total classes
        # Note: For large DBs, use aggregation queries. For now, matching existing style.
        teachers = db.collection('users').where('role', '==', 'teacher').get()
        students = db.collection('users').where('role', '==', 'student').get()
        classes = db.collection('classes').get()
        
        return {
            "success": True,
            "stats": {
                "teacher": len(list(teachers)),
                "student": len(list(students)),
                "classes_count": len(list(classes))
            }
        }
    except Exception as e:
        print(f"[REDACTED] Error fetching dashboard stats: {e}")
        raise HTTPException(status_code=500, detail=f"Lỗi Backend: {str(e)}")


@router.get("/registration/{semester}")
async def get_registration_settings(request: Request, semester: str):
    """Get registration settings for a semester"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        doc_id = f"registration_{semester}"
        doc = db.collection('settings').document(doc_id).get()
        
        if not doc.exists:
            return {
                "success": True,
                "settings": {
                    "semester": semester,
                    "isLocked": False,
                    "deadline": None,
                    "manualLock": False
                }
            }
        
        return {"success": True, "settings": doc.to_dict()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/registration")
async def update_registration_settings(request: Request, reg_data: RegistrationSettingsRequest):
    """Update registration settings for a semester"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        doc_id = f"registration_{reg_data.semester}"
        settings_data = {
            'semester': reg_data.semester,
            'isLocked': reg_data.isLocked,
            'deadline': reg_data.deadline,
            'manualLock': reg_data.manualLock,
            'updatedAt': firebase_service._get_server_timestamp(),
        }
        
        db.collection('settings').document(doc_id).set(settings_data, merge=True)
        return {"success": True, "message": "Settings updated successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/semesters")
async def get_all_semesters(request: Request):
    """Get list of all semesters with settings"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        settings = db.collection('settings').get()
        semesters = []
        for doc in settings:
            if doc.id.startswith('registration_'):
                data = doc.to_dict()
                semesters.append({
                    "semester": data.get('semester'),
                    "isLocked": data.get('isLocked', False),
                    "deadline": data.get('deadline'),
                })
        
        return {"success": True, "semesters": semesters}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/registration/{semester}")
async def delete_registration_settings(request: Request, semester: str):
    """Delete registration settings for a semester"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        doc_id = f"registration_{semester}"
        db.collection('settings').document(doc_id).delete()
        return {"success": True, "message": "Settings deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
