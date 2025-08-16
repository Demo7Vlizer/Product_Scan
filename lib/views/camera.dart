import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:eopystocknew/controllers/inventoryController.dart';
import 'package:eopystocknew/models/product.dart';
import 'package:eopystocknew/views/add_product.dart';
import 'package:eopystocknew/views/sell_product_page.dart';
import 'package:eopystocknew/views/multi_item_sale.dart';
import 'package:eopystocknew/widgets/restock_dialog.dart';

class CameraPage extends StatefulWidget {
  CameraPage({Key? key, required this.title, this.returnBarcodeDirectly = false}) : super(key: key);

  final String title;
  final bool returnBarcodeDirectly; // If true, return barcode without showing product interface

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  String _scannedValue = "";
  bool _isLoading = false;
  Product? _scannedProduct;
  final InventoryController _inventoryController = InventoryController();
  bool _hasPermission = false;
  bool _canScan = true;
  DateTime? _lastScanTime;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (_scannerController == null) return;
    
    switch (state) {
      case AppLifecycleState.resumed:
        if (_hasPermission && !_isLoading) {
          try {
            _scannerController?.start();
            print('📷 Camera resumed');
          } catch (e) {
            print('❌ Error starting camera: $e');
          }
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        try {
          _scannerController?.stop();
          print('📷 Camera paused');
        } catch (e) {
          print('❌ Error stopping camera: $e');
        }
        break;
      default:
        break;
    }
  }

  Future<void> _initializeScanner() async {
    try {
      print('🔧 Initializing scanner...');
      
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: [BarcodeFormat.all],
        returnImage: false,
      );
      
      // Check camera permission
      await _checkCameraPermission();
      
      print('✅ Scanner initialized successfully');
    } catch (e) {
      print('❌ Error initializing scanner: $e');
      if (mounted) {
        setState(() {
          _hasPermission = false;
        });
      }
    }
  }

  Future<void> _checkCameraPermission() async {
    try {
      print('🔍 Checking camera permission...');
      
      // Try to start the scanner to check permission
      await _scannerController?.start();
      
      if (mounted) {
        setState(() {
          _hasPermission = true;
        });
        print('✅ Camera permission granted');
      }
    } catch (e) {
      print('❌ Camera permission denied or error: $e');
      if (mounted) {
        setState(() {
          _hasPermission = false;
        });
        
        // Show permission dialog
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.orange),
            SizedBox(width: 12),
            Text('Camera Permission'),
          ],
        ),
        content: Text(
          'This app needs camera permission to scan barcodes. Please grant camera permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkCameraPermission(); // Try again
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.flash_on),
            onPressed: () {
              // TODO: Implement flash toggle
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Flash feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Scanner view
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade300, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    if (!_hasPermission)
                      Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 64,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Camera permission required',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (barcodeCapture) {
                          // Prevent scanning if we can't scan or are already processing
                          if (!_canScan || _isLoading) {
                            return;
                          }

                          print('=== SCANNER DEBUG ===');
                          print(
                            'Barcode detected: ${barcodeCapture.barcodes.length} barcodes',
                          );

                          if (barcodeCapture.barcodes.isNotEmpty) {
                            final String? code =
                                barcodeCapture.barcodes.first.rawValue;
                            print('Raw barcode value: $code');

                            if (code != null) {
                              // Check if this is the same barcode we just scanned
                              final now = DateTime.now();
                              if (_lastScanTime != null && 
                                  _scannedValue == code && 
                                  now.difference(_lastScanTime!).inSeconds < 3) {
                                print('Ignoring duplicate scan within 3 seconds');
                                return;
                              }

                              print('Processing barcode: $code');
                              
                              // Disable scanning temporarily
                              _canScan = false;
                              _lastScanTime = now;
                              
                              if (mounted) {
                                setState(() {
                                  _scannedValue = code;
                                  _isLoading = true;
                                });
                              }
                              
                              _handleScannedCode(code);
                              
                              // Show success feedback
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Barcode detected: $code'),
                                  backgroundColor: Colors.grey.shade800,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                              
                              // Re-enable scanning after 2 seconds
                              Future.delayed(Duration(seconds: 2), () {
                                if (mounted) {
                                  _canScan = true;
                                }
                              });
                            } else {
                              print('Code is null');
                            }
                          } else {
                            print('No barcodes found in capture');
                          }
                          print('=== END DEBUG ===');
                        },
                      ),
                    // Scanner overlay with status
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Stack(
                          children: [
                            // Scanning frame
                            Center(
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.6,
                                height: MediaQuery.of(context).size.width * 0.6,
                                constraints: BoxConstraints(
                                  maxWidth: 250,
                                  maxHeight: 250,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _isLoading 
                                        ? Colors.orange 
                                        : _canScan 
                                            ? Colors.green 
                                            : Colors.red, 
                                    width: 3
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _isLoading
                                    ? Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            
                            // Status indicator
                            Positioned(
                              top: 20,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isLoading 
                                            ? Icons.hourglass_empty
                                            : _canScan 
                                                ? Icons.qr_code_scanner 
                                                : Icons.pause_circle_outline,
                                        color: _isLoading 
                                            ? Colors.orange 
                                            : _canScan 
                                                ? Colors.green 
                                                : Colors.red,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        _isLoading 
                                            ? 'Processing...' 
                                            : _canScan 
                                                ? 'Ready to scan' 
                                                : 'Scanning paused',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Result display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_isLoading)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Searching product...'),
                      ],
                    ),
                  ),

                if (_scannedProduct != null) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Product Found!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Code: ${_scannedProduct!.barcode}',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Name: ${_scannedProduct!.name ?? 'N/A'}',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          'MRP: ${_scannedProduct!.mrp != null ? '₹${_scannedProduct!.mrp}' : 'N/A'}',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _scannedProduct!.quantity != null && _scannedProduct!.quantity! > 0
                                    ? () => _showSellOptions()
                                    : () => _showOutOfStockDialog(),
                                icon: Icon(Icons.shopping_cart_checkout),
                                label: Text('Sell'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _scannedProduct!.quantity != null && _scannedProduct!.quantity! > 0
                                      ? Colors.green
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _restockProduct(),
                                icon: Icon(Icons.add_box),
                                label: Text('Restock'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else if (_scannedValue.isNotEmpty && !_isLoading) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Product Not Found',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Scanned Code: $_scannedValue',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          'This product is not in your inventory. Do you want to add this product?',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _addNewProduct(_scannedValue),
                            icon: Icon(Icons.add),
                            label: Text('Add This Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    'Scan a barcode to find product information',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],

                SizedBox(height: 20),

                // Action buttons
                if (_scannedValue.isNotEmpty || _scannedProduct != null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _scannedValue = "";
                                _scannedProduct = null;
                                _isLoading = false;
                                _canScan = true;
                                _lastScanTime = null;
                              });
                            }
                          },
                          icon: Icon(Icons.refresh_rounded, size: 18),
                          label: Text("Scan Again"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade600,
                            side: BorderSide(color: Colors.blue.shade300),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScannedCode(String code) async {
    print('🔍 Handling scanned code: $code');
    
    // If we should return barcode directly, do so immediately
    if (widget.returnBarcodeDirectly) {
      print('↩️ Returning barcode directly: $code');
      Navigator.pop(context, code);
      return;
    }
    
    try {
      print('🌐 Making API request for barcode: $code');
      final product = await _inventoryController.getProduct(code);
      
      if (product != null) {
        print('✅ Product found: ${product.name} (${product.barcode})');
        if (mounted) {
          setState(() {
            _scannedProduct = product;
            _isLoading = false;
          });
          
          // Re-enable scanning after 2 seconds for next scan
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _canScan = true;
              });
              print('🔄 Scanning re-enabled');
            }
          });
        }
      } else {
        print('❌ Product not found for barcode: $code');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // Re-enable scanning immediately for product not found
          _canScan = true;
        }
      }
    } catch (e) {
      print('❌ Error handling scanned code: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Re-enable scanning on error
        _canScan = true;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Network Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleScannedCode(code),
            ),
          ),
        );
      }
    }
  }

  void _showSellOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.green),
            SizedBox(width: 8),
            Text('Sell Product'),
          ],
        ),
        content: Text('How would you like to sell this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _sellSingleProduct();
            },
            icon: Icon(Icons.shopping_bag),
            label: Text('Single Sale'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _sellMultipleProducts();
            },
            icon: Icon(Icons.shopping_cart),
            label: Text('Multi-Item Sale'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _sellSingleProduct() async {
    if (_scannedProduct == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellProductPage(product: _scannedProduct!),
      ),
    );
    if (result == true) {
      _handleScannedCode(_scannedProduct!.barcode!);
    }
  }

  void _sellMultipleProducts() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiItemSalePage(),
      ),
    );
    if (result == true) {
      _handleScannedCode(_scannedProduct!.barcode!);
    }
  }

  void _showOutOfStockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Out of Stock'),
          ],
        ),
        content: Text(
          'This product is currently out of stock. You can restock it or still process a sale (which will result in negative stock).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _restockProduct();
            },
            icon: Icon(Icons.add_box),
            label: Text('Restock'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _sellSingleProduct();
            },
            icon: Icon(Icons.shopping_cart),
            label: Text('Sell Anyway'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _restockProduct() async {
    if (_scannedProduct == null) return;
    
    final result = await showRestockDialog(context, _scannedProduct!);
    
    if (result == true) {
      // Refresh the product information
      _handleScannedCode(_scannedProduct!.barcode!);
    }
  }

  void _addNewProduct(String barcode) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductPage(barcode: barcode),
      ),
    );

    if (result == true) {
      // Product was added, refresh the scan
      _handleScannedCode(barcode);
    }
  }
}
