import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
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
  
  // Photo data
  String? _customerPhotoBase64;
  File? _customerPhotoFile;
  bool _hasExistingPhoto = false;
  bool _isCapturingPhoto = false;
  
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
    
    // Check for existing photo
    if (widget.sale.recipientPhoto != null && widget.sale.recipientPhoto!.isNotEmpty) {
      _hasExistingPhoto = true;
      _customerPhotoBase64 = widget.sale.recipientPhoto;
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.grey.shade600, size: 20),
              SizedBox(width: 8),
              Text(
                'Customer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Search Field
          TextField(
            controller: _customerSearchController,
            decoration: InputDecoration(
              hintText: 'Search customers by name or phone...',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
            onChanged: _searchCustomers,
          ),
          
          SizedBox(height: 16),
          
          // Selected Customer Card
          if (_selectedCustomerName != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                  ),
                  
                  SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCustomerName!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_selectedCustomerPhone != null)
                          Text(
                            _selectedCustomerPhone!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Edit and Delete buttons
                  IconButton(
                    onPressed: () {
                      _showEditCustomerDialog();
                    },
                    icon: Icon(Icons.edit, color: Colors.blue),
                  ),
                  
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedCustomerName = null;
                        _selectedCustomerPhone = null;
                        _selectedCustomerAddress = null;
                        _customerSearchController.clear();
                      });
                    },
                    icon: Icon(Icons.close, color: Colors.red),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calculate_outlined,
            color: Colors.green.shade700,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            'Total: ₹${_calculateTotal().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade800,
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
            Icon(Icons.shopping_cart_outlined, color: Colors.grey.shade600, size: 20),
            SizedBox(width: 8),
            Text(
              'Items',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Text(
                '${_saleItems.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
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
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Simple status indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      item.barcode,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '₹${item.mrp.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Quantity display
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${item.quantity}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Quantity Controls and Delete Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Quantity Controls
              Row(
                children: [
                  // Decrease button
                  GestureDetector(
                    onTap: item.quantity > 1 ? () => _updateItemQuantity(item, item.quantity - 1) : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.quantity > 1 ? Colors.red.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: item.quantity > 1 ? Colors.red.shade200 : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.remove,
                        size: 18,
                        color: item.quantity > 1 ? Colors.red.shade600 : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 16),
                  
                  // Quantity display
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200, width: 1),
                    ),
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  
                  SizedBox(width: 16),
                  
                  // Increase button
                  GestureDetector(
                    onTap: () => _updateItemQuantity(item, item.quantity + 1),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200, width: 1),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 18,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Delete Item Button
              GestureDetector(
                onTap: () => _showDeleteItemDialog(item),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200, width: 1),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red.shade600,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Item total
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Total: ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '₹${(item.quantity * item.mrp).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
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
              Icon(Icons.camera_alt_outlined, color: Colors.grey.shade600, size: 20),
              SizedBox(width: 8),
              Text(
                'Photo (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
              if (_hasExistingPhoto) ...[
                Spacer(),
                        Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera, color: Colors.green.shade700, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Photo Available',
                            style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ],
                        ),
                        
          SizedBox(height: 16),
                        
          // Photo preview if available
          if (_customerPhotoFile != null) ...[
                        Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Column(
                children: [
                  // Success indicator
                    Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Photo Captured',
                        style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                          fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                    ),
                  ),
                  SizedBox(height: 8),
                  // Photo preview
                    Container(
                    height: 120,
            width: double.infinity,
                      decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _customerPhotoFile!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade100,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 32, color: Colors.grey.shade600),
                                SizedBox(height: 8),
                                Text(
                                  'Preview Error',
                        style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
          ],
          
          // Action buttons
          Row(
            children: [
              // Capture/Retake Photo Button
                    Expanded(
            child: OutlinedButton.icon(
                  onPressed: _isCapturingPhoto ? null : _capturePhoto,
                  icon: _isCapturingPhoto 
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.camera_alt),
                  label: Text(
                    _isCapturingPhoto 
                      ? 'Capturing...' 
                      : _customerPhotoFile != null 
                        ? 'Retake Photo' 
                        : 'Capture Photo'
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
              
              // View existing photo button
              if (_hasExistingPhoto && _customerPhotoFile == null) ...[
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _viewExistingPhoto,
                    icon: Icon(Icons.photo, size: 16),
                    label: Text('View Photo'),
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
            ],
          ),
          
          // Alternative: Pick from Gallery (for testing)
          SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _isCapturingPhoto ? null : _pickFromGallery,
              icon: Icon(Icons.photo_library, size: 16),
              label: Text('Pick from Gallery (Alternative)'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
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
        imageQuality: 85,
        maxHeight: 1200,
        maxWidth: 1200,
      );
      
      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (photo != null) {
        print('Photo captured: ${photo.path}');
        
        // Convert to File and base64
        final File imageFile = File(photo.path);
        
        // Check if file exists
        if (!await imageFile.exists()) {
          throw Exception('Photo file not found after capture');
        }
        
        final List<int> imageBytes = await imageFile.readAsBytes();
        print('Image bytes length: ${imageBytes.length}');
        
        if (imageBytes.isEmpty) {
          throw Exception('Photo file is empty');
        }
        
        final String base64Image = base64Encode(imageBytes);
        print('Base64 image length: ${base64Image.length}');
        
        setState(() {
          _customerPhotoFile = imageFile;
          _customerPhotoBase64 = 'data:image/jpeg;base64,$base64Image';
          _hasExistingPhoto = true; // Mark as having a photo
        });
        
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
        imageQuality: 85,
        maxHeight: 1200,
        maxWidth: 1200,
      );
      
      if (photo != null) {
        print('Photo selected from gallery: ${photo.path}');
        
        // Convert to File and base64
        final File imageFile = File(photo.path);
        
        // Check if file exists
        if (!await imageFile.exists()) {
          throw Exception('Photo file not found after selection');
        }
        
        final List<int> imageBytes = await imageFile.readAsBytes();
        print('Image bytes length: ${imageBytes.length}');
        
        if (imageBytes.isEmpty) {
          throw Exception('Photo file is empty');
        }
        
        final String base64Image = base64Encode(imageBytes);
        print('Base64 image length: ${base64Image.length}');
        
        setState(() {
          _customerPhotoFile = imageFile;
          _customerPhotoBase64 = 'data:image/jpeg;base64,$base64Image';
          _hasExistingPhoto = true; // Mark as having a photo
        });
        
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

  void _viewExistingPhoto() {
    if (_customerPhotoBase64 == null || _customerPhotoBase64!.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF4A7C3C),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.photo_camera, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer Photo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _selectedCustomerName ?? 'Unknown Customer',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // Photo
                Flexible(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: _buildPhotoWidget(_customerPhotoBase64!),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoWidget(String photoPath) {
    // Check if it's a base64 image or file path
    if (photoPath.startsWith('data:image')) {
      // Base64 image
      try {
        final bytes = Uri.parse(photoPath).data!.contentAsBytes();
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildPhotoErrorWidget();
          },
        );
      } catch (e) {
        return _buildPhotoErrorWidget();
      }
    } else {
      // File path - assume it's on the server
      final imageUrl = '${_inventoryController.baseUrl}/uploads/$photoPath';
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
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
          return _buildPhotoErrorWidget();
        },
      );
    }
  }

  Widget _buildPhotoErrorWidget() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 48,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 12),
          Text(
            'Failed to load image',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }



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
            if (quantityDifference != 0 || _customerPhotoBase64 != widget.sale.recipientPhoto) {
              // Update the transaction in database (with safe handling for missing IDs)
              await _inventoryController.updateTransactionSafe(
                item.id!,
                recipientName: _selectedCustomerName!,
                recipientPhone: _selectedCustomerPhone ?? '',
                quantity: item.quantity,
                recipientPhoto: _customerPhotoBase64,
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
              recipientPhoto: _customerPhotoBase64,
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
