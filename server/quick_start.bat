@echo off
cls
echo ==========================================
echo  INVENTORY MANAGEMENT SERVER - QUICK START
echo ==========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.x from https://python.org
    echo.
    pause
    exit /b 1
)

echo Python version:
python --version
echo.

REM Check if requirements are installed
echo Checking dependencies...
pip show flask >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing dependencies...
    pip install -r requirements.txt
    if %errorlevel% neq 0 (
        echo ERROR: Failed to install dependencies
        pause
        exit /b 1
    )
    echo Dependencies installed successfully!
    echo.
)

REM Get IP address
echo Detecting IP address...
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set "IP=%%a"
    goto :found_ip
)
:found_ip
set "IP=%IP: =%"
echo Your IP address: %IP%
echo.

echo ==========================================
echo  STARTING SERVER...
echo ==========================================
echo.
echo Server will be available at:
echo  - Local:   http://localhost:8080
echo  - Network: http://%IP%:8080
echo.
echo Use these addresses in your mobile app settings
echo.
echo Press Ctrl+C to stop the server
echo ==========================================
echo.

REM Start the server
python app.py

pause
