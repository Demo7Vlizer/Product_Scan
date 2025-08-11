import 'dart:convert';
import 'package:flutter/material.dart';
import '../controllers/inventoryController.dart';
import '../models/transaction.dart';
import '../services/network/request_service.dart';
import 'edit_sale.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({Key? key}) : super(key: key);

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final InventoryController _inventoryController = InventoryController();
  final TextEditingController _searchController = TextEditingController();
  
  List<Transaction> _allSales = [];
  List<Transaction> _filteredSales = [];
  bool _isLoading = true;
  int _totalUnits = 0;

  @override
  void initState() {
    super.initState();
    _loadSalesHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSalesHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allTransactions = await _inventoryController.getTransactions();
      final salesTransactions = allTransactions
          .where((t) => t.transactionType == 'OUT')
          .toList();

      // Group transactions by product, customer, and date for multi-item sales
      final groupedSales = <String, List<Transaction>>{};
      
      for (final transaction in salesTransactions) {
        final key = '${transaction.recipientName}_${transaction.transactionDate?.split(' ')[0]}_${transaction.notes}';
        if (!groupedSales.containsKey(key)) {
          groupedSales[key] = [];
        }
        groupedSales[key]!.add(transaction);
      }

      // Create consolidated sales entries
      final consolidatedSales = <Transaction>[];
      
      for (final group in groupedSales.values) {
        if (group.length == 1) {
          // Single item sale
          final singleSale = group.first;
          print('Single sale photo: ${singleSale.recipientPhoto != null ? "HAS PHOTO" : "NO PHOTO"} for ${singleSale.recipientName}');
          consolidatedSales.add(singleSale);
        } else {
          // Multi-item sale - create a combined entry
          final firstItem = group.first;
          final totalQuantity = group.fold<int>(0, (sum, t) => sum + (t.quantity ?? 0));
          
          // Find the most sold product in the group
          final productCounts = <String, int>{};
          for (final t in group) {
            final productName = t.productName ?? 'Unknown';
            productCounts[productName] = (productCounts[productName] ?? 0) + (t.quantity ?? 0);
          }
          
          final topProduct = productCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;

          print('Multi-item sale photo: ${firstItem.recipientPhoto != null ? "HAS PHOTO" : "NO PHOTO"} for ${firstItem.recipientName}');

          final combinedSale = Transaction(
            id: firstItem.id,
            barcode: 'multi-item',
            transactionType: 'OUT',
            quantity: totalQuantity,
            recipientName: firstItem.recipientName,
            recipientPhone: firstItem.recipientPhone,
            recipientPhoto: firstItem.recipientPhoto, // ✅ Include photo!
            transactionDate: firstItem.transactionDate,
            notes: 'Multi-Item Sale',
            productName: topProduct,
          );
          
          consolidatedSales.add(combinedSale);
        }
      }

      // Calculate total units
      final totalUnits = consolidatedSales.fold<int>(0, (sum, sale) => sum + (sale.quantity ?? 0));

      setState(() {
        _allSales = consolidatedSales;
        _filteredSales = consolidatedSales;
        _totalUnits = totalUnits;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sales history: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterSales(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSales = _allSales;
      } else {
        _filteredSales = _allSales.where((sale) {
          final productName = (sale.productName ?? '').toLowerCase();
          final customerName = (sale.recipientName ?? '').toLowerCase();
          final phone = (sale.recipientPhone ?? '').toLowerCase();
          final searchQuery = query.toLowerCase();
          
          return productName.contains(searchQuery) ||
                 customerName.contains(searchQuery) ||
                 phone.contains(searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Sales History',
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
          IconButton(
            icon: Icon(Icons.refresh_outlined),
            onPressed: _loadSalesHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Minimal Header Section
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar - Minimal
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: _filterSales,
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Minimal Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_filteredSales.length} sales',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$_totalUnits units sold',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Sales List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.grey))
                : _filteredSales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No sales found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredSales.length,
                        itemBuilder: (context, index) {
                          final sale = _filteredSales[index];
                          return _buildSaleCard(sale);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Transaction sale) {
    final isMultiItem = sale.notes == 'Multi-Item Sale';
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
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
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: isMultiItem ? Colors.purple.shade400 : Colors.blue.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.productName ?? 'Unknown Product',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        if (isMultiItem)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.purple.shade200, width: 0.5),
                            ),
                            child: Text(
                              'Multi-Item',
                              style: TextStyle(
                                color: Colors.purple.shade600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        if (isMultiItem) SizedBox(width: 8),
                        Text(
                          '${sale.quantity ?? 0} units',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (sale.transactionDate != null)
                      Text(
                        _formatDate(sale.transactionDate!),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${sale.quantity ?? 0}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  sale.recipientName ?? 'Unknown Customer',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (sale.recipientPhoto != null && sale.recipientPhoto!.isNotEmpty)
                GestureDetector(
                  onTap: () => _viewCustomerPhoto(sale),
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200, width: 0.5),
                    ),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                  ),
                ),
              if (sale.recipientPhoto != null && sale.recipientPhoto!.isNotEmpty) SizedBox(width: 8),
              GestureDetector(
                onTap: () => _editSale(sale),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade200, width: 0.5),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: Colors.blue.shade600,
                  ),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteSale(sale),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200, width: 0.5),
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
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;
      
      if (difference == 0) {
        return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference == 1) {
        return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return dateString;
    }
  }

  void _editSale(Transaction sale) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSalePage(sale: sale),
      ),
    );
    
    // If the sale was updated, refresh the list
    if (result == true) {
      _loadSalesHistory();
    }
  }

  void _viewCustomerPhoto(Transaction sale) {
    if (sale.recipientPhoto == null || sale.recipientPhoto!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No customer photo available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4A7C3C), Color(0xFF6B9B4F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.photo, color: Colors.white, size: 24),
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
                              '${sale.recipientName ?? 'Unknown Customer'}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // Show fullscreen photo
                              _viewPhotoFullscreen(context, sale);
                            },
                            icon: Icon(Icons.fullscreen, color: Colors.white),
                            tooltip: 'View fullscreen',
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: Colors.white),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Photo Display
                Flexible(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Customer Info
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person, color: Colors.grey.shade600),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sale.recipientName ?? 'Unknown Customer',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (sale.recipientPhone != null && sale.recipientPhone!.isNotEmpty)
                                      Text(
                                        sale.recipientPhone!,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    Text(
                                      _formatDate(sale.transactionDate ?? ''),
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 20),
                        
                        // Photo
                        Flexible(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildPhotoWidget(sale.recipientPhoto!),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 20),
                        
                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.check),
                            label: Text('Close'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF4A7C3C),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
            print('Error loading base64 image: $error');
            return _buildPhotoErrorWidget();
          },
        );
      } catch (e) {
        print('Exception parsing base64 image: $e');
        return _buildPhotoErrorWidget();
      }
    } else {
      // File path - assume it's on the server
      try {
        // Make sure photoPath doesn't have any URL-unsafe characters
        final sanitizedPath = Uri.encodeComponent(photoPath);
        final imageUrl = '${_inventoryController.baseUrl}/uploads/$sanitizedPath';
        
        print('Loading image from URL: $imageUrl');
        
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
            print('Error loading image from network: $error');
            return _buildPhotoErrorWidget();
          },
        );
      } catch (e) {
        print('Exception loading network image: $e');
        return _buildPhotoErrorWidget();
      }
    }
  }

  Widget _buildPhotoErrorWidget() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
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
            'Unable to load image',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          Text(
            'The photo might be corrupted or unavailable',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _deleteSale(Transaction sale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Sale'),
        content: Text('Are you sure you want to delete this sale? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeleteSale(sale);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteSale(Transaction sale) async {
    if (!mounted) return; // Exit early if widget is disposed
    
    ScaffoldMessengerState? scaffoldMessenger;
    try {
      scaffoldMessenger = ScaffoldMessenger.of(context);
    } catch (e) {
      print('Cannot access ScaffoldMessenger, widget may be disposed');
      return;
    }
    
    try {
      // Show loading indicator
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Deleting sale...'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 30),
        ),
      );

      // Perform actual deletion with timeout
      if (sale.id != null) {
        await _inventoryController.deleteTransaction(sale.id!).timeout(
          Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Delete operation timed out. Please check your connection and try again.');
          },
        );
      } else {
        throw Exception('Invalid transaction ID');
      }
      
      // Only proceed if widget is still mounted
      if (!mounted) return;
      
      // Hide loading snackbar and show success message
      try {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Sale deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        print('Could not show success message, widget may be disposed');
      }
      
      // Refresh the list only if widget is still mounted
      if (mounted) {
        _loadSalesHistory();
      }
    } catch (e) {
      // Only show error message if widget is still mounted
      if (mounted) {
        try {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error deleting sale: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        } catch (uiError) {
          print('Could not show error message, widget may be disposed: $uiError');
        }
      }
    }
  }

  void _viewPhotoFullscreen(BuildContext context, Transaction sale) {
    if (sale.recipientPhoto == null || sale.recipientPhoto!.isEmpty) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            // Photo in center
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 3.0,
                child: sale.recipientPhoto!.startsWith('data:image')
                    ? Builder(
                        builder: (context) {
                          try {
                            final bytes = base64Decode(sale.recipientPhoto!.split(',')[1]);
                            return Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading base64 image in fullscreen: $error');
                                return _buildFullscreenErrorWidget();
                              },
                            );
                          } catch (e) {
                            print('Exception parsing base64 image in fullscreen: $e');
                            return _buildFullscreenErrorWidget();
                          }
                        },
                      )
                    : Image.network(
                        '${RequestClient.baseUrl}/uploads/${Uri.encodeComponent(sale.recipientPhoto!)}',
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading network image in fullscreen: $error');
                          return _buildFullscreenErrorWidget();
                        },
                      ),
              ),
            ),
            // Header with customer info and close button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 20,
                  right: 20,
                  bottom: 15,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.photo, color: Colors.white, size: 24),
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
                            '${sale.recipientName ?? 'Unknown Customer'}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white, size: 28),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
            ),
            // Instructions at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 15,
                  top: 15,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  'Pinch to zoom • Drag to pan • Tap outside to close',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFullscreenErrorWidget() {
    return Container(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image,
            size: 64,
            color: Colors.white.withOpacity(0.7),
          ),
          SizedBox(height: 16),
          Text(
            'Unable to load image',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'The photo might be corrupted or unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
