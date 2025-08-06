@echo off
echo ========================================
echo Inventory Management Server Setup
echo ========================================
echo.

echo Installing Python dependencies...
pip install -r requirements.txt

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo To start the server, run: start_server.bat
echo.
echo The server will be available at:
echo - Local: http://localhost:8080
echo - Network: http://YOUR_IP_ADDRESS:8080
echo.
pause 