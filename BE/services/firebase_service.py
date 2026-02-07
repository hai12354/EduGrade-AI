"""
Firebase Service
Firebase Admin SDK integration
"""

import os


class FirebaseService:
    """Service quản lý Firebase operations"""
    
    def __init__(self):
        # print(f"[DEBUG] FirebaseService initialized. Instance: {id(self)}")
        self.db = None
        self._initialized = False
        # No auto-init. Must call initialize() explicitly.


    @property
    def is_initialized(self) -> bool:
        """Check if Firebase is truly connected"""
        if self._initialized and self.db is not None:
            return True
        # Try to recover if initialized but flag/db missing? 
        return False
    

    
    def initialize(self, service_account_path: str = None):
        """Khởi tạo Firebase Admin SDK"""
        try:
            import firebase_admin
            from firebase_admin import credentials, firestore
            
            # Prevent re-initialization if already in memory
            if self._initialized and self.db is not None:
                return True
            
            # Use Firebase internal check to avoid Multi-App errors on reload
            import firebase_admin
            if firebase_admin._apps:
                self.db = firestore.client()
                self._initialized = True
                return True
            
            if not service_account_path:
                service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "serviceAccountKey.json")
                # Try to find service account key in BE directory
                if not os.path.isabs(service_account_path):
                    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                    service_account_path = os.path.join(base_dir, service_account_path)

            if os.path.exists(service_account_path):
                cred = credentials.Certificate(service_account_path)
                try:
                    firebase_admin.get_app()
                except ValueError:
                    firebase_admin.initialize_app(cred)
                
                self.db = firestore.client()
                self._initialized = True
                print(f"[OK] Firebase Connected. DB Instance: {id(self.db)}")
                return True
            else:
                # print(f"[ERROR] Service account file not found: {service_account_path}")
                pass # Silent fail to avoid spam if just starting without key
        except Exception as e:
            print(f"[ERROR] Firebase init error: {e}")
        
        return False
        
        return False
    
    def _get_server_timestamp(self):
        """Get Firestore server timestamp"""
        from google.cloud.firestore import SERVER_TIMESTAMP
        return SERVER_TIMESTAMP
    
    def _firestore_transaction(self, func):
        """Decorator for Firestore transactions"""
        from google.cloud import firestore
        return firestore.transactional(func)
    
    async def verify_token(self, id_token: str) -> dict:
        """
        Verify Firebase ID token
        Returns: { uid, email, ... } hoặc None nếu invalid
        """
        if not self._initialized:
            return {"error": "Firebase not initialized"}
        
        try:
            from firebase_admin import auth
            decoded_token = auth.verify_id_token(id_token)
            return {
                "uid": decoded_token.get("uid"),
                "email": decoded_token.get("email"),
                "email_verified": decoded_token.get("email_verified", False)
            }
        except Exception as e:
            return {"error": str(e)}
    
    async def get_user_role(self, uid: str) -> str:
        """Get user role từ Firestore"""
        if not self._initialized or not self.db:
            return "student"
        
        try:
            doc = self.db.collection("users").document(uid).get()
            if doc.exists:
                return doc.to_dict().get("role", "student")
        except Exception as e:
            print(f"Error getting user role: {e}")
        
        return "student"
    
    async def save_exam(self, exam_data: dict, doc_id: str = None) -> str:
        """Lưu đề thi vào Firestore"""
        if not self._initialized or not self.db:
            return None
        
        try:
            if doc_id:
                self.db.collection("exams").document(doc_id).set(exam_data)
                return doc_id
            else:
                doc_ref = self.db.collection("exams").add(exam_data)
                return doc_ref[1].id
        except Exception as e:
            print(f"Error saving exam: {e}")
            return None


# Singleton instance
firebase_service = FirebaseService()
