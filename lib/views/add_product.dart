import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Product'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barcode display (read-only, visually distinct)
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
                    Text(
                      'Scanned Barcode:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    SelectableText(
                      widget.barcode,
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
                  labelText: 'Initial Quantity *',
                  hintText: 'Enter quantity',
                  prefixIcon: Icon(Icons.numbers),
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

              // Save and Cancel buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                'Save Product',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue),
                        ),
                        child: Text('Cancel', style: TextStyle(fontSize: 16)),
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
