@echo off
echo Installing Python dependencies for image compression...
echo.

cd /d "%~dp0"

echo Installing Pillow for image compression...
pip install Pillow

echo.
echo Installing other requirements...
pip install -r requirements.txt

echo.
echo Dependencies installed successfully!
echo You can now restart the server to enable image compression.
echo.
pause
