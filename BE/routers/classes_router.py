"""
Classes Router - Class management endpoints
Handles all class CRUD and registration operations
"""
from models.schemas import ClassModel, ClassRegistrationRequest
from fastapi import APIRouter, HTTPException, Request
from typing import Optional, List
from services.firebase_service import firebase_service
from datetime import datetime
import traceback

router = APIRouter()
 
def to_snapshot(result):
    """
    Universally ensures the result is a DocumentSnapshot.
    Handles cases where .get() returns a generator/stream.
    """
    if result is None: return None
    if hasattr(result, 'exists'): return result
    # If it's a generator or list
    try:
        docs = list(result)
        return docs[0] if docs else None
    except:
        return None

import re

def parse_periods(p_str):
    """Bulletproof: extracts all numbers/ranges from strings like 'Tiết 1-3, 5'"""
    if not p_str: return set()
    res = set()
    try:
        # Normalize: remove "Tiết", " ", etc
        clean = str(p_str).upper().replace('TIẾT', '').strip()
        # Handle commas and ranges
        segments = [s.strip() for s in clean.replace(',', ' ').split()]
        for seg in segments:
            if '-' in seg:
                parts = re.findall(r'\d+', seg)
                if len(parts) >= 2:
                    res.update(range(int(parts[0]), int(parts[-1]) + 1))
            else:
                nums = re.findall(r'\d+', seg)
                for n in nums: res.add(int(n))
    except: pass
    return res

def parse_days(d_str):
    """Bulletproof: extracts days from '2-4-6', 'Thứ 2,4', etc"""
    if not d_str: return set()
    res = set()
    try:
        clean = str(d_str).lower().replace('thứ', '').strip()
        # Special case: Sunday
        if 'nhật' in clean or 'cn' in clean: res.add(8)
        # Extract all digits
        nums = re.findall(r'\d+', clean)
        for n in nums:
            val = int(n)
            if 2 <= val <= 8: res.add(val)
    except: pass
    return res

def parse_dates(dr_str):
    if not dr_str: return None, None
    try:
        # Extract anything that looks like a date dd/mm/yyyy
        dates = re.findall(r'\d{1,2}/\d{1,2}/\d{4}', str(dr_str))
        if len(dates) >= 2:
            d1 = datetime.strptime(dates[0], "%d/%m/%Y").date()
            d2 = datetime.strptime(dates[1], "%d/%m/%Y").date()
            return min(d1, d2), max(d1, d2)
    except: pass
    return None, None

def get_class_schedule_info(data):
    """Extracts components with robust fallback to 'schedule' string"""
    days = data.get('dayOfWeek')
    periods = data.get('periods')
    dates = data.get('dateRange')
    
    # Fallback to schedule string parsing if fields missing
    sched = data.get('schedule', '')
    if sched and '|' in sched:
        parts = [p.strip() for p in sched.split('|')]
        # Format: Days | Periods | Room | DateRange
        if not days and len(parts) >= 1: days = parts[0]
        if not periods and len(parts) >= 2: periods = parts[1]
        if not dates:
            if len(parts) >= 4: dates = parts[3]
            elif len(parts) == 3: dates = parts[2]
            
    return days, periods, dates

@router.get("/list/{semester}")
async def get_classes_by_semester(request: Request, semester: str):
    """Get all classes for a specific semester"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        classes = db.collection('classes').where('semester', '==', semester).order_by('createdAt', direction='DESCENDING').get()
        
        result = []
        for doc in classes:
            data = doc.to_dict()
            result.append({
                "classId": data.get('classId', doc.id),
                "name": data.get('name'),
                "teacher": data.get('teacher'),
                "schedule": data.get('schedule'),
                "room": data.get('room', ''),
                "maxSlots": data.get('maxSlots', 50),
                "currentSlots": data.get('currentSlots', 0),
                "semester": data.get('semester'),
            })
        
        return {"success": True, "classes": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/by-teacher/{teacher_name}")
async def get_classes_by_teacher(request: Request, teacher_name: str):
    """Get all classes assigned to a specific teacher"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        # Tìm các lớp có trường 'teacher' hoặc 'teacherName' khớp với teacher_name
        # Lưu ý: Firestore thực hiện query 'in' hoặc 'where'
        classes = db.collection('classes').where('teacher', '==', teacher_name).get()
        
        result = []
        for doc in classes:
            data = doc.to_dict()
            result.append({
                "classId": data.get('classId', doc.id),
                "name": data.get('name', data.get('className')),
                "teacher": data.get('teacher', data.get('teacherName')),
                "semester": data.get('semester'),
            })
            
        return {"success": True, "classes": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{class_id}")
async def get_class(request: Request, class_id: str):
    """Get class by ID"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        doc_res = db.collection('classes').document(class_id).get()
        doc = to_snapshot(doc_res)
        if doc is None or not doc.exists:
            raise HTTPException(status_code=404, detail="Class not found")
        
        return {"success": True, "class": doc.to_dict()}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{class_id}/students")
async def get_students_in_class(request: Request, class_id: str):
    """Get all students enrolled in a class"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        students = db.collection('users').where('role', '==', 'student').where('classId', '==', class_id).get()
        
        result = []
        for doc in students:
            data = doc.to_dict()
            result.append({
                "uid": data.get('uid', doc.id),
                "username": data.get('username'),
                "fullName": data.get('fullName'),
                "classId": data.get('classId'),
            })
        
        return {"success": True, "students": result, "count": len(result)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/")
async def create_or_update_class(request: Request, class_data: ClassModel):
    """Create or update a class"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
        
        data = class_data.dict()
        data['createdAt'] = firebase_service._get_server_timestamp()
        
        db.collection('classes').document(class_data.classId).set(data, merge=True)
        
        return {"success": True, "message": "Class saved successfully", "classId": class_data.classId}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{class_id}")
async def delete_class(request: Request, class_id: str):
    """Delete a class"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        db.collection('classes').document(class_id).delete()
        return {"success": True, "message": "Class deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/register")
async def handle_class_registration(request: Request, reg_data: ClassRegistrationRequest):
    """
    Handle class registration/unregistration with transaction
    Ensures atomic operation for slot counting
    """
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
        
        # 1. Resolve User Reference (Triple Fallback Resolution)
        uid_input = str(reg_data.userId).strip()
        user_ref = db.collection('users').document(uid_input)
        user_snap = to_snapshot(user_ref.get())
        
        # If direct Doc ID lookup fails, try fallback logic
        if user_snap is None or not user_snap.exists:
            found_ref = None
            
            # Fallback 1: Search by 'uid' field (Some logic stores UID in a field separate from Doc ID)
            uid_query = db.collection('users').where('uid', '==', uid_input).limit(1).get()
            uid_docs = list(uid_query)
            if uid_docs: 
                found_ref = uid_docs[0].reference
            else:
                # Fallback 2: Search by 'username' field (Resilient to UID typos if username is used as identifier)
                user_query = db.collection('users').where('username', '==', uid_input.lower()).limit(1).get()
                user_docs = list(user_query)
                if user_docs:
                    found_ref = user_docs[0].reference
            
            if not found_ref:
                raise Exception(f"[ERROR] Không tìm thấy học sinh với ID/UID hoặc Username: '{uid_input}'")
            
            user_ref = found_ref
            # Log resolution for diagnostics (optional, will show in BE terminal)
            print(f"[AUTH] Resolved identity '{uid_input}' to document: {user_ref.path}")
        
        # 2. Resolve Class Reference
        class_id_input = str(reg_data.classId).strip()
        class_ref = db.collection('classes').document(class_id_input)
        # 3. Transaction Logic
        @firebase_service._firestore_transaction
        def run_registration(transaction):
            # Inside transaction: Use transaction.get(ref) or ref.get(transaction=transaction)
            # Both are supported, but transaction.get() is the canonical transactional read.
            u_snap = transaction.get(user_ref)
            c_snap = transaction.get(class_ref)
            
            # Handle potential iterable return from transactional get (Rare SDK quirk)
            if not hasattr(u_snap, 'exists'): u_snap = list(u_snap)[0]
            if not hasattr(c_snap, 'exists'): c_snap = list(c_snap)[0]
            
            if not u_snap.exists: 
                raise Exception(f"[ERROR] Không tìm thấy tài liệu người dùng: {user_ref.path}")
            if not c_snap.exists: 
                raise Exception(f"[ERROR] Không tìm thấy tài liệu lớp học: {class_ref.path}")
            
            class_data = c_snap.to_dict() or {}
            user_data = u_snap.to_dict() or {}
            
            if class_data.get('semester') != reg_data.semester:
                raise Exception(f"[VALIDATION] Lớp học '{class_data.get('name')}' không thuộc học kỳ {reg_data.semester}")
            
            # Retrieve list of registered classes safely
            registered_ids = user_data.get('registeredClassIds')
            if not isinstance(registered_ids, list):
                # Fallback / Migration logic for old schema
                old_class_id = user_data.get('classId')
                registered_ids = [old_class_id] if old_class_id else []
            
            current_slots = int(class_data.get('currentSlots', 0))
            max_slots = int(class_data.get('maxSlots', 50))
            
            if reg_data.isRegister:
                if reg_data.classId in registered_ids: return
                
                # --- CONFLICT CHECK ---
                d_str, p_str, r_str = get_class_schedule_info(class_data)
                new_day_set = parse_days(d_str)
                new_period_set = parse_periods(p_str)
                new_start, new_end = parse_dates(r_str)
                
                print(f"[DEBUG] Checking conflicts for '{class_data.get('name')}' ({reg_data.classId})")
                print(f"       -> New Schedule: Days={new_day_set}, Periods={new_period_set}, Dates={new_start} to {new_end}")

                for existing_raw_id in registered_ids:
                    existing_id = str(existing_raw_id).strip()
                    if not existing_id or existing_id == reg_data.classId: continue
                    
                    ex_ref = db.collection('classes').document(existing_id)
                    ex_snap = to_snapshot(transaction.get(ex_ref))
                    if ex_snap is None or not ex_snap.exists: continue
                    
                    ex_data = ex_snap.to_dict() or {}
                    
                    # Accuracy: Only check conflicts within the SAME semester
                    if ex_data.get('semester') != reg_data.semester: continue
                    
                    ex_d_str, ex_p_str, ex_r_str = get_class_schedule_info(ex_data)
                    ex_day_set = parse_days(ex_d_str)
                    ex_period_set = parse_periods(ex_p_str)
                    ex_start, ex_end = parse_dates(ex_r_str)

                    # Intersection Check
                    day_overlap = new_day_set.intersection(ex_day_set)
                    period_overlap = new_period_set.intersection(ex_period_set)
                    date_overlap = max(new_start, ex_start) <= min(new_end, ex_end) if (new_start and ex_start) else True
                    
                    print(f"       -> Comparing with '{ex_data.get('name')}' ({existing_id}):")
                    print(f"          Days Match: {day_overlap}, Periods Match: {period_overlap}, Date Overlap: {date_overlap}")
                    
                    if day_overlap and period_overlap and date_overlap:
                        overlap_days_sorted = sorted(list(day_overlap))
                        day_names = [f"Thứ {d}" if d < 8 else "Chủ Nhật" for d in overlap_days_sorted]
                        raise Exception(
                            f"[CONFLICT] Trùng lịch với môn '{ex_data.get('name', existing_id)}'\n"
                            f"● Thời gian: {', '.join(day_names)}, Tiết {sorted(list(period_overlap))}\n"
                            f"● Đợt học: {ex_data.get('dateRange', 'Liên tục')}"
                        )

                if current_slots >= max_slots: raise Exception("[VALIDATION] Lớp học đã đủ số lượng sinh viên (Hết chỗ)")
                
                registered_ids.append(reg_data.classId)
                transaction.update(class_ref, {'currentSlots': current_slots + 1})
                transaction.update(user_ref, {
                    'registeredClassIds': registered_ids,
                    'classId': reg_data.classId,
                    'currentSemester': reg_data.semester
                })
            else:
                if reg_data.classId in registered_ids:
                    registered_ids.remove(reg_data.classId)
                    new_slots = max(0, current_slots - 1)
                    transaction.update(class_ref, {'currentSlots': new_slots})
                    transaction.update(user_ref, {
                        'registeredClassIds': registered_ids,
                    })

        # 4. EXECUTE THE TRANSACTION (Universal pattern via decorator)
        run_registration(db.transaction())
        
        action = "đăng ký" if reg_data.isRegister else "hủy đăng ký"
        return {"success": True, "message": f"Đã {action} thành công"}
    except Exception as e:
        import traceback
        print(f"[ERROR] Registration failed for user {reg_data.userId}, class {reg_data.classId}:")
        traceback.print_exc()
        raise HTTPException(status_code=400, detail=str(e))
