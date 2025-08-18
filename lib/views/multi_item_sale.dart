import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/product.dart';
import '../models/transaction.dart';
import '../controllers/inventoryController.dart';

// Customer Model
class Customer {
  final String? id;
  final String name;
  final String phone;
  final String? notes;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'notes': notes,
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id']?.toString(),
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        notes: json['notes'],
      );
}

// Cart Item Model
class CartItem {
  final Product product;
  int quantity;
  final double? customPrice;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.customPrice,
  });

  double get totalPrice => (customPrice ?? product.mrp ?? 0.0) * quantity;
}

class MultiItemSalePage extends StatefulWidget {
  const MultiItemSalePage({Key? key}) : super(key: key);

  @override
  State<MultiItemSalePage> createState() => _MultiItemSalePageState();
}

class _MultiItemSalePageState extends State<MultiItemSalePage> {
  final InventoryController _inventoryController = InventoryController();
  final TextEditingController _customerSearchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  Customer? _selectedCustomer;
  List<Customer> _searchResults = [];
  List<CartItem> _cartItems = [];
  bool _isLoading = false;
  bool _isSearching = false;
  Timer? _searchTimer;
  
  // Photo related variables
  List<File> _salePhotoFiles = [];
  List<String> _salePhotosBase64 = [];
  bool _isCapturingPhoto = false;

  // Responsive breakpoints
  late double _screenWidth;
  late double _screenHeight;
  late bool _isTablet;
  late bool _isLandscape;

  @override
  void dispose() {
    _customerSearchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _isTablet = _screenWidth > 600;
    _isLandscape = _screenWidth > _screenHeight;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: _isLandscape && _isTablet ? _buildTabletLandscapeLayout() : _buildMobileLayout(),
      ),
      bottomNavigationBar: SafeArea(child: _buildActionButton()),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Multi-Item Sale',
        style: TextStyle(
          fontSize: _isTablet ? 22 : 18,
          fontWeight: FontWeight.w600,
        ),
      ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      actions: [
        if (_cartItems.isNotEmpty)
          IconButton(
            icon: Icon(Icons.refresh, size: _isTablet ? 26 : 22),
            onPressed: _clearCart,
            tooltip: 'Clear Cart',
          ),
        IconButton(
          icon: Icon(Icons.info_outline, size: _isTablet ? 26 : 22),
          onPressed: _showHelpDialog,
          tooltip: 'Help',
        ),
      ],
    );
  }

  Widget _buildTabletLandscapeLayout() {
    return Row(
      children: [
        // Left Panel - Customer & Photo
        Expanded(
          flex: 1,
          child: Container(
            padding: EdgeInsets.all(_isTablet ? 20 : 16),
        child: Column(
              children: [
                _buildCustomerSection(),
                SizedBox(height: _isTablet ? 24 : 16),
                _buildCompactPhotoSection(),
              ],
            ),
          ),
        ),
        // Right Panel - Cart
        Expanded(
          flex: 2,
          child: Container(
            padding: EdgeInsets.all(_isTablet ? 20 : 16),
            child: _buildCartContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
          children: [
            // Customer Selection Section
            _buildCustomerSection(),
            
            // Cart Section with Photo
            Expanded(
              child: _buildCartSectionWithPhoto(),
            ),
          ],
    );
  }

  Widget _buildCustomerSection() {
    return Container(
      margin: EdgeInsets.all(_isTablet ? 20 : 16),
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
        borderRadius: BorderRadius.circular(_isTablet ? 16 : 12),
                    boxShadow: [
                      BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: _isTablet ? 15 : 10,
            offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Text(
            'Customer',
                      style: TextStyle(
              fontSize: _isTablet ? 22 : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
          SizedBox(height: _isTablet ? 16 : 12),
                
                // Search Field
          TextField(
                    controller: _customerSearchController,
                    decoration: InputDecoration(
              hintText: 'Search by name or phone...',
              hintStyle: TextStyle(fontSize: _isTablet ? 16 : 14),
              prefixIcon: Icon(Icons.search, size: _isTablet ? 24 : 20),
              suffixIcon: IconButton(
                icon: Icon(Icons.person_add, size: _isTablet ? 24 : 20),
                onPressed: _createNewCustomer,
                tooltip: 'Add New Customer',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: _isTablet ? 20 : 16, 
                vertical: _isTablet ? 16 : 12,
            ),
            ),
            style: TextStyle(fontSize: _isTablet ? 16 : 14),
            onChanged: _handleSearchInput,
          ),
          
          // Selected Customer Display
          if (_selectedCustomer != null) ...[
            SizedBox(height: _isTablet ? 16 : 12),
                Container(
                  width: double.infinity,
              padding: EdgeInsets.all(_isTablet ? 16 : 12),
                        decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
                border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                  CircleAvatar(
                    radius: _isTablet ? 20 : 16,
                    backgroundColor: Colors.green.shade100,
                    child: Text(
                      _selectedCustomer!.name.isNotEmpty ? _selectedCustomer!.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: _isTablet ? 16 : 14,
                      ),
                    ),
                  ),
                  SizedBox(width: _isTablet ? 16 : 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                          _selectedCustomer!.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: _isTablet ? 16 : 14,
                          ),
                        ),
                                    Text(
                                      _selectedCustomer!.phone,
                                      style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: _isTablet ? 14 : 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Notes icon
                            if (_selectedCustomer!.notes != null && _selectedCustomer!.notes!.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(right: _isTablet ? 8 : 4),
                                child: GestureDetector(
                                  onTap: () => _showCustomerNotes(_selectedCustomer!.name, _selectedCustomer!.notes!),
                                  child: Icon(
                                    Icons.sticky_note_2_outlined,
                                    color: Colors.orange.shade600,
                                    size: _isTablet ? 24 : 20,
                                  ),
                                ),
                              ),
                  IconButton(
                    icon: Icon(Icons.close, size: _isTablet ? 22 : 18),
                    onPressed: () => setState(() => _selectedCustomer = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
            ),
          ],
                
                // Search Results
          if (_isSearching && _searchResults.isNotEmpty) ...[
            SizedBox(height: _isTablet ? 12 : 8),
                  Container(
              constraints: BoxConstraints(maxHeight: _isTablet ? 200 : 150),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
              ),
              child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final customer = _searchResults[index];
                  return ListTile(
                    dense: !_isTablet,
                          leading: CircleAvatar(
                      radius: _isTablet ? 20 : 16,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                              style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: _isTablet ? 14 : 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    title: Text(
                      customer.name, 
                      style: TextStyle(fontSize: _isTablet ? 16 : 14),
                    ),
                    subtitle: Text(
                      customer.phone, 
                      style: TextStyle(fontSize: _isTablet ? 14 : 12),
                    ),
                          onTap: () => _selectCustomer(customer),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildCartSectionWithPhoto() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: _isTablet ? 20 : 16),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(
                top: _isTablet ? 12 : 8, 
                bottom: _isTablet ? 24 : 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Photo Section
                  _buildCompactPhotoSection(),
                  
                  SizedBox(height: _isTablet ? 24 : 16),
                  
                  // Cart Section
                  _buildCartContent(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactPhotoSection() {
    return Container(
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_isTablet ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: _isTablet ? 15 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Sale Photos (${_salePhotoFiles.length})',
                  style: TextStyle(
                    fontSize: _isTablet ? 18 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_isCapturingPhoto)
                Row(
                  children: [
                    _buildCompactActionButton(
                      icon: Icons.camera_alt,
                      color: Colors.blue,
                      onTap: () => _capturePhoto(ImageSource.camera),
                      tooltip: 'Camera',
                    ),
                    SizedBox(width: _isTablet ? 6 : 4),
                    _buildCompactActionButton(
                      icon: Icons.photo_library,
                      color: Colors.green,
                      onTap: () => _capturePhoto(ImageSource.gallery),
                      tooltip: 'Gallery',
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: _isTablet ? 12 : 8),
          
          if (_isCapturingPhoto) ...[
            Container(
              height: _isTablet ? 120 : 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: _isTablet ? 20 : 16,
                      height: _isTablet ? 20 : 16,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: _isTablet ? 16 : 12),
                    Text(
                      'Processing...', 
                      style: TextStyle(fontSize: _isTablet ? 14 : 12),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_salePhotoFiles.isNotEmpty) ...[
            // Enhanced photo grid with unlimited scrolling
            SizedBox(
              height: _isTablet ? 80 : 65,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _salePhotoFiles.length + 1, // +1 for add button
                itemBuilder: (context, index) {
                  if (index == _salePhotoFiles.length) {
                    // Add more button as last item
                    return Container(
                      margin: EdgeInsets.only(left: _isTablet ? 8 : 6),
                      child: InkWell(
                        onTap: () => _showPhotoOptions(),
                        borderRadius: BorderRadius.circular(_isTablet ? 8 : 6),
                        child: Container(
                          width: _isTablet ? 80 : 65,
                          height: _isTablet ? 80 : 65,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(_isTablet ? 8 : 6),
                            border: Border.all(
                              color: Colors.blue.shade300,
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: _isTablet ? 24 : 20,
                                color: Colors.blue.shade600,
                              ),
                              SizedBox(height: _isTablet ? 4 : 2),
                              Text(
                                'Add',
                                style: TextStyle(
                                  fontSize: _isTablet ? 10 : 8,
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    // Photo thumbnail
                    return Container(
                      margin: EdgeInsets.only(right: _isTablet ? 8 : 6),
                      child: _buildEnhancedPhotoThumbnail(index),
                    );
                  }
                },
              ),
            ),
          ] else ...[
            InkWell(
              onTap: _showPhotoOptions,
              borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
              child: Container(
                height: _isTablet ? 80 : 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo, 
                        size: _isTablet ? 24 : 20, 
                        color: Colors.grey.shade500,
                      ),
                      SizedBox(width: _isTablet ? 12 : 8),
                      Text(
                        'Add Sale Photo',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: _isTablet ? 16 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_isTablet ? 6 : 4),
        child: Container(
          padding: EdgeInsets.all(_isTablet ? 8 : 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(_isTablet ? 6 : 4),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(
            icon,
            size: _isTablet ? 16 : 14,
            color: color,
          ),
        ),
      ),
    );
  }



  Widget _buildEnhancedPhotoThumbnail(int index) {
    return Container(
      width: _isTablet ? 80 : 65,
      height: _isTablet ? 80 : 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_isTablet ? 8 : 6),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_isTablet ? 8 : 6),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Image.file(
                _salePhotoFiles[index],
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Photo number indicator
          Positioned(
            bottom: 2,
            left: 2,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _isTablet ? 10 : 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Remove button
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _removePhoto(index),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(_isTablet ? 4 : 3),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: _isTablet ? 12 : 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildCartContent() {
    return Container(
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_isTablet ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: _isTablet ? 15 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                    Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
              Text(
                'Cart',
                          style: TextStyle(
                  fontSize: _isTablet ? 22 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
              if (_cartItems.isNotEmpty)
                TextButton.icon(
                  onPressed: _scanProduct,
                  icon: Icon(Icons.qr_code_scanner, size: _isTablet ? 22 : 18),
                  label: Text(
                    'Add Item',
                    style: TextStyle(fontSize: _isTablet ? 16 : 14),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(
                      horizontal: _isTablet ? 16 : 12, 
                      vertical: _isTablet ? 12 : 8,
                    ),
                                  ),
                                ),
                              ],
                            ),
          SizedBox(height: _isTablet ? 16 : 12),
          
                  if (_cartItems.isEmpty) ...[
            // Empty Cart State
                    Container(
              constraints: BoxConstraints(
                minHeight: _isTablet ? 250 : 180,
                maxHeight: _isTablet ? 400 : 300,
              ),
              child: Center(
                child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                        children: [
                    Icon(
                            Icons.shopping_cart_outlined,
                        size: _isTablet ? 80 : 48,
                      color: Colors.grey.shade400,
                          ),
                      SizedBox(height: _isTablet ? 20 : 12),
                          Text(
                      'No items in cart',
                            style: TextStyle(
                          fontSize: _isTablet ? 20 : 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                        textAlign: TextAlign.center,
                    ),
                      SizedBox(height: _isTablet ? 12 : 6),
                          Text(
                      'Scan products to add them',
                            style: TextStyle(
                          fontSize: _isTablet ? 16 : 14,
                              color: Colors.grey.shade500,
                            ),
                        textAlign: TextAlign.center,
                          ),
                      SizedBox(height: _isTablet ? 32 : 20),
                    ElevatedButton.icon(
                            onPressed: _scanProduct,
                        icon: Icon(Icons.qr_code_scanner, size: _isTablet ? 24 : 20),
                        label: Text(
                          'Scan Product',
                          style: TextStyle(fontSize: _isTablet ? 16 : 14),
                        ),
                            style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: _isTablet ? 32 : 20, 
                            vertical: _isTablet ? 16 : 10,
                          ),
                              shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
                              ),
                            ),
                          ),
                        ],
                  ),
                ),
                      ),
                    ),
                  ] else ...[
                    // Cart Items List
                    Column(
                      children: [
                        for (int index = 0; index < _cartItems.length; index++)
                  _buildCartItem(index),
              ],
            ),
            
            SizedBox(height: _isTablet ? 20 : 16),
            // Cart Total
                          Container(
              padding: EdgeInsets.all(_isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: _isTablet ? 20 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '₹${_calculateTotal().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: _isTablet ? 24 : 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  if (_salePhotoFiles.isNotEmpty) ...[
                    SizedBox(height: _isTablet ? 12 : 8),
                    Row(
                      children: [
                        Icon(
                          Icons.photo_camera,
                          size: _isTablet ? 20 : 16,
                          color: Colors.green.shade600,
                        ),
                        SizedBox(width: _isTablet ? 8 : 6),
                        Text(
                          '${_salePhotoFiles.length} photo${_salePhotoFiles.length == 1 ? '' : 's'} attached',
                          style: TextStyle(
                            fontSize: _isTablet ? 14 : 12,
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartItem(int index) {
    final item = _cartItems[index];
    return Container(
      margin: EdgeInsets.only(bottom: _isTablet ? 12 : 8),
      padding: EdgeInsets.all(_isTablet ? 16 : 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                        // Product Image/Icon
                                Container(
            width: _isTablet ? 60 : 40,
            height: _isTablet ? 60 : 40,
                                decoration: BoxDecoration(
                                    color: Colors.white,
              borderRadius: BorderRadius.circular(_isTablet ? 8 : 6),
                            border: Border.all(color: Colors.grey.shade300),
                                ),
            child: item.product.imagePath != null
                                    ? ClipRRect(
                    borderRadius: BorderRadius.circular(_isTablet ? 8 : 6),
                                        child: Image.network(
                      '${_inventoryController.baseUrl}/uploads/${item.product.imagePath}',
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            print('Error loading product image: ${_inventoryController.baseUrl}/uploads/${item.product.imagePath}');
                                            print('Error details: $error');
                                            return Icon(
                            Icons.inventory_2_outlined, 
                            color: Colors.grey.shade400, 
                            size: _isTablet ? 28 : 20,
                          );
                                          },
                    ),
                  )
                : Icon(
                    Icons.inventory_2_outlined, 
                    color: Colors.grey.shade400, 
                    size: _isTablet ? 28 : 20,
                  ),
          ),
          SizedBox(width: _isTablet ? 16 : 12),
                        
                                // Product Details
                                Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                      Text(
                  item.product.name ?? 'Unknown Product',
                  style: TextStyle(
                                          fontWeight: FontWeight.w500,
                    fontSize: _isTablet ? 16 : 14,
                                        ),
                                      ),
                SizedBox(height: _isTablet ? 4 : 2),
                                      Text(
                  '₹${item.product.mrp ?? 0} × ${item.quantity}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                    fontSize: _isTablet ? 14 : 12,
                                        ),
                                      ),
                                  Text(
                  'Stock: ${item.product.quantity ?? 0}',
                                    style: TextStyle(
                    color: (item.product.quantity ?? 0) < item.quantity
                                      ? Colors.red
                                      : Colors.green,
                    fontSize: _isTablet ? 12 : 11,
                                          fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                                ),
                        
                                // Quantity Controls
                        Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                      InkWell(
                onTap: () => _updateQuantity(index, item.quantity - 1),
                                        child: Container(
                  padding: EdgeInsets.all(_isTablet ? 6 : 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                    borderRadius: BorderRadius.circular(_isTablet ? 6 : 4),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                  child: Icon(
                    Icons.remove, 
                    size: _isTablet ? 20 : 16, 
                    color: Colors.red.shade400,
                  ),
                                        ),
                                      ),
                                      Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isTablet ? 16 : 12, 
                  vertical: _isTablet ? 6 : 4,
                ),
                                        child: Text(
                  '${item.quantity}',
                  style: TextStyle(
                    fontSize: _isTablet ? 16 : 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                onTap: () => _updateQuantity(index, item.quantity + 1),
                                        child: Container(
                  padding: EdgeInsets.all(_isTablet ? 6 : 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                    borderRadius: BorderRadius.circular(_isTablet ? 6 : 4),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                  child: Icon(
                    Icons.add, 
                    size: _isTablet ? 20 : 16, 
                    color: Colors.green.shade400,
                  ),
                                        ),
                                  ),
                                ],
                              ),
          SizedBox(width: _isTablet ? 12 : 8),
                        
                                // Delete Button
                                InkWell(
                                  onTap: () => _removeItem(index),
                                  child: Container(
              padding: EdgeInsets.all(_isTablet ? 6 : 4),
              child: Icon(
                Icons.delete_outline, 
                size: _isTablet ? 22 : 18, 
                color: Colors.red.shade400,
              ),
                            ),
                        ),
                      ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Container(
      padding: EdgeInsets.all(_isTablet ? 20 : 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canCheckout() ? _processSale : null,
                                  style: ElevatedButton.styleFrom(
            backgroundColor: _canCheckout() ? Colors.green : Colors.grey.shade300,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: _isTablet ? 20 : 16),
                                      shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_isTablet ? 16 : 12),
                                      ),
            elevation: 0,
          ),
          child: _isLoading
              ? SizedBox(
                  width: _isTablet ? 24 : 20,
                  height: _isTablet ? 24 : 20,
                  child: const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment, size: _isTablet ? 24 : 20),
                    SizedBox(width: _isTablet ? 12 : 8),
                    Text(
                      _isLoading ? 'Processing...' : 'Complete Sale',
                      style: TextStyle(
                        fontSize: _isTablet ? 18 : 16,
                        fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
        ),
      ),
    );
  }

  // Customer Search and Selection Methods
  void _handleSearchInput(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      _searchCustomers(query);
    });
  }

  void _searchCustomers(String query) async {
    if (query.isEmpty) {
        setState(() {
          _isSearching = false;
          _searchResults.clear();
        });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _inventoryController.searchCustomers(query);
        setState(() {
          _searchResults = results.map((data) => Customer.fromJson(data)).toList();
        _isSearching = _searchResults.isNotEmpty;
        });
    } catch (e) {
        setState(() {
          _searchResults.clear();
          _isSearching = false;
        });
        
      _showErrorSnackBar('Error searching customers: ${e.toString()}');
    }
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _isSearching = false;
      _searchResults.clear();
      _customerSearchController.clear();
    });
  }

  void _createNewCustomer() async {
    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => _CreateCustomerDialog(
        inventoryController: _inventoryController,
        isTablet: _isTablet,
      ),
    );

    if (result != null) {
      _selectCustomer(result);
    }
  }

  void _showCustomerNotes(String customerName, String notes) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_isTablet ? 20 : 16),
          ),
          child: Container(
            padding: EdgeInsets.all(_isTablet ? 24 : 20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: _isTablet ? 500 : double.infinity,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.sticky_note_2,
                      color: Colors.orange.shade600,
                      size: _isTablet ? 28 : 24,
                    ),
                    SizedBox(width: _isTablet ? 12 : 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Notes',
                            style: TextStyle(
                              fontSize: _isTablet ? 20 : 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            customerName,
                            style: TextStyle(
                              fontSize: _isTablet ? 14 : 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close),
                      iconSize: _isTablet ? 24 : 20,
                    ),
                  ],
                ),
                
                SizedBox(height: _isTablet ? 20 : 16),
                
                // Notes content
                Flexible(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(_isTablet ? 16 : 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(_isTablet ? 12 : 8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        notes,
                        style: TextStyle(
                          fontSize: _isTablet ? 16 : 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: _isTablet ? 20 : 16),
                
                // Close button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: _isTablet ? 20 : 16,
                        vertical: _isTablet ? 12 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_isTablet ? 10 : 8),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(fontSize: _isTablet ? 16 : 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Product Scanning and Cart Management
  void _scanProduct() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ProductScannerPage(
          onProductScanned: (product) {
            _addToCart(product);
          },
          isTablet: _isTablet,
        ),
      ),
    );
  }

  void _addToCart(Product product) {
    final existingIndex = _cartItems.indexWhere(
      (item) => item.product.barcode == product.barcode,
    );

    setState(() {
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity++;
      } else {
        _cartItems.add(CartItem(product: product));
      }
    });

    _showSuccessSnackBar('${product.name} added to cart');
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeItem(index);
      return;
    }

    final maxStock = _cartItems[index].product.quantity ?? 0;
    if (newQuantity > maxStock) {
      _showErrorSnackBar('Insufficient stock. Available: $maxStock');
      return;
    }

    setState(() {
      _cartItems[index].quantity = newQuantity;
    });
  }

  void _removeItem(int index) {
    final productName = _cartItems[index].product.name;
    setState(() {
      _cartItems.removeAt(index);
    });
    _showInfoSnackBar('$productName removed from cart');
  }

  double _calculateTotal() {
    return _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  bool _canCheckout() {
    return _selectedCustomer != null && 
           _cartItems.isNotEmpty && 
           !_isLoading &&
           _cartItems.every((item) => (item.product.quantity ?? 0) >= item.quantity);
  }

  void _clearCart() {
    if (_cartItems.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to remove all items from the cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _cartItems.clear();
              });
              Navigator.pop(context);
              _showInfoSnackBar('Cart cleared');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // Photo Management Methods
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_isTablet ? 24 : 20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(_isTablet ? 28 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _isTablet ? 50 : 40,
                height: _isTablet ? 5 : 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(_isTablet ? 3 : 2),
                ),
              ),
              SizedBox(height: _isTablet ? 28 : 20),
              Text(
                'Add Sale Photo',
                style: TextStyle(
                  fontSize: _isTablet ? 24 : 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: _isTablet ? 28 : 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _capturePhoto(ImageSource.camera);
                      },
                      borderRadius: BorderRadius.circular(_isTablet ? 16 : 12),
                      child: Container(
                        padding: EdgeInsets.all(_isTablet ? 28 : 20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(_isTablet ? 16 : 12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: _isTablet ? 48 : 40,
                              color: Colors.blue.shade700,
                            ),
                            SizedBox(height: _isTablet ? 12 : 8),
                            Text(
                              'Camera',
                              style: TextStyle(
                                fontSize: _isTablet ? 18 : 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: _isTablet ? 20 : 16),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _capturePhoto(ImageSource.gallery);
                      },
                      borderRadius: BorderRadius.circular(_isTablet ? 16 : 12),
                      child: Container(
                        padding: EdgeInsets.all(_isTablet ? 28 : 20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(_isTablet ? 16 : 12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.photo_library,
                              size: _isTablet ? 48 : 40,
                              color: Colors.green.shade700,
                            ),
                            SizedBox(height: _isTablet ? 12 : 8),
                            Text(
                              'Gallery',
                              style: TextStyle(
                                fontSize: _isTablet ? 18 : 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _isTablet ? 28 : 20),
            ],
          ),
        );
      },
    );
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

  void _capturePhoto(ImageSource source) async {
    setState(() {
      _isCapturingPhoto = true;
    });

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,          // Reduced from 1024
        maxHeight: 800,         // Reduced from 1024
        imageQuality: 70,       // Reduced from 80
      );

      if (photo != null) {
        final File originalFile = File(photo.path);
        
        // Apply additional compression
        final File? compressedFile = await _compressImage(originalFile);
        
        if (compressedFile != null) {
          final bytes = await compressedFile.readAsBytes();
          final base64Image = base64Encode(bytes);
          
          setState(() {
            _salePhotoFiles.add(compressedFile);
            _salePhotosBase64.add('data:image/jpeg;base64,$base64Image');
            _isCapturingPhoto = false;
          });
          
          // Clean up original file if different from compressed
          if (originalFile.path != compressedFile.path) {
            try {
              await originalFile.delete();
            } catch (e) {
              print('Could not delete original file: $e');
            }
          }
          
          _showSuccessSnackBar('Photo ${_salePhotoFiles.length} added!');
        } else {
          setState(() {
            _isCapturingPhoto = false;
          });
          _showErrorSnackBar('Error compressing image');
        }
      } else {
        setState(() {
          _isCapturingPhoto = false;
        });
      }
    } catch (e) {
      setState(() {
        _isCapturingPhoto = false;
      });

      _showErrorSnackBar('Error capturing photo: $e');
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _salePhotoFiles.removeAt(index);
      _salePhotosBase64.removeAt(index);
    });
    
    _showInfoSnackBar('Photo removed');
  }

  // Sale Processing
  void _processSale() async {
    if (!_canCheckout()) return;

    setState(() => _isLoading = true);

    try {
      // Process each item as a separate transaction
      for (final item in _cartItems) {
        final transaction = Transaction(
          barcode: item.product.barcode,
          transactionType: 'OUT',
          quantity: item.quantity,
          recipientName: _selectedCustomer!.name,
          recipientPhone: _selectedCustomer!.phone,
          recipientPhoto: _salePhotosBase64.isNotEmpty ? jsonEncode(_salePhotosBase64) : null,
          notes: 'Multi-item sale - Total: ₹${_calculateTotal().toStringAsFixed(2)}',
        );

        await _inventoryController.addTransaction(transaction);
      }

      // Show success message
      _showSuccessSnackBar('Sale completed successfully!');

      // Clear cart, photo, and return
      setState(() {
        _cartItems.clear();
        _selectedCustomer = null;
        _salePhotoFiles.clear();
        _salePhotosBase64.clear();
      });

      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackBar('Error processing sale: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper Methods
  void _showSuccessSnackBar(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
          backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Use'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Search and select a customer'),
            const SizedBox(height: 8),
            const Text('2. Scan products to add to cart'),
            const SizedBox(height: 8),
            const Text('3. Adjust quantities as needed'),
            const SizedBox(height: 8),
            const Text('4. Optionally add a sale photo'),
            const SizedBox(height: 8),
            const Text('5. Complete the sale'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

// Create Customer Dialog
class _CreateCustomerDialog extends StatefulWidget {
  final InventoryController inventoryController;
  final bool isTablet;
  
  const _CreateCustomerDialog({
    required this.inventoryController,
    required this.isTablet,
  });
  
  @override
  State<_CreateCustomerDialog> createState() => _CreateCustomerDialogState();
}

class _CreateCustomerDialogState extends State<_CreateCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(widget.isTablet ? 20 : 16),
      ),
      child: Container(
        padding: EdgeInsets.all(widget.isTablet ? 32 : 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: widget.isTablet ? 500 : double.infinity,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                      'Create New Customer',
                      style: TextStyle(
                fontSize: widget.isTablet ? 24 : 20,
                fontWeight: FontWeight.w600,
                      ),
                    ),
            SizedBox(height: widget.isTablet ? 24 : 20),
            
            Flexible(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                      TextFormField(
              controller: _nameController,
                        decoration: InputDecoration(
                labelText: 'Customer Name *',
                          labelStyle: TextStyle(fontSize: widget.isTablet ? 16 : 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(widget.isTablet ? 12 : 8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: widget.isTablet ? 16 : 12,
                            vertical: widget.isTablet ? 16 : 12,
                          ),
                        ),
                        style: TextStyle(fontSize: widget.isTablet ? 16 : 14),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter customer name';
                }
                return null;
              },
            ),
                      SizedBox(height: widget.isTablet ? 20 : 16),
                      
                      TextFormField(
              controller: _phoneController,
                        decoration: InputDecoration(
                labelText: 'Phone Number *',
                          labelStyle: TextStyle(fontSize: widget.isTablet ? 16 : 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(widget.isTablet ? 12 : 8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: widget.isTablet ? 16 : 12,
                            vertical: widget.isTablet ? 16 : 12,
                          ),
                        ),
                        style: TextStyle(fontSize: widget.isTablet ? 16 : 14),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                return null;
              },
            ),
                      SizedBox(height: widget.isTablet ? 20 : 16),
                      
                      TextFormField(
              controller: _notesController,
                        decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                          labelStyle: TextStyle(fontSize: widget.isTablet ? 16 : 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(widget.isTablet ? 12 : 8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: widget.isTablet ? 16 : 12,
                            vertical: widget.isTablet ? 16 : 12,
                          ),
                        ),
                        style: TextStyle(fontSize: widget.isTablet ? 16 : 14),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            SizedBox(height: widget.isTablet ? 32 : 24),
            Row(
                children: [
                  Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: widget.isTablet ? 16 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(widget.isTablet ? 12 : 8),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: widget.isTablet ? 16 : 14),
                    ),
                  ),
                ),
                SizedBox(width: widget.isTablet ? 20 : 16),
                  Expanded(
                      child: ElevatedButton(
                    onPressed: _isLoading ? null : _createCustomer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: widget.isTablet ? 16 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(widget.isTablet ? 12 : 8),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: widget.isTablet ? 20 : 16,
                            height: widget.isTablet ? 20 : 16,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Create',
                            style: TextStyle(fontSize: widget.isTablet ? 16 : 14),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



  void _createCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

              try {
                final customerData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                };
                
                await widget.inventoryController.addCustomer(customerData);
                
                final customer = Customer(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                );
                Navigator.pop(context, customer);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error creating customer: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// Product Scanner Page
class _ProductScannerPage extends StatefulWidget {
  final Function(Product) onProductScanned;
  final bool isTablet;

  const _ProductScannerPage({
    required this.onProductScanned,
    required this.isTablet,
  });

  @override
  State<_ProductScannerPage> createState() => _ProductScannerPageState();
}

class _ProductScannerPageState extends State<_ProductScannerPage> 
    with WidgetsBindingObserver {
  final InventoryController _inventoryController = InventoryController();
  bool _isLoading = false;
  bool _hasScanned = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: [BarcodeFormat.all],
      returnImage: false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController?.dispose();
    _scannerController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (_scannerController == null) return;
    
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_hasScanned && !_isLoading) {
          try {
            _scannerController?.start();
          } catch (e) {
            // Handle camera start error silently
          }
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        try {
          _scannerController?.stop();
        } catch (e) {
          // Handle camera stop error silently
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scan Product',
          style: TextStyle(fontSize: widget.isTablet ? 22 : 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_hasScanned)
            IconButton(
              icon: Icon(Icons.refresh, size: widget.isTablet ? 26 : 22),
              onPressed: _resetScanner,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: EdgeInsets.all(widget.isTablet ? 24 : 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.isTablet ? 20 : 16),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.isTablet ? 18 : 14),
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _onBarcodeDetect,
                    ),
                    
                    // Loading overlay
                    if (_isLoading)
                      Container(
                        color: Colors.black.withOpacity(0.7),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: widget.isTablet ? 40 : 32,
                                height: widget.isTablet ? 40 : 32,
                                child: const CircularProgressIndicator(color: Colors.white),
                              ),
                              SizedBox(height: widget.isTablet ? 20 : 16),
                              Text(
                                'Processing...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.isTablet ? 18 : 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Success overlay
                    if (_hasScanned && !_isLoading)
                      Container(
                        color: Colors.green.withOpacity(0.9),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: widget.isTablet ? 80 : 64,
                              ),
                              SizedBox(height: widget.isTablet ? 20 : 16),
                              Text(
                                'Scanned Successfully!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.isTablet ? 22 : 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_lastScannedCode != null) ...[
                                SizedBox(height: widget.isTablet ? 12 : 8),
                                Text(
                                    _lastScannedCode!,
                                  style: TextStyle(
                                      color: Colors.white,
                                    fontSize: widget.isTablet ? 16 : 14,
                                    ),
                                  ),
                              ],
                              SizedBox(height: widget.isTablet ? 32 : 24),
                              ElevatedButton.icon(
                                onPressed: _resetScanner,
                                icon: Icon(Icons.refresh, size: widget.isTablet ? 20 : 18),
                                label: Text(
                                  'Scan Again',
                                  style: TextStyle(fontSize: widget.isTablet ? 16 : 14),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.green,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: widget.isTablet ? 24 : 20,
                                    vertical: widget.isTablet ? 12 : 10,
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
          
          Container(
            padding: EdgeInsets.all(widget.isTablet ? 20 : 16),
            child: Text(
                  _hasScanned 
                    ? 'Product scanned! Tap "Scan Again" to scan another product.'
                    : 'Point camera at product barcode',
                  style: TextStyle(
                fontSize: widget.isTablet ? 18 : 16,
                    color: _hasScanned ? Colors.green.shade700 : Colors.grey.shade600,
                fontWeight: _hasScanned ? FontWeight.w500 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _onBarcodeDetect(BarcodeCapture barcodeCapture) {
    if (_hasScanned || _isLoading) return;
    
    if (barcodeCapture.barcodes.isNotEmpty) {
      final String? code = barcodeCapture.barcodes.first.rawValue;
      if (code != null) {
        final now = DateTime.now();
        if (_lastScannedCode == code && 
            _lastScanTime != null && 
            now.difference(_lastScanTime!).inSeconds < 2) {
          return;
        }
        
        _lastScannedCode = code;
        _lastScanTime = now;
        _handleScannedCode(code);
      }
    }
  }

  void _handleScannedCode(String code) async {
      setState(() {
        _isLoading = true;
      _hasScanned = true;
      });

    try {
    _scannerController?.stop();
    } catch (e) {
      // Camera may already be stopped, ignore error
    }

    try {
      final product = await _inventoryController.getProduct(code);
      
      if (mounted) {
        if (product != null) {
          await Future.delayed(const Duration(milliseconds: 500));
          widget.onProductScanned(product);
          Navigator.pop(context);
        } else {
          _showProductNotFoundDialog(code);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasScanned = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _resetScanner,
            ),
          ),
        );
        
        try {
        _scannerController?.start();
        } catch (e) {
          // Handle camera start error
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Camera error: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetScanner() {
      setState(() {
        _hasScanned = false;
        _isLoading = false;
        _lastScannedCode = null;
        _lastScanTime = null;
      });
    
    try {
    _scannerController?.start();
    } catch (e) {
      // Handle camera restart error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restart camera: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showProductNotFoundDialog(String barcode) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
        title: Row(
            children: [
            const Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: widget.isTablet ? 12 : 8),
            Text(
              'Product Not Found',
              style: TextStyle(fontSize: widget.isTablet ? 20 : 18),
            ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'This product is not in your inventory.',
              style: TextStyle(fontSize: widget.isTablet ? 16 : 14),
            ),
            SizedBox(height: widget.isTablet ? 12 : 8),
              Container(
              padding: EdgeInsets.all(widget.isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(widget.isTablet ? 6 : 4),
                ),
                child: Text(
                  'Barcode: $barcode',
                style: TextStyle(
                    fontFamily: 'monospace',
                  fontSize: widget.isTablet ? 14 : 12,
                  ),
                ),
              ),
            SizedBox(height: widget.isTablet ? 20 : 16),
            Text(
              'Would you like to add this product?',
              style: TextStyle(fontSize: widget.isTablet ? 16 : 14),
            ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
              Navigator.pop(context);
              _resetScanner();
              },
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: widget.isTablet ? 16 : 14),
            ),
            ),
            ElevatedButton(
              onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
                Navigator.pushNamed(context, '/addProduct', arguments: barcode);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            child: Text(
              'Add Product',
              style: TextStyle(fontSize: widget.isTablet ? 16 : 14),
            ),
            ),
          ],
        ),
      );
    }
  }