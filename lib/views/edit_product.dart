import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });

      // Convert to base64
      List<int> imageBytes = await _imageFile!.readAsBytes();
      _imageBase64 = base64Encode(imageBytes);
    }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final product = Product(
        id: widget.product.id,
        barcode: widget.product.barcode,
        name: _nameController.text,
        mrp: _mrpController.text.isNotEmpty
            ? double.parse(_mrpController.text)
            : null,
        quantity: int.parse(_quantityController.text),
        imagePath: _imageBase64 != null
            ? 'data:image/jpeg;base64,$_imageBase64'
            : widget.product.imagePath,
      );

      await _inventoryController.updateProduct(widget.product.barcode!, product);

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
        title: Text('Delete Product'),
        content: Text('Are you sure you want to delete "${widget.product.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
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
      appBar: AppBar(
        title: Text('Edit Product'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: _isLoading ? null : _deleteProduct,
            tooltip: 'Delete Product',
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
              // Product info display
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.qr_code, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Product Barcode:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      widget.product.barcode ?? '',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Product name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Product Name *',
                  hintText: 'Enter product name',
                  prefixIcon: Icon(Icons.inventory),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter product name';
                  }
                  return null;
                },
              ),

              SizedBox(height: 16),

              // MRP
              TextFormField(
                controller: _mrpController,
                decoration: InputDecoration(
                  labelText: 'MRP (Optional)',
                  hintText: 'Enter MRP',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),

              SizedBox(height: 16),

              // Quantity
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  hintText: 'Enter quantity',
                  prefixIcon: Icon(Icons.shopping_cart),
                  border: OutlineInputBorder(),
                ),
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

              SizedBox(height: 24),

              // Image section
              Text(
                'Product Image (Optional)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),

              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : widget.product.imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tap to change photo',
                                        style: TextStyle(color: Colors.grey.shade600),
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
                                  Icons.camera_alt,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to take photo',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                ),
              ),

              SizedBox(height: 32),

              // Update button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Update Product',
                          style: TextStyle(fontSize: 16),
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