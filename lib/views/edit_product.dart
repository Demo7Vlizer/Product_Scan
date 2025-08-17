import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:eopystocknew/controllers/inventoryController.dart';
import 'package:eopystocknew/models/product.dart';
import 'package:eopystocknew/services/network/request_service.dart';

class EditProductPage extends StatefulWidget {
  final Product product;

  EditProductPage({required this.product});

  @override
  _EditProductPageState createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mrpController = TextEditingController();
  final _quantityController = TextEditingController();
  
  File? _imageFile;
  String? _imageBase64;
  bool _isLoading = false;
  final InventoryController _inventoryController = InventoryController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.product.name ?? '';
    _mrpController.text = widget.product.mrp?.toString() ?? '';
    _quantityController.text = widget.product.quantity?.toString() ?? '1';
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
      
      // Compress image with minimal compression for excellent text clarity
      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        minWidth: 900,        // Much larger for excellent text clarity
        minHeight: 900,       // Much larger for excellent text clarity
        quality: 85,          // High quality for very clear text
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
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (image != null) {
        final File originalFile = File(image.path);
        
        // Apply additional compression
        final File? compressedFile = await _compressImage(originalFile);
        
        if (compressedFile != null) {
          setState(() {
            _imageFile = compressedFile;
          });

          // Convert to base64 (without data URI prefix, will be added when sending)
          final bytes = await compressedFile.readAsBytes();
          _imageBase64 = base64Encode(bytes);
          
          print('Edit Product: Image processed successfully: ${bytes.length} bytes, base64 length: ${_imageBase64?.length ?? 0}');
          
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
      print('Error picking image: $e');
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

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final imageData = _imageBase64 != null
          ? 'data:image/jpeg;base64,$_imageBase64'
          : null;
      
      print('📝 Updating product with:');
      print('   Barcode: ${widget.product.barcode}');
      print('   Name: ${_nameController.text}');
      print('   Image data length: ${imageData?.length ?? 0} characters');
      if (imageData != null) {
        print('   Image data prefix: ${imageData.substring(0, 50)}...');
      }
      
      final product = Product(
        id: widget.product.id,
        barcode: widget.product.barcode,
        name: _nameController.text,
        mrp: _mrpController.text.isNotEmpty
            ? double.parse(_mrpController.text)
            : null,
        quantity: int.parse(_quantityController.text),
        imagePath: imageData, // Use the properly formatted imageData
      );

      await _inventoryController.updateProduct(widget.product.barcode!, product);

      // If image was updated, fetch the updated product to get the new image path
      final imageWasUpdated = imageData != null;
      if (imageWasUpdated) {
        try {
          final updatedProduct = await _inventoryController.getProduct(widget.product.barcode!);
          if (updatedProduct != null) {
            // Update the widget's product data with the new image path
            widget.product.imagePath = updatedProduct.imagePath;
            // Clear the temporary image state since we now have the server's image path
            setState(() {
              _imageFile = null;
              _imageBase64 = null;
            });
          }
        } catch (e) {
          print('Warning: Could not fetch updated product data: $e');
          // Continue anyway, the update was successful
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          'Delete Product',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.product.name}"? This action cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                color: Colors.grey.shade700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.red.shade200, width: 1),
              ),
            ),
            child: Text(
              'Delete',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _inventoryController.deleteProduct(widget.product.barcode!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
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
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = '${RequestClient.baseUrl}/uploads/${widget.product.imagePath}';
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Edit Product',
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
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200, width: 1),
            ),
            child: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade600, size: 20),
            onPressed: _isLoading ? null : _deleteProduct,
            tooltip: 'Delete Product',
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
              // Minimal barcode display
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.qr_code_outlined, color: Colors.grey.shade600, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Product Barcode',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      widget.product.barcode ?? '',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                        borderSide: BorderSide(color: Colors.blue, width: 1),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
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
                      prefixStyle: TextStyle(color: Colors.green.shade700, fontSize: 14, fontWeight: FontWeight.w500),
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
                        borderSide: BorderSide(color: Colors.blue, width: 1),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
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
                    'Quantity *',
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
                        borderSide: BorderSide(color: Colors.blue, width: 1),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
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
                          borderRadius: BorderRadius.circular(7),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : widget.product.imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error loading product image: $imageUrl');
                                  print('Error details: $error');
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt_outlined,
                                        size: 32,
                                        color: Colors.grey.shade400,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tap to change photo',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 32,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: 8),
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

              // Update button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Update Product',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 