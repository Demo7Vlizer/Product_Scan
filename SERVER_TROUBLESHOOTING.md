# Server Connection Troubleshooting Guide

## Quick Fix for "WinError 233" or "No process is on..." Error

This error occurs when the Flutter app cannot connect to the Python server. Follow these steps to resolve the issue:

### 🚀 **QUICK START (Recommended)**

1. **Navigate to the server folder:**
   ```
   cd barcode_scanner/server
   ```

2. **Run the quick start script:**
   ```
   quick_start.bat
   ```
   
   This script will:
   - Check if Python is installed
   - Install required dependencies
   - Show your IP address
   - Start the server automatically

### 🛠️ **Manual Setup**

If the quick start doesn't work, follow these steps:

#### Step 1: Install Python
- Download Python 3.x from [python.org](https://python.org)
- Make sure to check "Add Python to PATH" during installation

#### Step 2: Install Dependencies
```bash
cd barcode_scanner/server
pip install -r requirements.txt
```

#### Step 3: Start Server
```bash
python app.py
```

#### Step 4: Configure App
1. Open the Flutter app
2. Go to Settings
3. Enter the server IP address (shown when server starts)
4. Use format: `http://YOUR_IP_ADDRESS:8080`

### 📱 **Common Server Addresses**

- **Local testing:** `http://localhost:8080` or `http://127.0.0.1:8080`
- **Network access:** `http://192.168.1.XXX:8080` (replace XXX with your actual IP)

### 🔍 **Finding Your IP Address**

**Windows:**
```cmd
ipconfig
```
Look for "IPv4 Address" under your network adapter.

**Alternative method:**
The `quick_start.bat` script automatically detects and displays your IP address.

### ✅ **Verify Server is Running**

1. Open a web browser
2. Navigate to `http://localhost:8080`
3. You should see the server status page

### 🔧 **Troubleshooting Common Issues**

#### Issue: "Python is not recognized"
**Solution:** Install Python and add it to your system PATH

#### Issue: "pip is not recognized"  
**Solution:** Python installation might be incomplete. Reinstall Python with "Add to PATH" option.

#### Issue: "Permission denied"
**Solution:** Run command prompt as Administrator

#### Issue: "Port 8080 is already in use"
**Solution:** 
1. Close any other applications using port 8080
2. Or change the port in `app.py` (line with `app.run()`)

#### Issue: "Module not found" errors
**Solution:** Install dependencies: `pip install -r requirements.txt`

### 📞 **Testing Connection**

After starting the server, test the connection:

1. **From browser:** Visit `http://localhost:8080/api/server-status`
2. **From app:** Use the "Auto-Detect Server" feature in Settings

### 🔄 **App Features that Require Server**

The following features need the server to be running:
- ✅ Adding/editing products
- ✅ Recording sales/transactions  
- ✅ **Editing sales (this feature)**
- ✅ Viewing sales history
- ✅ Inventory management
- ✅ Customer management

### 💡 **Pro Tips**

1. **Keep server running:** Don't close the server window while using the app
2. **Same network:** Ensure both your computer (server) and phone are on the same WiFi network
3. **Firewall:** Windows Firewall might block the connection - allow Python through if prompted
4. **Auto-start:** You can create a desktop shortcut to `quick_start.bat` for easy server startup

---

## 🎯 **Quick Summary**

**The error you're seeing means the server is not running. Simply:**

1. **Run:** `barcode_scanner/server/quick_start.bat`
2. **Copy the IP address** shown in the console
3. **Enter it in your app settings**
4. **Try the edit sale again**

**That's it! The error should be resolved.** 🎉
