@echo off
setlocal
title Nohut Falafel - Yerel Sunucu (SQLite)
cd /d "%~dp0"
echo =============================================
echo  NOHUT FALAFEL - LAPTOP LOCAL SERVER
echo =============================================
echo.
where py >nul 2>&1
if %errorlevel%==0 (
    py -3 local_server.py
) else (
    where python >nul 2>&1
    if %errorlevel%==0 (
        python local_server.py
    ) else (
        echo Python 3 bulunamadi. Once Python 3 kurun:
        echo https://www.python.org/downloads/windows/
    )
)
echo.
echo Yerel sunucu durdu. Hata varsa yukarida gorunur.
pause
