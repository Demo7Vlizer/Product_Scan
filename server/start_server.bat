@echo off
echo ========================================
echo Starting Inventory Management Server
echo ========================================
echo.

echo Server starting...
echo.
echo The server will be available at:
echo - Local: http://localhost:8080
echo - Network: http://YOUR_IP_ADDRESS:8080
echo.
echo To find your IP address, run: ipconfig
echo Look for "IPv4 Address" in the output
echo.
echo Press Ctrl+C to stop the server
echo.

python app.py 