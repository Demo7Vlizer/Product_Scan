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

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"? This action cannot be undone.'),
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
      appBar: AppBar(
        title: Text('Product List'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: _filterProducts,
            ),
          ),

          // Product count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredProducts.length} products found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _filterProducts('');
                    },
                    child: Text('Clear'),
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
                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.blue.shade100,
                                child: product.imagePath != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(30),
                                        child: Image.network(
                                          '${RequestClient.baseUrl}/uploads/${product.imagePath}',
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Icon(
                                              Icons.inventory,
                                              color: Colors.blue,
                                              size: 30,
                                            );
                                          },
                                        ),
                                      )
                                    : Icon(
                                        Icons.inventory,
                                        color: Colors.blue,
                                        size: 30,
                                      ),
                              ),
                              title: Text(
                                product.name ?? 'Unknown Product',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Barcode: ${product.barcode}'),
                                  if (product.mrp != null)
                                    Text('MRP: ₹${product.mrp}'),
                                  Text('Quantity: ${product.quantity ?? 0}'),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditProductPage(product: product),
                                      ),
                                    ).then((_) => _loadProducts());
                                  } else if (value == 'delete') {
                                    _deleteProduct(product);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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