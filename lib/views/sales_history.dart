import 'dart:convert';
import 'dart:typed_data';
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

      // Group transactions by customer, and date for multi-item sales (excluding notes to avoid split issues)
      final groupedSales = <String, List<Transaction>>{};
      
      for (final transaction in salesTransactions) {
        // Group by customer name, phone, and date (up to minutes) - excluding notes field
        final datePart = transaction.transactionDate?.substring(0, 16) ?? ''; // YYYY-MM-DD HH:MM
        final key = '${transaction.recipientName}_${transaction.recipientPhone ?? ''}_$datePart';
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

          // Find user notes from any transaction in the group
          String? userNotes;
          for (final transaction in group) {
            if (transaction.notes?.contains('\nNotes: ') == true) {
              final notesStart = transaction.notes!.indexOf('\nNotes: ') + 8;
              userNotes = transaction.notes!.substring(notesStart);
              break; // Use the first user notes found
            }
          }
          
          // Build notes for multi-item sale
          final combinedNotes = userNotes != null 
              ? 'Multi-item sale\nNotes: $userNotes'
              : 'Multi-item sale';

          final combinedSale = Transaction(
            id: firstItem.id,
            barcode: 'multi-item',
            transactionType: 'OUT',
            quantity: totalQuantity,
            recipientName: firstItem.recipientName,
            recipientPhone: firstItem.recipientPhone,
            recipientPhoto: firstItem.recipientPhoto, // ✅ Include photo!
            transactionDate: firstItem.transactionDate,
            notes: combinedNotes,
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
    final isMultiItem = sale.notes?.contains('Multi-item sale') == true;
    final hasUserNotes = sale.notes?.contains('\nNotes: ') == true;
    
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
              if (sale.customerNotes != null && sale.customerNotes!.isNotEmpty)
                GestureDetector(
                  onTap: () => _viewCustomerNotes(sale),
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.shade200, width: 0.5),
                    ),
                    child: Icon(
                      Icons.sticky_note_2_outlined,
                      size: 16,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ),
              if (sale.customerNotes != null && sale.customerNotes!.isNotEmpty) SizedBox(width: 8),
              if (hasUserNotes)
                GestureDetector(
                  onTap: () => _showSaleNotesDialog(sale),
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade200, width: 0.5),
                    ),
                    child: Icon(
                      Icons.edit_note_outlined,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ),
              if (hasUserNotes) SizedBox(width: 8),
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

    // Parse photos to determine if single or multiple
    List<String> photos = [];
    try {
      final dynamic parsed = jsonDecode(sale.recipientPhoto!);
      if (parsed is List) {
        photos = parsed.cast<String>();
      } else {
        photos = [sale.recipientPhoto!];
      }
    } catch (e) {
      photos = [sale.recipientPhoto!];
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(24),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minimal header
                Container(
                  padding: EdgeInsets.fromLTRB(16, 16, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        '${sale.recipientName ?? 'Customer'}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${photos.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, size: 18),
                        color: Colors.grey.shade600,
                        padding: EdgeInsets.all(6),
                        constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
                
                // Photo display - clean and simple
                Flexible(
                  child: Container(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildSimplePhotoCarousel(photos),
                    ),
                  ),
                ),
                
                // Minimal action buttons
                Container(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditSalePage(sale: sale),
                              ),
                            );
                            
                            if (result == true) {
                              await _loadSalesHistory();
                              final updatedSale = _filteredSales.firstWhere(
                                (s) => s.recipientName == sale.recipientName && 
                                       s.recipientPhone == sale.recipientPhone,
                                orElse: () => sale,
                              );
                              if (updatedSale.recipientPhoto != null && updatedSale.recipientPhoto!.isNotEmpty) {
                                _viewCustomerPhoto(updatedSale);
                              }
                            }
                          },
                          icon: Icon(Icons.edit, size: 16),
                          label: Text('Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue.shade600,
                            padding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      
                      SizedBox(width: 8),
                      
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _viewPhotoFullscreen(context, sale);
                          },
                          icon: Icon(Icons.fullscreen, size: 16),
                          label: Text('Fullscreen'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            padding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSinglePhoto(String photoPath) {
    print('=== _buildSinglePhoto called ===');
    print('Photo path type: ${photoPath.startsWith('data:image') ? 'base64' : 'file path'}');
    print('Photo path preview: ${photoPath.length > 50 ? photoPath.substring(0, 50) + '...' : photoPath}');
    
    // Check if it's a base64 image or file path
    if (photoPath.startsWith('data:image')) {
      // Base64 image
      try {
        print('Attempting to parse base64 image...');
        Uint8List bytes;
        
        if (photoPath.contains(',')) {
          // Data URL format: data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQ...
          final base64String = photoPath.split(',').last;
          print('Extracted base64 string length: ${base64String.length}');
          bytes = base64Decode(base64String);
        } else {
          // Direct base64 string
          print('Direct base64 string length: ${photoPath.length}');
          bytes = base64Decode(photoPath);
        }
        
        print('Successfully decoded ${bytes.length} bytes');
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            print('Error displaying base64 image: $error');
            print('Bytes length: ${bytes.length}');
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
        // Don't encode the entire path, just build the URL correctly
        final imageUrl = '${_inventoryController.baseUrl}/uploads/$photoPath';
        
        print('Loading image from URL: $imageUrl');
        print('Base URL: ${_inventoryController.baseUrl}');
        print('Original path: $photoPath');
        
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
            print('Error stackTrace: $stackTrace');
            print('Failed URL: $imageUrl');
            return _buildPhotoErrorWidget();
          },
        );
      } catch (e) {
        print('Exception loading network image: $e');
        return _buildPhotoErrorWidget();
      }
    }
  }

  Widget _buildSimplePhotoCarousel(List<String> photos) {
    return StatefulBuilder(
      builder: (context, setState) {
        int currentIndex = 0;
        
        return Column(
          children: [
            // Minimal photo counter for multiple photos
            if (photos.length > 1)
              Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${currentIndex + 1} of ${photos.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            
            // Photo with PageView for smooth swiping
            Expanded(
              child: PageView.builder(
                controller: PageController(initialPage: currentIndex),
                itemCount: photos.length,
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildSinglePhoto(photos[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
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
        ],
      ),
    );
  }

  void _viewPhotoFullscreen(BuildContext context, Transaction sale) {
    if (sale.recipientPhoto == null || sale.recipientPhoto!.isEmpty) return;
    
    // Parse photos - could be single photo or JSON array
    List<String> photos = [];
    try {
      final dynamic parsed = jsonDecode(sale.recipientPhoto!);
      if (parsed is List) {
        photos = parsed.cast<String>();
        print('Fullscreen: Found ${photos.length} photos in array');
      } else {
        photos = [sale.recipientPhoto!];
        print('Fullscreen: Single photo (not array)');
      }
    } catch (e) {
      photos = [sale.recipientPhoto!];
      print('Fullscreen: JSON parsing failed, treating as single photo');
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: _buildFullscreenPhotoViewer(photos, sale),
      ),
    );
  }

  Widget _buildFullscreenPhotoViewer(List<String> photos, Transaction sale) {
    return StatefulBuilder(
      builder: (context, setState) {
        int currentIndex = 0;
        
        return Stack(
          children: [
            // Photo in center
            Center(
              child: PageView.builder(
                controller: PageController(initialPage: currentIndex),
                itemCount: photos.length,
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Center(
                      child: _buildFullscreenSinglePhoto(photos[index]),
                    ),
                  );
                },
              ),
            ),
            
            // Minimalistic photo counter only
            if (photos.length > 1)
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${currentIndex + 1} of ${photos.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

            // Minimalistic close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 15,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Colors.white, size: 24),
                  iconSize: 40,
                ),
              ),
            ),
            // Minimalistic swipe hint for multiple photos
            if (photos.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      'Swipe to navigate • Pinch to zoom',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFullscreenSinglePhoto(String photoPath) {
    print('Fullscreen single photo: ${photoPath.length > 50 ? photoPath.substring(0, 50) + '...' : photoPath}');
    
    if (photoPath.startsWith('data:image')) {
      // Base64 image
      try {
        final bytes = base64Decode(photoPath.split(',')[1]);
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
    } else {
      // File path - assume it's on the server
      final imageUrl = '${RequestClient.baseUrl}/uploads/$photoPath';
      print('Fullscreen loading image from URL: $imageUrl');
      
      return Image.network(
        imageUrl,
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
          print('Failed URL: $imageUrl');
          return _buildFullscreenErrorWidget();
        },
      );
    }
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

  void _deleteSale(Transaction sale) async {
    // Show confirmation dialog first
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Sale'),
        content: Text('Are you sure you want to delete this sale? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) {
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

  void _showSaleNotesDialog(Transaction sale) {
    // Extract user notes from transaction notes
    String? userNotes;
    if (sale.notes?.contains('\nNotes: ') == true) {
      final notesStart = sale.notes!.indexOf('\nNotes: ') + 8;
      userNotes = sale.notes!.substring(notesStart);
    }

    if (userNotes == null || userNotes.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: 500,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit_note,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sale Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            sale.recipientName ?? 'Unknown Customer',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close),
                      iconSize: 20,
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                Flexible(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        userNotes!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(fontSize: 14),
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

  void _viewCustomerNotes(Transaction sale) {
    if (sale.customerNotes == null || sale.customerNotes!.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: 500,
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
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            sale.recipientName ?? 'Unknown Customer',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close),
                      iconSize: 20,
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Notes content
                Flexible(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        sale.customerNotes!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Close button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(fontSize: 14),
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
}
