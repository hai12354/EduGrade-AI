"""
Pydantic models/schemas cho EduGrade AI Backend
"""

from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from enum import Enum


class ExamStructure(str, Enum):
    """Cấu trúc đề thi"""
    FULL_MULTIPLE = "100% Trắc nghiệm"
    SEVENTY_THIRTY = "70% Trắc nghiệm - 30% Tự luận"
    SIXTY_FORTY = "60% Trắc nghiệm - 40% Tự luận"
    FIFTY_FIFTY = "50% Trắc nghiệm - 50% Tự luận"
    FORTY_SIXTY = "40% Trắc nghiệm - 60% Tự luận"
    FULL_ESSAY = "100% Tự luận"


class GenerateExamRequest(BaseModel):
    """Request body để tạo đề thi"""
    text: str = Field(..., min_length=10, description="Nội dung tài liệu để AI tạo đề")
    count: int = Field(default=10, ge=1, le=50, description="Số câu hỏi")
    structure: str = Field(default="70% Trắc nghiệm - 30% Tự luận", description="Cấu trúc đề")
    subject: Optional[str] = Field(default=None, description="Tên môn học")


class Question(BaseModel):
    """Model cho 1 câu hỏi"""
    type: str = Field(..., description="trac_nghiem hoặc tu_luan")
    content: str = Field(..., description="Nội dung câu hỏi")
    correct_answer: str = Field(..., description="Đáp án đúng")
    rubric: Optional[str] = Field(default=None, description="Tiêu chí chấm điểm (cho tự luận)")
    score: Optional[float] = Field(default=None, description="Điểm số")


class GenerateExamResponse(BaseModel):
    """Response sau khi tạo đề thi"""
    success: bool
    questions: List[Question]
    model_used: str = Field(..., description="AI model đã sử dụng: gemini, grok, hoặc openai")
    total_questions: int
    message: Optional[str] = None


class ErrorResponse(BaseModel):
    """Error response"""
    success: bool = False
    error: str
    detail: Optional[str] = None


class TokenVerifyRequest(BaseModel):
    """Request để verify Firebase token"""
    id_token: str


class TokenVerifyResponse(BaseModel):
    """Response sau khi verify token"""
    success: bool
    uid: Optional[str] = None
    email: Optional[str] = None
    role: Optional[str] = None
    message: Optional[str] = None


class UserLoginRequest(BaseModel):
    """Request body cho Login tập trung qua Backend"""
    username: str
    password: str


class UserCreateRequest(BaseModel):
    """Request body cho đăng ký User mới tập trung qua Backend"""
    username: str
    fullName: str
    password: str
    role: str = "student"
    class_id: Optional[str] = Field(default="", alias="classId")

    class Config:
        populate_by_name = True


class UserUpdateRequest(BaseModel):
    """Request body for updating user info"""
    fullName: Optional[str] = None
    classId: Optional[str] = None
    currentSemester: Optional[str] = None
    phone: Optional[str] = None
    birthDate: Optional[str] = None
    department: Optional[str] = None


class PasswordUpdateRequest(BaseModel):
    """Request body for updating password"""
    username: str
    newPassword: str


class UserCheckRequest(BaseModel):
    """Request body for checking username existence"""
    username: str


class ClassModel(BaseModel):
    """Class data model"""
    classId: str
    name: str
    teacher: str
    schedule: str
    room: str = ""
    maxSlots: int = 50
    currentSlots: int = 0
    semester: str


class ClassRegistrationRequest(BaseModel):
    """Request for class registration"""
    userId: str
    classId: str
    semester: str
    isRegister: bool


class QuestionModel(BaseModel):
    """Question data model"""
    type: str
    content: str
    correctAnswer: str
    rubric: Optional[str] = None
    score: Optional[float] = None


class ExamCreateRequest(BaseModel):
    """Request body for creating an exam"""
    title: str
    subject: str
    structure: str
    questions: List[Dict[str, Any]]


class ExamResultRequest(BaseModel):
    """Request body for submitting exam results"""
    examId: str
    studentId: str
    studentName: str
    classId: str
    answers: Dict[str, Any]
    score: float
    totalQuestions: int
    correctCount: int
    submittedAt: Optional[str] = None


class RegistrationSettingsRequest(BaseModel):
    """Request body for registration settings"""
    semester: str
    isLocked: bool = False
    deadline: Optional[str] = None
    manualLock: bool = False
