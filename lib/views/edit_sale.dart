import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../controllers/inventoryController.dart';
import '../models/transaction.dart';
import 'camera.dart';

class EditSalePage extends StatefulWidget {
  final Transaction sale;

  const EditSalePage({Key? key, required this.sale}) : super(key: key);

  @override
  State<EditSalePage> createState() => _EditSalePageState();
}

class _EditSalePageState extends State<EditSalePage> {
  final InventoryController _inventoryController = InventoryController();
  final TextEditingController _customerSearchController = TextEditingController();
  
  // Customer data
  String? _selectedCustomerName;
  String? _selectedCustomerPhone;
  String? _selectedCustomerAddress;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  // Sale items
  List<SaleItem> _saleItems = [];
  
  // Photo data - Support multiple photos
  List<String> _customerPhotosBase64 = [];
  List<File> _customerPhotoFiles = [];
  bool _hasExistingPhoto = false;
  bool _isCapturingPhoto = false;
  int _currentPhotoIndex = 0;
  
  // Loading state
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeSaleData();
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    super.dispose();
  }

  void _initializeSaleData() {
    // Initialize customer data
    _selectedCustomerName = widget.sale.recipientName;
    _selectedCustomerPhone = widget.sale.recipientPhone;
    _customerSearchController.text = _selectedCustomerName ?? '';
    
    // Check for existing photos
    if (widget.sale.recipientPhoto != null && widget.sale.recipientPhoto!.isNotEmpty) {
      _hasExistingPhoto = true;
      
      // Handle both single photo and JSON array of photos
      try {
        final dynamic parsed = jsonDecode(widget.sale.recipientPhoto!);
        if (parsed is List) {
          _customerPhotosBase64 = parsed.cast<String>();
        } else {
          _customerPhotosBase64 = [widget.sale.recipientPhoto!];
        }
      } catch (e) {
        // Not JSON, treat as single photo
        _customerPhotosBase64 = [widget.sale.recipientPhoto!];
      }
    }
    
    // Load all items from this sale (by matching customer and date)
    _loadSaleItems();
  }

  void _updateItemQuantity(SaleItem item, int newQuantity) {
    if (newQuantity < 1) return;
    
    setState(() {
      item.quantity = newQuantity;
    });
  }

  void _showDeleteItemDialog(SaleItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item'),
        content: Text('Are you sure you want to remove "${item.productName}" from this sale?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(item);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteItem(SaleItem item) {
    setState(() {
      _saleItems.removeWhere((saleItem) => saleItem.barcode == item.barcode);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.productName} removed from sale'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _scanAndAddProduct() async {
    try {
      // Navigate to camera page for barcode scanning with direct return mode
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraPage(
            title: "Scan Product",
            returnBarcodeDirectly: true,
          ),
        ),
      );
      
      if (result != null && result is String && result.isNotEmpty) {
        await _addProductByBarcode(result);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning barcode: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addProductByBarcode(String barcode) async {
    try {
      // Check if product already exists in sale
      bool productExists = _saleItems.any((item) => item.barcode == barcode);
      
      if (productExists) {
        // If product exists, increase quantity
        SaleItem existingItem = _saleItems.firstWhere((item) => item.barcode == barcode);
        _updateItemQuantity(existingItem, existingItem.quantity + 1);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${existingItem.productName} quantity increased to ${existingItem.quantity}'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Get product details from server
      final product = await _inventoryController.getProduct(barcode);
      
      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product not found: $barcode'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Add new product to sale
      setState(() {
        _saleItems.add(SaleItem(
          id: null, // New item, no transaction ID yet
          productName: product.name ?? 'Unknown Product',
          barcode: barcode,
          mrp: product.mrp ?? 0.0,
          quantity: 1,
          originalQuantity: 0, // New item, original quantity is 0
        ));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to sale'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding product: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Connect scan product button to scanning functionality
  void _scanProduct() {
    _scanAndAddProduct();
  }

  double _calculateTotal() {
    return _saleItems.fold(0.0, (sum, item) => sum + (item.quantity * item.mrp));
  }

  Future<void> _loadSaleItems() async {
    try {
      // Get all transactions to find all items from this sale
      final allTransactions = await _inventoryController.getTransactions();
      
      // Filter transactions for this specific sale
      // Match by recipient name, phone, and date (same day)
      final saleTransactions = allTransactions.where((transaction) {
        if (transaction.transactionType != 'OUT') return false;
        if (transaction.recipientName != widget.sale.recipientName) return false;
        if (transaction.recipientPhone != widget.sale.recipientPhone) return false;
        
        // For multi-item sales, match by date and notes
        // For single sales, also check if this is the exact transaction
        if (widget.sale.notes == 'Multi-Item Sale') {
          // Check if same date (ignore time differences)
          final transactionDate = DateTime.tryParse(transaction.transactionDate ?? '');
          final originalDate = DateTime.tryParse(widget.sale.transactionDate ?? '');
          
          if (transactionDate != null && originalDate != null) {
            // Match transactions within the same hour for multi-item sales
            return transactionDate.year == originalDate.year &&
                   transactionDate.month == originalDate.month &&
                   transactionDate.day == originalDate.day &&
                   (transactionDate.difference(originalDate).inMinutes.abs() <= 60);
          }
        } else {
          // For single item sales, try to match the exact transaction first
          if (transaction.id == widget.sale.id) {
            return true;
          }
          
          // Fallback: match by date if exact ID match fails
          final transactionDate = DateTime.tryParse(transaction.transactionDate ?? '');
          final originalDate = DateTime.tryParse(widget.sale.transactionDate ?? '');
          
          if (transactionDate != null && originalDate != null) {
            return transactionDate.year == originalDate.year &&
                   transactionDate.month == originalDate.month &&
                   transactionDate.day == originalDate.day;
          }
        }
        
        return false;
      }).toList();
      
      // Convert transactions to sale items
      List<SaleItem> items = [];
      for (var transaction in saleTransactions) {
        // Load product details to get correct MRP
        final product = await _inventoryController.getProduct(transaction.barcode ?? '');
        
        items.add(SaleItem(
          id: transaction.id, // Store transaction ID for updates
          productName: transaction.productName ?? 'Unknown Product',
          barcode: transaction.barcode ?? '',
          mrp: product?.mrp ?? 10.0,
          quantity: transaction.quantity ?? 1,
          originalQuantity: transaction.quantity ?? 1,
        ));
      }
      
      if (mounted) {
        setState(() {
          _saleItems = items;
        });
      }
    } catch (e) {
      print('Error loading sale items: $e');
      // Fallback to single item if loading fails
      if (mounted) {
        setState(() {
          _saleItems = [
            SaleItem(
              id: widget.sale.id,
              productName: widget.sale.productName ?? 'Unknown Product',
              barcode: widget.sale.barcode ?? '',
              mrp: 10.0,
              quantity: widget.sale.quantity ?? 1,
              originalQuantity: widget.sale.quantity ?? 1,
            ),
          ];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? 24.0 : 16.0;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Edit Sale',
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
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Text(
              '${_saleItems.length} items',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Selection Section
                    _buildCustomerSection(),
                    
                    SizedBox(height: 16),
                    
                    // Grand Total Section
                    _buildGrandTotalSection(),
                    
                    SizedBox(height: 24),
                    
                    // Sale Items Section
                    _buildSaleItemsSection(),
                    
                    SizedBox(height: 24),
                    
                    // Customer Photo Section
                    _buildCustomerPhotoSection(),
                    
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            
            // Bottom Action Buttons
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          
          SizedBox(height: 12),
          
          // Search Field - Minimal
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200, width: 0.5),
            ),
            child: TextField(
              controller: _customerSearchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: _searchCustomers,
            ),
          ),
          
          SizedBox(height: 16),
          
          // Selected Customer Card - Minimal
          if (_selectedCustomerName != null) ...[
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade100, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 16,
                  ),
                  
                  SizedBox(width: 8),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCustomerName!,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (_selectedCustomerPhone != null)
                          Text(
                            _selectedCustomerPhone!,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Edit and Delete buttons - Minimal
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _showEditCustomerDialog,
                        child: Container(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.edit, color: Colors.blue.shade600, size: 16),
                        ),
                      ),
                      SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCustomerName = null;
                            _selectedCustomerPhone = null;
                            _selectedCustomerAddress = null;
                            _customerSearchController.clear();
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close, color: Colors.red.shade600, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          // Search Results
          if (_isSearching && _searchResults.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final customer = _searchResults[index];
                  return ListTile(
                    dense: true,
                    title: Text(customer['name'] ?? ''),
                    subtitle: Text(customer['phone'] ?? ''),
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

  Widget _buildGrandTotalSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade100, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calculate_outlined,
            color: Colors.green.shade600,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            'Total: ₹${_calculateTotal().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Items',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_saleItems.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ..._saleItems.map((item) => Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _buildSaleItemCard(item),
        )).toList(),
      ],
    );
  }

  Widget _buildSaleItemCard(SaleItem item) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade100, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Simple status indicator
              Container(
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue.shade400,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              
              SizedBox(width: 10),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      item.barcode,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      '₹${item.mrp.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Quantity display - Minimal
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.quantity}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Quantity Controls and Delete Button - Minimal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Quantity Controls - Compact
              Row(
                children: [
                  // Decrease button
                  GestureDetector(
                    onTap: item.quantity > 1 ? () => _updateItemQuantity(item, item.quantity - 1) : null,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: item.quantity > 1 ? Colors.red.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.quantity > 1 ? Colors.red.shade100 : Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 14,
                        color: item.quantity > 1 ? Colors.red.shade600 : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 12),
                  
                  // Quantity display
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade100, width: 0.5),
                    ),
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 12),
                  
                  // Increase button
                  GestureDetector(
                    onTap: () => _updateItemQuantity(item, item.quantity + 1),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade100, width: 0.5),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 14,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Delete Item Button - Minimal
              GestureDetector(
                onTap: () => _showDeleteItemDialog(item),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade100, width: 0.5),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.red.shade600,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Item total - Minimal
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Total: ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                '₹${(item.quantity * item.mrp).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }





  Widget _buildCustomerPhotoSection() {
    return Container(
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
              Text(
                'Photos (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              if (_hasExistingPhoto) ...[
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade100, width: 0.5),
                  ),
                  child: Text(
                    '${_customerPhotosBase64.length}',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          SizedBox(height: 16),
          
          // Photo carousel if photos exist
          if (_customerPhotosBase64.isNotEmpty) ...[
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  // Current photo with swipe gesture
                  GestureDetector(
                    onHorizontalDragEnd: _customerPhotosBase64.length > 1 ? (DragEndDetails details) {
                      if (details.primaryVelocity != null) {
                        if (details.primaryVelocity! > 0 && _currentPhotoIndex > 0) {
                          // Swiped right - previous photo
                          _previousPhoto();
                        } else if (details.primaryVelocity! < 0 && _currentPhotoIndex < _customerPhotosBase64.length - 1) {
                          // Swiped left - next photo
                          _nextPhoto();
                        }
                      }
                    } : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildPhotoWidget(_customerPhotosBase64[_currentPhotoIndex]),
                    ),
                  ),
                  
                  // Photo navigation overlay - always show for multiple photos
                  if (_customerPhotosBase64.length > 1) ...[
                    // Previous button
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _currentPhotoIndex > 0 ? _previousPhoto : null,
                            icon: Icon(
                              Icons.arrow_back_ios, 
                              color: _currentPhotoIndex > 0 ? Colors.white : Colors.white54, 
                              size: 18
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    
                    // Next button
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _currentPhotoIndex < _customerPhotosBase64.length - 1 ? _nextPhoto : null,
                            icon: Icon(
                              Icons.arrow_forward_ios, 
                              color: _currentPhotoIndex < _customerPhotosBase64.length - 1 ? Colors.white : Colors.white54, 
                              size: 18
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    
                    // Photo counter
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          '${_currentPhotoIndex + 1} / ${_customerPhotosBase64.length}',
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 12,
                            fontWeight: FontWeight.w500
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // Delete button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => _deletePhoto(_currentPhotoIndex),
                        icon: Icon(Icons.delete, color: Colors.white, size: 16),
                        tooltip: 'Delete this photo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
          
          // Action buttons
          Row(
            children: [
              // Add Photo Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isCapturingPhoto ? null : _addPhoto,
                  icon: _isCapturingPhoto 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.add_a_photo),
                  label: Text(
                    _isCapturingPhoto 
                      ? 'Adding...' 
                      : 'Add Photo'
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isCapturingPhoto ? Colors.grey : Colors.blue,
                    side: BorderSide(color: _isCapturingPhoto ? Colors.grey : Colors.blue),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
              // Quick capture button
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isCapturingPhoto ? null : _capturePhoto,
                  icon: Icon(Icons.camera_alt, size: 16),
                  label: Text('Quick Capture'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
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
    );
  }

  Widget _buildPhotoWidget(String photoPath) {
    // Check if it's a base64 image or file path
    if (photoPath.startsWith('data:image')) {
      // Base64 image
      try {
        Uint8List bytes;
        
        if (photoPath.contains(',')) {
          // Data URL format: data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQ...
          final base64String = photoPath.split(',').last;
          bytes = base64Decode(base64String);
        } else {
          // Direct base64 string
          bytes = base64Decode(photoPath);
        }
        
        return Image.memory(
          bytes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 32, color: Colors.grey.shade600),
                    SizedBox(height: 8),
                    Text(
                      'Error loading photo',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } catch (e) {
        return Container(
          color: Colors.grey.shade100,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 32, color: Colors.red.shade400),
                SizedBox(height: 8),
                Text(
                  'Invalid photo data',
                  style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      // File path - assume it's on the server
      final imageUrl = '${_inventoryController.baseUrl}/uploads/$photoPath';
      
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Color(0xFF4A7C3C),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade100,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 32, color: Colors.grey.shade600),
                  SizedBox(height: 8),
                  Text(
                    'Unable to load photo',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildBottomActions() {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 600 ? 24.0 : 16.0;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey.shade50, Colors.white],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;
            
            if (isSmallScreen) {
              // Stack buttons vertically on very small screens
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSale,
                      icon: _isSaving 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.check),
                      label: Text(_isSaving ? 'Saving...' : 'Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _scanProduct,
                      icon: Icon(Icons.qr_code_scanner),
                      label: Text('Scan Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Side by side layout for larger screens
              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSale,
                      icon: _isSaving 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.check),
                      label: Text(_isSaving ? 'Saving...' : 'Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 12),
                  
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scanProduct,
                      icon: Icon(Icons.qr_code_scanner),
                      label: Text('Scan Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  void _searchCustomers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _inventoryController.searchCustomers(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      setState(() {
        _searchResults.clear();
      });
    }
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomerName = customer['name'];
      _selectedCustomerPhone = customer['phone'];
      _selectedCustomerAddress = customer['address']; // Add address support
      _customerSearchController.text = _selectedCustomerName ?? '';
      _isSearching = false;
      _searchResults.clear();
    });
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

  // Photo management methods
  void _addPhoto() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Photo'),
        content: Text('Choose photo source'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _capturePhoto();
            },
            child: Text('Camera'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickFromGallery();
            },
            child: Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _deletePhoto(int index) {
    if (index >= 0 && index < _customerPhotosBase64.length) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Photo'),
          content: Text('Are you sure you want to delete this photo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDeletePhoto(index);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _confirmDeletePhoto(int index) async {
    final photoToDelete = _customerPhotosBase64[index];
    print('🗑️ Attempting to delete photo: $photoToDelete');
    print('👤 Customer info: $_selectedCustomerName ($_selectedCustomerPhone)');
    
    // If it's a server file path, try to delete from server
    if (!photoToDelete.startsWith('data:image')) {
      try {
        print('📡 Sending delete request to server...');
        await _inventoryController.deletePhotoFile(
          photoToDelete,
          customerName: _selectedCustomerName,
          customerPhone: _selectedCustomerPhone,
        );
        print('✅ Successfully deleted photo from server: $photoToDelete');
      } catch (e) {
        print('❌ Failed to delete photo from server: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: Could not delete from server: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        // Continue with local deletion even if server deletion fails
      }
    } else {
      print('📱 Deleting base64 photo (local only)');
    }
    
    setState(() {
      _customerPhotosBase64.removeAt(index);
      if (index < _customerPhotoFiles.length) {
        _customerPhotoFiles.removeAt(index);
      }
      
      // Update current index
      if (_customerPhotosBase64.isEmpty) {
        _hasExistingPhoto = false;
        _currentPhotoIndex = 0;
      } else if (_currentPhotoIndex >= _customerPhotosBase64.length) {
        _currentPhotoIndex = _customerPhotosBase64.length - 1;
      }
    });
    
    print('🔄 Photo deleted from local array. Remaining photos: ${_customerPhotosBase64.length}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Photo deleted successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _nextPhoto() {
    if (_currentPhotoIndex < _customerPhotosBase64.length - 1) {
      setState(() {
        _currentPhotoIndex++;
      });
    }
  }

  void _previousPhoto() {
    if (_currentPhotoIndex > 0) {
      setState(() {
        _currentPhotoIndex--;
      });
    }
  }

  void _capturePhoto() async {
    setState(() {
      _isCapturingPhoto = true;
    });
    
    try {
      print('Starting photo capture...');
      final ImagePicker picker = ImagePicker();
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Opening camera...'),
              ],
            ),
          );
        },
      );
      
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,          // Reduced from 1200
        maxHeight: 800,         // Reduced from 1200
        imageQuality: 70,       // Reduced from 85
      );
      
      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (photo != null) {
        print('Photo captured: ${photo.path}');
        
        final File originalFile = File(photo.path);
        
        // Check if file exists
        if (!await originalFile.exists()) {
          throw Exception('Photo file not found after capture');
        }
        
        // Apply additional compression
        final File? compressedFile = await _compressImage(originalFile);
        
        if (compressedFile != null) {
          final bytes = await compressedFile.readAsBytes();
          print('Compressed image bytes length: ${bytes.length}');
          
          if (bytes.isEmpty) {
            throw Exception('Compressed photo file is empty');
          }
          
          final base64Image = base64Encode(bytes);
          print('Base64 image length: ${base64Image.length}');
          
          setState(() {
            _customerPhotoFiles.add(compressedFile);
            _customerPhotosBase64.add('data:image/jpeg;base64,$base64Image');
            _hasExistingPhoto = true; // Mark as having photos
            _currentPhotoIndex = _customerPhotosBase64.length - 1; // Show newest photo
          });
          
          // Clean up original file if different from compressed
          if (originalFile.path != compressedFile.path) {
            try {
              await originalFile.delete();
            } catch (e) {
              print('Could not delete original file: $e');
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Photo captured successfully! Preview shown below.',
                style: TextStyle(fontSize: 14),
              ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: Duration(seconds: 3),
            ),
          );
          
          print('Photo capture completed successfully');
        } else {
          throw Exception('Failed to compress image');
        }
      } else {
        print('Photo capture cancelled by user');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo capture cancelled'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error capturing photo: $e');
      
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
            'Error capturing photo: ${e.toString()}',
            style: TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isCapturingPhoto = false;
      });
    }
  }

  void _pickFromGallery() async {
    setState(() {
      _isCapturingPhoto = true;
    });
    
    try {
      print('Starting gallery selection...');
      final ImagePicker picker = ImagePicker();
      
      final XFile? photo = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,          // Reduced from 1200
        maxHeight: 800,         // Reduced from 1200
        imageQuality: 70,       // Reduced from 85
      );
      
      if (photo != null) {
        print('Photo selected from gallery: ${photo.path}');
        
        final File originalFile = File(photo.path);
        
        // Check if file exists
        if (!await originalFile.exists()) {
          throw Exception('Photo file not found after selection');
        }
        
        // Apply additional compression
        final File? compressedFile = await _compressImage(originalFile);
        
        if (compressedFile != null) {
          final bytes = await compressedFile.readAsBytes();
          print('Compressed image bytes length: ${bytes.length}');
          
          if (bytes.isEmpty) {
            throw Exception('Compressed photo file is empty');
          }
          
          final base64Image = base64Encode(bytes);
          print('Base64 image length: ${base64Image.length}');
          
          setState(() {
            _customerPhotoFiles.add(compressedFile);
            _customerPhotosBase64.add('data:image/jpeg;base64,$base64Image');
            _hasExistingPhoto = true; // Mark as having photos
            _currentPhotoIndex = _customerPhotosBase64.length - 1; // Show newest photo
          });
          
          // Clean up original file if different from compressed
          if (originalFile.path != compressedFile.path) {
            try {
              await originalFile.delete();
            } catch (e) {
              print('Could not delete original file: $e');
            }
          }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Photo selected successfully! Preview shown below.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: Duration(seconds: 3),
          ),
        );
        
        print('Photo selection completed successfully');
        } else {
          throw Exception('Failed to compress image');
        }
      } else {
        print('Photo selection cancelled by user');
      }
    } catch (e) {
      print('Error selecting photo: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error selecting photo: ${e.toString()}',
                  style: TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isCapturingPhoto = false;
      });
    }
  }

  // Removed unused methods for cleaner code



  void _showServerOfflineDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Server Offline',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unable to connect to the server. Please ensure:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 16),
              _buildServerCheckItem('1. Server is running'),
              _buildServerCheckItem('2. Network connection is active'),
              _buildServerCheckItem('3. Server IP address is correct'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Address:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _inventoryController.baseUrl,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                // Try to save again
                _saveSale();
              },
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServerCheckItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: Colors.grey.shade600),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  void _saveSale() async {
    if (_selectedCustomerName == null || _saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a customer and add at least one item',
            style: TextStyle(fontSize: 14),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Check server connectivity first
    bool isServerOnline = await _inventoryController.checkServerConnection();
    if (!isServerOnline) {
      setState(() {
        _isSaving = false;
      });
      
      _showServerOfflineDialog();
      return;
    }

    try {
      // Process each sale item
      for (var item in _saleItems) {
        print('Processing item: ${item.productName}, ID: ${item.id}, Quantity: ${item.quantity}, Original: ${item.originalQuantity}');
        
        if (item.id != null) {
          // Existing item - update transaction
          try {
            // Calculate inventory adjustment needed
            int quantityDifference = item.quantity - item.originalQuantity;
            print('Updating existing item ${item.productName} (ID: ${item.id}) with quantity difference: $quantityDifference');
            
            // Only update if there's actually a change
            // Prepare photos for sending
            String? photosToSend;
            if (_customerPhotosBase64.isNotEmpty) {
              photosToSend = _customerPhotosBase64.length == 1 
                  ? _customerPhotosBase64.first 
                  : jsonEncode(_customerPhotosBase64);
            }
            
            // Check if photos have changed (more robust comparison)
            bool photosChanged = false;
            try {
              if (photosToSend != widget.sale.recipientPhoto) {
                // Handle null cases
                if ((photosToSend == null && widget.sale.recipientPhoto != null) ||
                    (photosToSend != null && widget.sale.recipientPhoto == null)) {
                  photosChanged = true;
                } else if (photosToSend != null && widget.sale.recipientPhoto != null) {
                  // Both are not null, compare the actual content
                  List<String> currentPhotos = _customerPhotosBase64;
                  List<String> originalPhotos = [];
                  
                  // Parse original photos
                  try {
                    if (widget.sale.recipientPhoto!.startsWith('[')) {
                      originalPhotos = List<String>.from(jsonDecode(widget.sale.recipientPhoto!));
                    } else {
                      originalPhotos = [widget.sale.recipientPhoto!];
                    }
                  } catch (e) {
                    originalPhotos = [widget.sale.recipientPhoto!];
                  }
                  
                  // Compare arrays
                  if (currentPhotos.length != originalPhotos.length) {
                    photosChanged = true;
                  } else {
                    for (int i = 0; i < currentPhotos.length; i++) {
                      if (!originalPhotos.contains(currentPhotos[i])) {
                        photosChanged = true;
                        break;
                      }
                    }
                  }
                }
              }
            } catch (e) {
              print('Error comparing photos, assuming changed: $e');
              photosChanged = true;
            }
            
            print('🔍 Photo comparison: quantityDiff=$quantityDifference, photosChanged=$photosChanged');
            print('📸 Original photos: ${widget.sale.recipientPhoto}');
            print('📸 Current photos: $photosToSend');
            
            if (quantityDifference != 0 || photosChanged) {
              // Update the transaction in database (with safe handling for missing IDs)
              await _inventoryController.updateTransactionSafe(
                item.id!,
                recipientName: _selectedCustomerName!,
                recipientPhone: _selectedCustomerPhone ?? '',
                quantity: item.quantity,
                recipientPhoto: photosToSend,
              );
              print('Successfully updated transaction ${item.id}');
              
              // Adjust inventory if quantity changed
              if (quantityDifference != 0) {
                // Get current product to update inventory
                final product = await _inventoryController.getProduct(item.barcode);
                if (product != null) {
                  // If quantity increased, we need to reduce inventory
                  // If quantity decreased, we need to increase inventory
                  int newInventoryQuantity = (product.quantity ?? 0) - quantityDifference;
                  
                  await _inventoryController.updateProductQuantity(
                    item.barcode,
                    newInventoryQuantity,
                  );
                  print('Updated inventory for ${item.barcode}: ${newInventoryQuantity}');
                }
              }
            } else {
              print('No changes needed for item ${item.productName}');
            }
          } catch (e) {
            print('Error updating transaction ${item.id}: $e');
            // Continue with other items, but collect errors
            throw Exception('Failed to update ${item.productName}: ${e.toString()}');
          }
        } else {
          // New item - create new transaction
          try {
            print('Creating new transaction for ${item.productName}');
            final transaction = Transaction(
              barcode: item.barcode,
              transactionType: 'OUT',
              quantity: item.quantity,
              recipientName: _selectedCustomerName!,
              recipientPhone: _selectedCustomerPhone ?? '',
              recipientPhoto: _customerPhotosBase64.isNotEmpty 
                  ? (_customerPhotosBase64.length == 1 
                      ? _customerPhotosBase64.first 
                      : jsonEncode(_customerPhotosBase64))
                  : null,
              notes: 'Added during edit',
            );
            
            await _inventoryController.addTransaction(transaction);
            print('Successfully added new transaction for ${item.productName}');
          } catch (e) {
            print('Error adding new transaction for ${item.productName}: $e');
            throw Exception('Failed to add ${item.productName}: ${e.toString()}');
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sale updated successfully!',
              style: TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        
        // Clean up error message for better user experience
        if (errorMessage.contains('Exception: ')) {
          errorMessage = errorMessage.replaceFirst('Exception: ', '');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Failed to update sale',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  errorMessage,
                  style: TextStyle(fontSize: 13),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            duration: Duration(seconds: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _saveSale();
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showEditCustomerDialog() {
    final nameController = TextEditingController(text: _selectedCustomerName ?? '');
    final phoneController = TextEditingController(text: _selectedCustomerPhone ?? '');
    final addressController = TextEditingController(text: _selectedCustomerAddress ?? '');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Minimal Header
                  Row(
                    children: [
                      Icon(Icons.edit_outlined, color: Colors.grey.shade600, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Edit Customer',
                          style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Customer Name Field
                  Text(
                    'Name',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Enter customer name',
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
                    ),
                    style: TextStyle(fontSize: 14),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Phone Number Field
                  Text(
                    'Phone',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 6),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Enter phone number',
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
                    ),
                    style: TextStyle(fontSize: 14),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Address Field (Optional)
                  Text(
                    'Address (Optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 6),
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter address',
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
                    ),
                    style: TextStyle(fontSize: 14),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
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
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final newName = nameController.text.trim();
                            final newPhone = phoneController.text.trim();
                            final newAddress = addressController.text.trim();
                            
                            if (newName.isNotEmpty && newPhone.isNotEmpty) {
                              _updateCustomerInfo(newName, newPhone, newAddress);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please enter both name and phone number',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Update',
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
      },
    );
  }

  Future<void> _updateCustomerInfo(String newName, String newPhone, [String? newAddress]) async {
    try {
      // Store old phone for database update
      final oldPhone = _selectedCustomerPhone ?? '';
      
      // Update customer in database if they have an old phone number
      if (oldPhone.isNotEmpty) {
        await _inventoryController.updateCustomerByPhone(oldPhone, newName, newPhone);
      }
      
      // Update the UI
      if (mounted) {
        setState(() {
          _selectedCustomerName = newName;
          _selectedCustomerPhone = newPhone;
          _selectedCustomerAddress = newAddress;
          _customerSearchController.text = newName;
        });
        
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Customer information updated successfully',
                    style: TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Still update the UI even if database update fails
        setState(() {
          _selectedCustomerName = newName;
          _selectedCustomerPhone = newPhone;
          _selectedCustomerAddress = newAddress;
          _customerSearchController.text = newName;
        });
        
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Customer info updated locally. Will sync to database when sale is saved.',
                    style: TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class SaleItem {
  int? id; // Transaction ID for database updates
  String productName;
  String barcode;
  double mrp;
  int quantity;
  int originalQuantity; // Track original quantity for inventory adjustment

  SaleItem({
    this.id,
    required this.productName,
    required this.barcode,
    required this.mrp,
    required this.quantity,
    int? originalQuantity,
  }) : originalQuantity = originalQuantity ?? quantity;
}
