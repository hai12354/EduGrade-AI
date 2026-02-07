@echo off
echo ==========================================
echo   BUILDING APK WITH DOCKER (JDK 17)
echo ==========================================

REM 1. Build the Docker Image
echo [1/2] Creating Docker image: edugrade-flutter...
docker build -t edugrade-flutter .

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Build Docker Image failed!
    pause
    exit /b %ERRORLEVEL%
)

REM 2. Extract APK from the image
echo [2/2] Extracting APK...
docker create --name temp-container edugrade-flutter
docker cp temp-container:/app-release.apk ./app-release.apk
docker rm temp-container

echo ==========================================
echo   BUILD SUCCESSFUL! File: app-release.apk
echo ==========================================
pause
