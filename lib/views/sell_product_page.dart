import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class SellProductPage extends StatefulWidget {
  final Product product;
  const SellProductPage({Key? key, required this.product}) : super(key: key);

  @override
  State<SellProductPage> createState() => _SellProductPageState();
}

class _SellProductPageState extends State<SellProductPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  XFile? _pickedImage;

  @override
  void dispose() {
    _customerController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
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
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(
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
            _pickedImage = XFile(compressedFile.path);
          });
          
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

  void _submitSale() async {
    if (_formKey.currentState?.validate() ?? false) {
      final qty = int.parse(_quantityController.text);
      final url = Uri.parse('http://localhost:8080/api/transactions'); // Change to your server IP if needed
      final Map<String, dynamic> payload = {
        'barcode': widget.product.barcode,
        'transaction_type': 'OUT',
        'quantity': qty,
        'recipient_name': _customerController.text,
        'recipient_phone': _phoneController.text,
        'recipient_photo': null, // You can handle photo upload as base64 if needed
        'notes': _addressController.text,
      };
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sale submitted!')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.body}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sell Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.inventory_2, size: 40),
                title: Text(widget.product.name ?? 'N/A', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Barcode: ${widget.product.barcode}'),
                    Text('MRP: ₹${widget.product.mrp ?? 'N/A'}'),
                    Text('Stock: ${widget.product.quantity ?? 'N/A'}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _customerController,
                    decoration: InputDecoration(labelText: 'Customer Name'),
                    validator: (v) => v == null || v.isEmpty ? 'Enter customer name' : null,
                  ),
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(labelText: 'Address (optional)'),
                  ),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.isEmpty ? 'Enter phone number' : null,
                  ),
                  TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter quantity';
                      final qty = int.tryParse(v);
                      if (qty == null || qty <= 0) return 'Enter valid quantity';
                      if (widget.product.quantity != null && qty > widget.product.quantity!) return 'Not enough stock';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: Icon(Icons.photo_camera),
                        label: Text(_pickedImage == null ? 'Upload Photo (optional)' : 'Change Photo'),
                      ),
                      if (_pickedImage != null) ...[
                        SizedBox(width: 10),
                        Icon(Icons.check_circle, color: Colors.green),
                      ]
                    ],
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitSale,
                      child: Text('Submit Sale'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
