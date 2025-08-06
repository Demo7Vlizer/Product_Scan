import 'package:eopystocknew/controllers/orderController.dart';
import 'package:eopystocknew/models/order.dart';
import 'package:eopystocknew/views/order_ops/order_new.dart';
import 'package:flutter/material.dart';

import 'order_detail_list.dart';

class OrderListPage extends StatefulWidget {
  @override
  _OrderListPageState createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  late OrderController _dbHelper;
  late Future<List<Order>> getOrders;
  int orderCount = 0;
  final String deleted = "Deleted";
  final String archived = "Archived";
  final String restore = "";
  String _searchQuery = "";
  List<Order> _filteredOrders = [];

  @override
  void initState() {
    super.initState();
    _dbHelper = OrderController();
    getOrderList();
  }

  void getOrderList() {
    getOrders = _dbHelper.getOrders();
    getOrders.then((value) {
      orderCount = value.length;
      _filteredOrders = value;
      refresh();
    });
  }

  void refresh() {
    setState(() {});
  }

  void _filterOrders(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        getOrders.then((orders) {
          _filteredOrders = orders;
        });
      } else {
        getOrders.then((orders) {
          _filteredOrders = orders.where((order) {
            return order.name?.toLowerCase().contains(query.toLowerCase()) ==
                    true ||
                order.note?.toLowerCase().contains(query.toLowerCase()) ==
                    true ||
                order.status?.toLowerCase().contains(query.toLowerCase()) ==
                    true;
          }).toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Orders (${_filteredOrders.length})"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              _showSearchDialog();
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: () {
              getOrderList();
            },
            child: Icon(Icons.refresh),
            backgroundColor: Colors.amber,
            heroTag: "Refresh",
          ),
          SizedBox(height: 20),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddOrderPage(order: Order()),
                ),
              ).then((value) => getOrderList());
            },
            child: Icon(Icons.add),
            heroTag: "Add",
          ),
        ],
      ),
      body: FutureBuilder<List<Order>>(
        future: getOrders,
        builder: (BuildContext context, AsyncSnapshot<List<Order>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading orders...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error loading orders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(onPressed: getOrderList, child: Text('Retry')),
                ],
              ),
            );
          }

          if (!snapshot.hasData || _filteredOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No orders found'
                        : 'No orders match your search',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Create your first order to get started'
                        : 'Try adjusting your search terms',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _filterOrders(""),
                      child: Text('Clear Search'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: _filteredOrders.length,
            itemBuilder: (BuildContext context, int index) {
              Order order = _filteredOrders[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(order.status),
                    child: Icon(
                      _getStatusIcon(order.status),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    order.name ?? "No Name",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.note != null && order.note!.isNotEmpty)
                        Text(order.note!),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                order.status,
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              order.status ?? "No Status",
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(order.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddOrderPage(order: order),
                          ),
                        ).then((value) => getOrderList());
                      } else if (value == 'delete') {
                        _showDeleteDialog(order);
                      } else if (value == 'details') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OrderDetailListPage(order: order),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.list, size: 16),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddOrderPage(order: order),
                      ),
                    ).then((value) => getOrderList());
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'done':
        return Colors.green;
      case 'pending':
      case 'processing':
        return Colors.orange;
      case 'cancelled':
      case 'deleted':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'done':
        return Icons.check_circle;
      case 'pending':
      case 'processing':
        return Icons.schedule;
      case 'cancelled':
      case 'deleted':
        return Icons.cancel;
      default:
        return Icons.shopping_cart;
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Search Orders'),
          content: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name, note, or status...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _filterOrders,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _filterOrders("");
                Navigator.of(context).pop();
              },
              child: Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(Order order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Order'),
          content: Text('Are you sure you want to delete "${order.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _dbHelper.changeStatusOrder(order, deleted);
                  Navigator.of(context).pop();
                  getOrderList();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Order deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting order: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
