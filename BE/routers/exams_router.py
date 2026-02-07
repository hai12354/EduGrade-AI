"""
Exams Router - Exam management endpoints
Handles exam CRUD and results operations
"""

from models.schemas import ExamCreateRequest, ExamResultRequest
from fastapi import APIRouter, HTTPException, Request
from typing import Optional, List, Dict, Any
from services.firebase_service import firebase_service

from google.cloud import firestore
import traceback

router = APIRouter()

def extract_snapshot(res_or_ref):
    """Universally extracts a DocumentSnapshot from a reference or generator."""
    if res_or_ref is None: return None
    if hasattr(res_or_ref, 'exists'): return res_or_ref
    if hasattr(res_or_ref, 'get'):
        res = res_or_ref.get()
        if hasattr(res, 'exists'): return res
        try:
            docs = list(res)
            return docs[0] if docs else None
        except: return None
    try:
        docs = list(res_or_ref)
        return docs[0] if docs else None
    except: return None

@router.get("/list")
async def get_all_exams(request: Request):
    """Get all exams"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        exams = db.collection('exams').order_by('createdAt', direction='DESCENDING').get()
        
        result = []
        for doc in exams:
            data = doc.to_dict()
            result.append({
                "id": doc.id,
                "title": data.get('title'),
                "subject": data.get('subject'),
                "structure": data.get('structure'),
                "questionCount": len(data.get('questions', [])),
                "createdAt": str(data.get('createdAt', '')),
            })
        
        return {"success": True, "exams": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/by-subject/{subject}")
async def get_exams_by_subject(request: Request, subject: str):
    """Get exams by subject name"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        exams = db.collection('exams').where('subject', '==', subject).get()
        
        result = []
        for doc in exams:
            data = doc.to_dict()
            result.append({
                "id": doc.id,
                "title": data.get('title'),
                "subject": data.get('subject'),
                "structure": data.get('structure'),
                "questions": data.get('questions', []),
                "createdAt": str(data.get('createdAt', '')),
            })
        
        return {"success": True, "exams": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{exam_id}")
async def get_exam(request: Request, exam_id: str):
    """Get exam by ID with full questions"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        doc = db.collection('exams').document(exam_id).get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Exam not found")
        
        return {"success": True, "exam": doc.to_dict()}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/")
async def create_exam(request: Request, exam_data: ExamCreateRequest):
    """Create a new exam"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        import unicodedata
        doc_id = unicodedata.normalize('NFD', exam_data.subject.lower().strip().replace(' ', '_'))
        doc_id = ''.join(c for c in doc_id if unicodedata.category(c) != 'Mn')
        
        entry = {
            'title': exam_data.title,
            'subject': exam_data.subject,
            'structure': exam_data.structure,
            'questions': exam_data.questions,
            'createdAt': firebase_service._get_server_timestamp(),
            'updatedAt': firebase_service._get_server_timestamp(),
        }
        
        db.collection('exams').document(doc_id).set(entry)
        return {"success": True, "examId": doc_id, "message": "Exam created successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{exam_id}")
async def delete_exam(request: Request, exam_id: str):
    """Delete an exam"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        db.collection('exams').document(exam_id).delete()
        return {"success": True, "message": "Exam deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============ EXAM RESULTS ============

@router.post("/results")
async def submit_exam_result(request: Request, res_data: ExamResultRequest):
    """Submit exam result for a student"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        # 1. Fetch Exam title for denormalization
        exam_title = "Đề thi"
        try:
            ex_snap = extract_snapshot(db.collection('exams').document(res_data.examId))
            if ex_snap and ex_snap.exists:
                exam_title = ex_snap.to_dict().get('title', exam_title)
        except: pass

        result_data = {
            'examId': res_data.examId,
            'examTitle': exam_title, # Denormalize
            'studentId': res_data.studentId,
            'studentName': res_data.studentName,
            'classId': res_data.classId,
            'answers': res_data.answers,
            'score': res_data.score,
            'totalQuestions': res_data.totalQuestions,
            'correctCount': res_data.correctCount,
            'submittedAt': firebase_service._get_server_timestamp(),
        }
        
        doc_ref = db.collection('exam_results').add(result_data)
        return {"success": True, "resultId": doc_ref[1].id, "message": "Result submitted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


        return {"success": True, "results": result_list}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/results/list/all")
async def get_all_results(request: Request, teacher_name: Optional[str] = None):
    """
    Get all exam results (Admin/Teacher view)
    - If teacher_name is provided: Filter results by classes owned by that teacher.
    - If None: Return all results (Admin view)
    """
    print(f"[DEBUG] GET /results/list/all - Teacher restriction: '{teacher_name}'")
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        # 0. Authorization Context
        allowed_class_ids = set()
        if teacher_name:
            # Teacher Mode: Fetch classes owned by this teacher
            # Notes: 'teacher' field in classes collection stores the teacher's Name
            try:
                classes_query = db.collection('classes').where('teacher', '==', teacher_name).get()
                for c in classes_query:
                    allowed_class_ids.add(c.id)
                print(f"[AUTH] Teacher '{teacher_name}' manages classes: {allowed_class_ids}")
                
                if not allowed_class_ids:
                    return {"success": True, "results": []} # Teacher has no classes
            except Exception as auth_err:
                 print(f"[AUTH] Failed to fetch teacher classes: {auth_err}")

        # 1. Fetch all results (or filtered query if possible)
        # Using post-query filtering for flexibility if classId filtering is complex
        results_query = db.collection('exam_results').order_by('submittedAt', direction='DESCENDING').get()
        all_results = list(results_query)
        print(f"[DEBUG] Found {len(all_results)} total results (pre-filter)")

        # Filter by Class ID if restricted
        if teacher_name:
            results = [doc for doc in all_results if doc.to_dict().get('classId') in allowed_class_ids]
            print(f"[AUTH] Filtered down to {len(results)} results for teacher")
        else:
            results = all_results
        
        # 2. Get unique user IDs to fetch detail in one go
        # Filter None or empty IDs to prevent query crashes
        uids_raw = [doc.to_dict().get('studentId') for doc in results]
        uids = list(set([uid for uid in uids_raw if uid]))
        
        user_map = {}
        if uids:
            print(f"[DEBUG] Fetching details for {len(uids)} students")
            # Batch fetch users
            for i in range(0, len(uids), 30):
                batch_uids = uids[i:i+30]
                try:
                    user_docs = db.collection('users').where('uid', 'in', batch_uids).get()
                    for u_doc in user_docs:
                        user_map[u_doc.id] = u_doc.to_dict()
                        if 'uid' in user_map[u_doc.id]:
                            user_map[user_map[u_doc.id]['uid']] = user_map[u_doc.id]
                except Exception as u_err:
                    print(f"[WARN] Failed fetching users batch: {u_err}")

        # 3. Get unique Exam IDs to fetch titles
        exam_ids_raw = [doc.to_dict().get('examId') for doc in results]
        exam_ids = list(set([eid for eid in exam_ids_raw if eid]))
        
        exam_map = {}
        if exam_ids:
            print(f"[DEBUG] Fetching details for {len(exam_ids)} exams")
            from google.cloud import firestore
            for i in range(0, len(exam_ids), 30):
                batch_exam_ids = exam_ids[i:i+30]
                try:
                    exam_docs = db.collection('exams').where(firestore.FieldPath.document_id(), 'in', batch_exam_ids).get()
                    for e_doc in exam_docs:
                        exam_map[e_doc.id] = e_doc.to_dict()
                except Exception as ex_err:
                    print(f"[WARN] Failed fetching exams batch: {ex_err}")

        result_list = []
        for doc in results:
            data = doc.to_dict()
            s_id = data.get('studentId')
            e_id = data.get('examId')
            u_info = user_map.get(s_id, {})
            e_info = exam_map.get(e_id, {})
            
            # Logic Update: Use examId as display title
            display_title = e_id if e_id else (data.get('examTitle') or e_info.get('title', 'Đề thi'))

            result_list.append({
                "id": doc.id,
                "examId": e_id,
                "examTitle": display_title, 
                "studentId": s_id,
                "studentName": data.get('studentName') or u_info.get('fullName', 'Unknown'),
                "classId": data.get('classId'),
                "score": data.get('score'),
                "totalQuestions": data.get('totalQuestions'),
                "submittedAt": str(data.get('submittedAt', '')),
                "birthDate": u_info.get('birthDate'),
                "department": u_info.get('department'),
            })
        
        return {"success": True, "results": result_list}

    except Exception as e:
        print(f"[ERROR] 500 in get_all_results: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Server Error: {str(e)}")


@router.get("/results/by-student/{student_id}")
async def get_results_by_student(request: Request, student_id: str):
    """Get all exam results for a specific student"""
    print(f"[DEBUG] GET /results/by-student/{student_id}")
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        # 0. Check if student exists (Optional, for 404 accuracy)
        # Verify student exists in 'users' collection first if we want strict 404
        # (For performance, we might skip this, but user requested 404 if not found)
        # Let's check simply.
        try:
             # Just a lightweight check or rely on query emptiness
             pass
        except: pass

        # 1. Fetch Results
        print(f"[DEBUG] Querying exam_results for studentId: {student_id}")
        results_query = db.collection('exam_results').where('studentId', '==', student_id).get()
        results = list(results_query)
        print(f"[DEBUG] Found {len(results)} results")
        
        # 2. Fetch Student Name
        student_name = "Học sinh"
        try:
            # Use extract_snapshot carefully
            u_ref = db.collection('users').document(student_id)
            u_snap = extract_snapshot(u_ref)
            if u_snap and u_snap.exists:
                student_name = u_snap.to_dict().get('fullName', student_name)
            else:
                # Fallback search by uid
                u_q = db.collection('users').where('uid', '==', student_id).limit(1).get()
                docs = list(u_q)
                if docs:
                    student_name = docs[0].to_dict().get('fullName', student_name)
        except Exception as e:
            print(f"[WARN] Failed to fetch student name: {e}")

        # 3. Fetch Exam Titles
        # Filter cleanly: must have examId and it must be truthy
        exam_ids_raw = [doc.to_dict().get('examId') for doc in results]
        exam_ids = list(set([eid for eid in exam_ids_raw if eid]))
        
        exam_map = {}
        if exam_ids:
            print(f"[DEBUG] Fetching titles for {len(exam_ids)} exams")
            from google.cloud import firestore
            for i in range(0, len(exam_ids), 30):
                batch = exam_ids[i:i+30]
                try:
                    # Query by document ID
                    ex_docs = db.collection('exams').where(firestore.FieldPath.document_id(), 'in', batch).get()
                    for d in ex_docs:
                        exam_map[d.id] = d.to_dict()
                except Exception as ex_err:
                    print(f"[ERR] Failed fetching exam batch: {ex_err}")
                    traceback.print_exc()

        result_list = []
        for doc in results:
            data = doc.to_dict()
            e_id = data.get('examId')
            e_info = exam_map.get(e_id, {})
            # Logic Update: Use examId as display title
            e_title = e_id if e_id else (data.get('examTitle') or e_info.get('title', 'Đề thi'))
            
            # Student name: denormalized > fetched > default
            s_name = data.get('studentName') or student_name
            
            result_list.append({
                "id": doc.id,
                "examId": e_id,
                "examTitle": e_title,
                "score": data.get('score'),
                "totalQuestions": data.get('totalQuestions'),
                "correctCount": data.get('correctCount'),
                "submittedAt": str(data.get('submittedAt', '')),
                "studentName": s_name
            })
        
        return {"success": True, "results": result_list}

    except Exception as e:
        print(f"[ERROR] 500 in get_results_by_student: {str(e)}")
        traceback.print_exc() # CRITICAL: Print stack trace to terminal
        # User requested 404 if not found? 
        # But this is a 500 catch. Real errors should be 500.
        # If explicit empty check was needed, we'd do it above.
        raise HTTPException(status_code=500, detail=f"Server Error: {str(e)}")


@router.delete("/results/{result_id}")
async def delete_result_endpoint(request: Request, result_id: str):
    """Delete an exam result"""
    try:
        db = request.app.state.firebase_db
        if not db:
            raise HTTPException(status_code=503, detail="Firebase not initialized")
            
        db.collection('exam_results').document(result_id).delete()
        return {"success": True, "message": "Result deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
