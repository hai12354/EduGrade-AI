"""
AI Router - Endpoints cho AI generation
"""

from fastapi import APIRouter, HTTPException
from models.schemas import GenerateExamRequest, GenerateExamResponse, ErrorResponse
from services.ai_service import ai_service

router = APIRouter()


@router.post(
    "/generate-exam",
    response_model=GenerateExamResponse,
    responses={500: {"model": ErrorResponse}}
)
async def generate_exam(request: GenerateExamRequest):
    """
    Tạo đề thi bằng AI Multi-Fallback
    
    - **text**: Nội dung tài liệu để AI tạo đề
    - **count**: Số câu hỏi (mặc định 10)
    - **structure**: Cấu trúc đề (vd: "70% Trắc nghiệm - 30% Tự luận")
    - **subject**: Tên môn học (optional)
    
    AI sẽ thử theo thứ tự: Gemini → Grok → OpenAI
    """
    try:
        questions, model_used = await ai_service.generate_exam(
            text=request.text,
            count=request.count,
            structure=request.structure
        )
        
        if not questions:
            raise HTTPException(
                status_code=500,
                detail="Tất cả AI đều không thể tạo đề. Vui lòng thử lại."
            )
        
        return GenerateExamResponse(
            success=True,
            questions=questions,
            model_used=model_used,
            total_questions=len(questions),
            message=f"Tạo đề thành công bằng {model_used.upper()}!"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/models")
async def get_available_models():
    return {
        "models": [
            {"name": "gemini", "display": "Gemini 2.5 Flash", "priority": 1},
            {"name": "grok", "display": "Grok 2", "priority": 2},
            {"name": "openai", "display": "GPT-4o", "priority": 3}
        ],
        "fallback_order": ["gemini", "grok", "openai"]
    }


@router.get("/structures")
async def get_exam_structures():
    """Lấy danh sách cấu trúc đề có sẵn"""
    return {
        "structures": [
            "100% Trắc nghiệm",
            "70% Trắc nghiệm - 30% Tự luận",
            "60% Trắc nghiệm - 40% Tự luận",
            "50% Trắc nghiệm - 50% Tự luận",
            "40% Trắc nghiệm - 60% Tự luận",
            "100% Tự luận"
        ]
    }
