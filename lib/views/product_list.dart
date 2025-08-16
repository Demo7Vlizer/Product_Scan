import 'package:flutter/material.dart';
import 'package:eopystocknew/controllers/inventoryController.dart';
import 'package:eopystocknew/models/product.dart';
import 'package:eopystocknew/views/edit_product.dart';
import 'package:eopystocknew/services/network/request_service.dart';

class ProductListPage extends StatefulWidget {
  @override
  _ProductListPageState createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final InventoryController _inventoryController = InventoryController();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _inventoryController.getProducts();
      if (mounted) {
        setState(() {
          _products = products;
          _filteredProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterProducts(String query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
        if (query.isEmpty) {
          _filteredProducts = _products;
        } else {
          _filteredProducts = _products.where((product) {
            final name = product.name?.toLowerCase() ?? '';
            final barcode = product.barcode?.toLowerCase() ?? '';
            final queryLower = query.toLowerCase();
            return name.contains(queryLower) || barcode.contains(queryLower);
          }).toList();
        }
      });
    }
  }

  void _showImageDialog(Product product) {
    if (product.imagePath == null) return;
    
    showDialog(
      context: context,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black87,
          child: Center(
            child: Container(
              margin: EdgeInsets.all(20),
              child: Image.network(
                '${RequestClient.baseUrl}/uploads/${product.imagePath}',
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return CircularProgressIndicator(color: Colors.white);
                },
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.white54,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
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
          'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
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
      try {
        await _inventoryController.deleteProduct(product.barcode!);
        await _loadProducts(); // Reload the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting product: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Product List',
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
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Minimal search bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: _filterProducts,
              ),
            ),
          ),

          // Minimal product count
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredProducts.length} products',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => _filterProducts(''),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Products list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No products found'
                                  : 'No products match your search',
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
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200, width: 1),
                            ),
                            child: Row(
                              children: [
                                // Simple status indicator
                                Container(
                                  width: 4,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: (product.quantity ?? 0) > 0 
                                        ? Colors.green.shade400 
                                        : Colors.red.shade400,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                
                                SizedBox(width: 12),
                                
                                // Product image
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300, width: 1),
                                  ),
                                  child: product.imagePath != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(7),
                                          child: Image.network(
                                            '${RequestClient.baseUrl}/uploads/${product.imagePath}',
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              final imageUrl = '${RequestClient.baseUrl}/uploads/${product.imagePath}';
                                              print('❌ Error loading product image:');
                                              print('   URL: $imageUrl');
                                              print('   Base URL: ${RequestClient.baseUrl}');
                                              print('   Image Path: ${product.imagePath}');
                                              print('   Error: $error');
                                              
                                              // Test the image URL in the background
                                              InventoryController().testImageUrl(product.imagePath!);
                                              
                                              return Icon(
                                                Icons.inventory_2_outlined,
                                                color: Colors.grey.shade500,
                                                size: 20,
                                              );
                                            },
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) {
                                                print('✅ Product image loaded successfully: ${RequestClient.baseUrl}/uploads/${product.imagePath}');
                                                return child;
                                              }
                                              return Container(
                                                width: 40,
                                                height: 40,
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.grey.shade400,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : Icon(
                                          Icons.inventory_2_outlined,
                                          color: Colors.grey.shade500,
                                          size: 20,
                                        ),
                                ),
                                
                                SizedBox(width: 12),
                                
                                // Product details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name ?? 'Unknown Product',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        product.barcode ?? '',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (product.mrp != null) ...[
                                            Text(
                                              '₹${product.mrp?.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: Colors.green.shade700,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                          ],
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (product.quantity ?? 0) > 0 
                                                  ? Colors.green.shade50 
                                                  : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: (product.quantity ?? 0) > 0 
                                                    ? Colors.green.shade200 
                                                    : Colors.red.shade200, 
                                                width: 0.5
                                              ),
                                            ),
                                            child: Text(
                                              'Qty: ${product.quantity ?? 0}',
                                              style: TextStyle(
                                                color: (product.quantity ?? 0) > 0 
                                                    ? Colors.green.shade700 
                                                    : Colors.red.shade700,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Action buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // View image button (only show if product has image)
                                    if (product.imagePath != null) ...[
                                      GestureDetector(
                                        onTap: () => _showImageDialog(product),
                                        child: Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.green.shade200, width: 0.5),
                                          ),
                                          child: Icon(
                                            Icons.visibility_outlined,
                                            size: 16,
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                    ],
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditProductPage(product: product),
                                          ),
                                        ).then((_) => _loadProducts());
                                      },
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
                                      onTap: () => _deleteProduct(product),
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
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 