"""
AI Service - Multi-Fallback Logic
Gemini → Grok → OpenAI

Logic giống hệt Flutter frontend (syllabus_page.dart)
"""

import os
import re
import httpx
from google.genai import Client
from openai import OpenAI
from typing import List, Tuple
from models.schemas import Question


class AIService:
    """Service xử lý AI generation với multi-fallback"""
    
    def __init__(self):
        self.gemini_key = os.getenv("GEMINI_API_KEY")
        self.grok_key = os.getenv("GROK_API_KEY")
        self.openai_key = os.getenv("OPENAI_API_KEY")
        
        # Configure Gemini Client
        self.gemini_client = None
        if self.gemini_key:
            self.gemini_client = Client(api_key=self.gemini_key)
    
    def _build_prompt(self, text: str, count: int, structure: str) -> str:
        """Tạo prompt giống Flutter frontend"""
        return f"""
Nhiệm vụ: Thiết kế đề thi tổng 10 điểm dựa trên nội dung sau.
Nội dung: {text}. Số lượng câu: {count}. Cấu trúc yêu cầu: {structure} (Lưu ý: Chia điểm đúng theo tỉ lệ này).
YÊU CẦU QUY ĐỊNH:
- TỔNG ĐIỂM CÁC CÂU HỎI PHẢI BẰNG 10.0.
- Phân bổ điểm cho từng câu trắc nghiệm và tự luận sao cho khớp với tỉ lệ {structure}.
- Tuyệt đối không dùng ký tự trang trí như *, **, ***.
- Trả về văn bản theo cấu trúc:
Loại: [trac_nghiem hoặc tu_luan]
Điểm: [Số điểm]
Nội dung: [Câu hỏi]
Đáp án: [Đáp án]
Rubric: [Tiêu chí chấm điểm nếu là tự luận, còn lại N/A]
KẾT THÚC CÂU
"""

    def _parse_ai_response(self, response: str) -> List[Question]:
        """Parse AI response thành list Question (giống Flutter)"""
        questions = []
        blocks = response.split("KẾT THÚC CÂU")
        
        for block in blocks:
            block = block.strip()
            if not block:
                continue
            
            q_type = self._get_value_by_label(block, "Loại:")
            score = self._get_value_by_label(block, "Điểm:")
            content = self._get_value_by_label(block, "Nội dung:")
            answer = self._get_value_by_label(block, "Đáp án:")
            rubric = self._get_value_by_label(block, "Rubric:")
            
            # Clean content (remove "Câu 1:" prefix)
            content = re.sub(r'^(Câu|Câu hỏi)\s*\d+[:.]?\s*', '', content, flags=re.IGNORECASE)
            
            # Parse score
            try:
                score_float = float(re.search(r'[\d.]+', score).group()) if score else None
            except:
                score_float = None
            
            questions.append(Question(
                type=self._clean_text(q_type),
                content=f"({score} điểm) {self._clean_text(content)}" if score else self._clean_text(content),
                correct_answer=self._clean_text(answer),
                rubric=None if rubric == "N/A" else self._clean_text(rubric),
                score=score_float
            ))
        
        return questions

    def _get_value_by_label(self, block: str, label: str) -> str:
        """Extract value từ block text theo label"""
        if label not in block:
            return ""
        
        start = block.index(label) + len(label)
        labels = ["Loại:", "Điểm:", "Nội dung:", "Đáp án:", "Rubric:", "KẾT THÚC CÂU"]
        end = len(block)
        
        for l in labels:
            try:
                pos = block.index(l, start)
                if pos < end:
                    end = pos
            except ValueError:
                continue
        
        return block[start:end].strip()

    def _clean_text(self, text: str) -> str:
        """Remove markdown artifacts"""
        return text.replace('*', '').replace('_', '').replace('#', '').strip()

    async def generate_with_gemini(self, prompt: str, max_retries: int = 3) -> Tuple[List[Question], bool]:
        """Gọi Gemini API (New SDK) với retry logic"""
        if not self.gemini_client:
            return [], False
        
        for attempt in range(max_retries):
            try:
                # Dùng gemini-1.5-flash là model chuẩn và stable nhất hiện tại
                response = self.gemini_client.models.generate_content(
                    model='gemini-2.5-flash',
                    contents=prompt
                )
                
                if response.text:
                    questions = self._parse_ai_response(response.text)
                    return questions, True
                    
            except Exception as e:
                error_str = str(e)
                # Nếu 503 hoặc overloaded, retry
                if '503' in error_str or 'overloaded' in error_str.lower():
                    if attempt < max_retries - 1:
                        continue
                else:
                    print(f"Gemini error: {e}")
                    break
        
        return [], False

    async def generate_with_grok(self, prompt: str) -> Tuple[List[Question], bool]:
        """Gọi Grok API"""
        if not self.grok_key:
            return [], False
        
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    "https://api.x.ai/v1/chat/completions",
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {self.grok_key}"
                    },
                    json={
                        "model": "grok-2-latest",
                        "messages": [{"role": "user", "content": prompt}],
                        "temperature": 0.7
                    }
                )
                
                if response.status_code == 200:
                    data = response.json()
                    ai_text = data['choices'][0]['message']['content']
                    questions = self._parse_ai_response(ai_text)
                    return questions, True
                    
        except Exception as e:
            print(f"Grok error: {e}")
        
        return [], False

    async def generate_with_openai(self, prompt: str) -> Tuple[List[Question], bool]:
        """Gọi OpenAI API (cứu cánh cuối cùng)"""
        if not self.openai_key:
            return [], False
        
        try:
            client = OpenAI(api_key=self.openai_key)
            response = client.chat.completions.create(
                model="gpt-4o",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7
            )
            
            if response.choices:
                ai_text = response.choices[0].message.content
                questions = self._parse_ai_response(ai_text)
                return questions, True
                
        except Exception as e:
            error_str = str(e).lower()
            if "insufficient_quota" in error_str or "429" in error_str:
                print(f"OpenAI Error: Tài khoản hết quota (429). Đang chuyển sang model dự phòng...")
            else:
                print(f"OpenAI error: {e}")
        
        return [], False

    async def generate_exam(self, text: str, count: int, structure: str) -> Tuple[List[Question], str]:
        """
        Main function - Generate exam với multi-fallback
        Returns: (questions, model_used)
        """
        prompt = self._build_prompt(text, count, structure)
        
        # 1. Try Gemini first
        questions, success = await self.generate_with_gemini(prompt)
        if success and questions:
            return questions, "gemini"
        
        # 2. Fallback to Grok
        questions, success = await self.generate_with_grok(prompt)
        if success and questions:
            return questions, "grok"
        
        # 3. Final fallback to OpenAI
        questions, success = await self.generate_with_openai(prompt)
        if success and questions:
            return questions, "openai"
        
        # All failed
        return [], "none"


# Singleton instance
ai_service = AIService()
