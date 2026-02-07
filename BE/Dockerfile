FROM python:3.10-slim

WORKDIR /app

# Cài đặt các gói hệ thống cần thiết (nếu có)
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements và cài đặt dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy toàn bộ code Backend
COPY . .

# Mở port cho ứng dụng
EXPOSE 8000

# Chạy main.py
CMD ["python", "main.py"]
