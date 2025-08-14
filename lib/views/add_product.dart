import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:eopystocknew/controllers/inventoryController.dart';
import 'package:eopystocknew/models/product.dart';

class AddProductPage extends StatefulWidget {
  final String barcode;

  const AddProductPage({Key? key, required this.barcode}) : super(key: key);

  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mrpController = TextEditingController();
  final _quantityController = TextEditingController();
  final _inventoryController = InventoryController();

  File? _imageFile;
  String? _imageBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mrpController.dispose();
    _quantityController.dispose();
    super.dispose();
  }



  /// Advanced image compression for smaller file sizes
  Future<File?> _compressImage(File imageFile) async {
    try {
      // Get temporary directory for compressed images
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
      final String targetPath = '${tempDir.path}/$fileName';
      
      // Compress image with aggressive settings
      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        minWidth: 600,        // Reduced from 1200
        minHeight: 600,       // Reduced from 1200
        quality: 60,          // Reduced from 85 for smaller size
        rotate: 0,
        format: CompressFormat.jpeg,
      );
      
      if (compressedFile != null) {
        final File compressedImageFile = File(compressedFile.path);
        
        // Log compression results
        final originalSize = await imageFile.length();
        final compressedSize = await compressedImageFile.length();
        final compressionRatio = (originalSize / compressedSize).toStringAsFixed(1);
        
        print('Image compression: ${(originalSize / 1024).toStringAsFixed(1)}KB → ${(compressedSize / 1024).toStringAsFixed(1)}KB (${compressionRatio}x smaller)');
        
        return compressedImageFile;
      }
    } catch (e) {
      print('Error compressing image: $e');
      // Return original file if compression fails
      return imageFile;
    }
    
    return null;
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,          // Reduced from previous
        maxHeight: 800,         // Reduced from previous
        imageQuality: 70,       // Reduced from 75
      );

      if (image != null) {
        final File originalFile = File(image.path);
        
        // Apply additional compression
        final File? compressedFile = await _compressImage(originalFile);
        
        if (compressedFile != null) {
          setState(() {
            _imageFile = compressedFile;
          });

          // Convert to base64 with proper data URI format
          final bytes = await compressedFile.readAsBytes();
          _imageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
          
          // Clean up original file if different from compressed
          if (originalFile.path != compressedFile.path) {
            try {
              await originalFile.delete();
            } catch (e) {
              print('Could not delete original file: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error picking product image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final product = Product(
        barcode: widget.barcode,
        name: _nameController.text,
        mrp: _mrpController.text.isNotEmpty
            ? double.parse(_mrpController.text)
            : null,
        quantity: int.parse(_quantityController.text),
        imagePath: _imageBase64 != null
            ? 'data:image/jpeg;base64,$_imageBase64'
            : null,
      );

      await _inventoryController.addProduct(product);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product added successfully!'),
            backgroundColor: Colors.grey.shade800,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.grey.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Add New Product',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: IconButton(
              icon: Icon(Icons.qr_code_outlined, color: Colors.grey.shade600, size: 20),
              onPressed: () {
                Navigator.pushNamed(context, '/camera');
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barcode display - Minimalistic
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Icon(Icons.qr_code_outlined, color: Colors.grey.shade600, size: 16),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                            'QR Code Scanned:',
                      style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                    SelectableText(
                      widget.barcode,
                      style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Product name
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Name *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter product name',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade500, width: 1),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 14),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter product name';
                  }
                  return null;
                },
                  ),
                ],
              ),

              SizedBox(height: 16),

              // MRP
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MRP (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 6),
              TextFormField(
                controller: _mrpController,
                decoration: InputDecoration(
                  hintText: 'Enter MRP',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade500, width: 1),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 14),
                keyboardType: TextInputType.number,
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Quantity
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Initial Quantity *',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 6),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  hintText: 'Enter quantity',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade500, width: 1),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                    style: TextStyle(fontSize: 14),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                  ),
                ],
              ),

              SizedBox(height: 24),

              // Image section
              Text(
                'Product Image (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 8),

              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300, width: 1),
                              ),
                              child: Icon(
                                Icons.camera_alt_outlined,
                                size: 24,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Tap to take photo',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              SizedBox(height: 32),

              // Save and Cancel buttons
              Row(
                children: [
                  Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProduct,
                        style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.grey.shade700,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                        ),
                        child: _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.grey.shade600,
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                                'Save Product',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
