@echo off
:menu
cls
echo ======================================================
echo   EDUGREDE AI - DOCKER CONTROL PANEL
echo ======================================================
echo.
echo  1. Start System (Chay he thong)
echo  2. Stop System (Tat he thong)
echo  3. Rebuild (Cap nhat code va chay lai)
echo  4. View Logs (Xem nhat ky hoat dong)
echo  5. Clean Exit (Tat va don dep tai nguyen)
echo  6. Exit (Thoat)
echo.

set /p choice="Chon lua chon (1-6): "

if "%choice%"=="1" (
    echo Dang khoi dong he thong...
    docker-compose up -d
    echo He thong dang chay tai http://localhost
    pause
    goto menu
)

if "%choice%"=="2" (
    echo Dang tam dung he thong...
    docker-compose stop
    pause
    goto menu
)

if "%choice%"=="3" (
    echo Dang cap nhat code va build lai...
    docker-compose up -d --build
    echo Da cap nhat xong! Truy cap tai http://localhost
    pause
    goto menu
)

if "%choice%"=="4" (
    docker-compose logs -f
    goto menu
)

if "%choice%"=="5" (
    echo Dang tat va don dep toan bo...
    docker-compose down
    pause
    goto menu
)

if "%choice%"=="6" exit

goto menu
