# 📦 Inventory Management System

A complete local inventory management system with barcode scanning, desktop server, and mobile app.

## 🚀 Features

- **Barcode Scanning**: Scan products to add them to inventory
- **Product Management**: Add products with images, MRP, and quantities
- **Stock Tracking**: Track product in/out with recipient details
- **Desktop Dashboard**: Real-time web interface to view all data
- **Local Network**: Works on your local WiFi network
- **No Internet Required**: Everything runs locally

## 📋 Prerequisites

1. **Python 3.7+** installed on your desktop
2. **Flutter SDK** installed on your development machine
3. **Android Studio** or **VS Code** for mobile development
4. **Both devices** (desktop and mobile) on the same WiFi network

## 🛠️ Setup Instructions

### Step 1: Desktop Server Setup

1. **Navigate to the server folder:**
   ```bash
   cd server
   ```

2. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```
   
   Or on Windows, run:
   ```bash
   setup.bat
   ```

3. **Find your computer's IP address:**
   - **Windows**: Open Command Prompt and type `ipconfig`
   - **Mac/Linux**: Open Terminal and type `ifconfig`
   - Look for "IPv4 Address" (usually starts with 192.168.x.x)

4. **Start the server:**
   ```bash
   python app.py
   ```
   
   Or on Windows:
   ```bash
   start_server.bat
   ```

5. **Test the server:**
   - Open your browser and go to `http://localhost:8080`
   - You should see the inventory dashboard

### Step 2: Mobile App Setup

1. **Update the server IP address:**
   - Open `lib/controllers/inventoryController.dart`
   - Change line 7: `final String _baseUrl = "http://YOUR_IP_ADDRESS:8080";`
   - Replace `YOUR_IP_ADDRESS` with your computer's IP address

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the mobile app:**
   ```bash
   flutter run
   ```

## 📱 How to Use

### Adding New Products

1. **Open the mobile app** and go to "Barcode Scanner"
2. **Scan a barcode** of a product
3. If the product is not found, tap **"Add Product"**
4. **Fill in the details:**
   - Product Name (required)
   - MRP (optional)
   - Initial Quantity
   - Take a photo (optional)
5. **Tap "Save Product"**

### Product In/Out Operations

1. **Scan a barcode** of an existing product
2. **Choose operation:**
   - **Product IN**: Add stock to inventory
   - **Product OUT**: Remove stock from inventory
3. **Fill recipient details** (for Product OUT):
   - Recipient Name
   - Phone Number
   - Take photo
   - Notes
4. **Confirm the transaction**

### Desktop Dashboard

1. **Open your browser** and go to `http://YOUR_IP_ADDRESS:8080`
2. **View real-time data:**
   - Total Products
   - Total Quantity
   - Total Transactions
   - Low Stock Items
3. **Browse Products** and **Transactions** tabs
4. **Auto-refresh** every 30 seconds

## 🔧 Configuration

### Changing Server IP

If your computer's IP address changes:

1. **Update the mobile app:**
   - Edit `lib/controllers/inventoryController.dart`
   - Change the `_baseUrl` to your new IP

2. **Restart the server** and mobile app

### Customizing the System

- **Database**: All data is stored in `server/inventory.db`
- **Images**: Product images are saved in `server/uploads/`
- **API Endpoints**: See `server/app.py` for all available APIs

## 🐛 Troubleshooting

### Server Won't Start
- Check if Python is installed: `python --version`
- Install dependencies: `pip install -r requirements.txt`
- Check if port 8080 is available

### Mobile App Can't Connect
- Ensure both devices are on the same WiFi
- Check the IP address in `inventoryController.dart`
- Verify the server is running: `http://localhost:8080`

### Barcode Scanner Not Working
- Check camera permissions in Android settings
- Ensure the barcode is clear and well-lit
- Try different barcode formats

## 📊 API Endpoints

The server provides these REST APIs:

- `GET /api/products` - Get all products
- `GET /api/products/{barcode}` - Get product by barcode
- `POST /api/products` - Add new product
- `GET /api/transactions` - Get all transactions
- `POST /api/transactions` - Add new transaction

## 🔒 Security Notes

- This system runs on your local network only
- No data is sent to external servers
- All data is stored locally on your computer
- Use only on trusted networks

## 📈 Future Enhancements

- User authentication
- Multiple warehouses
- Export/import data
- Barcode generation
- Advanced reporting
- Email notifications

## 🤝 Support

If you encounter any issues:

1. Check the console output for error messages
2. Verify network connectivity
3. Restart both server and mobile app
4. Check the troubleshooting section above

---

**Happy Inventory Management! 📦✨**
