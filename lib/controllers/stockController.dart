import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StockList extends StatefulWidget {
  @override
  _StockListState createState() => _StockListState();
}

class _StockListState extends State<StockList> {
  final String apiUrl = "http://192.168.2.27:8080/Stocks/getStocks";
  List<dynamic> _stocks = [];
  List<dynamic> _filteredStocks = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    fetchStocks();
  }

  Future<List<dynamic>> fetchStocks() async {
    try {
      setState(() {
        _isLoading = true;
      });

      var result = await http.get(Uri.parse(apiUrl));
      if (result.statusCode == 200) {
        final data = json.decode(result.body)['Result'];
        setState(() {
          _stocks = data;
          _filteredStocks = data;
          _isLoading = false;
        });
        return data;
      } else {
        throw Exception('Failed to load stocks: ${result.statusCode}');
      }
    } catch (e) {
      if (mounted) {
      setState(() {
        _isLoading = false;
      });
      }
      throw e;
    }
  }

  void _filterStocks(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredStocks = _stocks;
      } else {
        _filteredStocks = _stocks.where((stock) {
          final stockCode = stock['StockCode']?.toString().toLowerCase() ?? '';
          final amount = stock['Amount']?.toString().toLowerCase() ?? '';
          final status = stock['Status']?.toString().toLowerCase() ?? '';
          final queryLower = query.toLowerCase();

          return stockCode.contains(queryLower) ||
              amount.contains(queryLower) ||
              status.contains(queryLower);
        }).toList();
      }
    });
  }

  String _stockCode(dynamic stock) {
    return stock['StockCode']?.toString() ?? 'N/A';
  }

  String _amount(dynamic stock) {
    return stock['Amount']?.toString() ?? '0';
  }

  String _status(dynamic stock) {
    return stock['Status']?.toString() ?? 'Unknown';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'available':
        return Colors.green;
      case 'low':
      case 'warning':
        return Colors.orange;
      case 'out':
      case 'unavailable':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stock Inventory'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              _showSearchDialog();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              fetchStocks();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading stock inventory...'),
                ],
              ),
            )
          : _filteredStocks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No stock items found'
                        : 'No items match your search',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Add some stock items to get started'
                        : 'Try adjusting your search terms',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _filterStocks(""),
                      child: Text('Clear Search'),
                    ),
                  ],
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: _filteredStocks.length,
              itemBuilder: (BuildContext context, int index) {
                final stock = _filteredStocks[index];
                final status = _status(stock);

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(status),
                      child: Icon(Icons.inventory, color: Colors.white),
                    ),
                    title: Text(
                      _stockCode(stock),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amount: ${_amount(stock)}'),
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          // TODO: Implement edit functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Edit functionality coming soon!'),
                            ),
                          );
                        } else if (value == 'details') {
                          // TODO: Implement details view
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Details view coming soon!'),
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
                              Icon(Icons.info, size: 16),
                              SizedBox(width: 8),
                              Text('View Details'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Search Stock'),
          content: TextField(
            decoration: InputDecoration(
              hintText: 'Search by stock code, amount, or status...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _filterStocks,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _filterStocks("");
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
}
