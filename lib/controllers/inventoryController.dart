import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:eopystocknew/models/product.dart';
import 'package:eopystocknew/models/transaction.dart';
import 'package:eopystocknew/services/network/request_service.dart';

class InventoryController {
  String get _baseUrl => RequestClient.baseUrl;
  String get baseUrl => RequestClient.baseUrl;

  // Check server connectivity
  Future<bool> checkServerConnection() async {
    try {
      var response = await http.get(
        Uri.parse('$_baseUrl/api/server-status'),
      ).timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get all products
  Future<List<Product>> getProducts() async {
    try {
      var response = await http.get(Uri.parse('$_baseUrl/api/products'));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return (data['Result'] as List)
            .map((product) => Product.fromJson(product))
            .toList();
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get product by barcode
  Future<Product?> getProduct(String barcode) async {
    try {
      print('🔍 [InventoryController] Fetching product with barcode: $barcode');
      print('🌐 [InventoryController] Request URL: $_baseUrl/api/products/$barcode');
      
      var response = await http.get(
        Uri.parse('$_baseUrl/api/products/$barcode'),
      ).timeout(Duration(seconds: 10));
      
      print('📡 [InventoryController] Response status: ${response.statusCode}');
      print('📄 [InventoryController] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['Result'] != null) {
          print('✅ [InventoryController] Product found: ${data['Result']['name']}');
          return Product.fromJson(data['Result']);
        }
        print('❌ [InventoryController] Product not found (Result is null)');
        return null;
      } else if (response.statusCode == 404) {
        print('❌ [InventoryController] Product not found (404 status)');
        return null; // Product not found
      } else {
        print('🚨 [InventoryController] Server error: ${response.statusCode}');
        throw Exception('Failed to load product: ${response.statusCode}');
      }
    } on TimeoutException {
      print('⏱️ [InventoryController] Connection timeout');
      throw Exception('Connection timeout');
    } on SocketException {
      print('🔌 [InventoryController] Cannot connect to server');
      throw Exception('Cannot connect to server');
    } catch (e) {
      print('💥 [InventoryController] Network error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Add new product
  Future<String> addProduct(Product product) async {
    try {
      var response = await http.post(
        Uri.parse('$_baseUrl/api/products'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(product.toJson()),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data['Result'];
      } else {
        var data = json.decode(response.body);
        throw Exception(data['error'] ?? 'Failed to add product');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Add transaction (Product IN/OUT)
  Future<String> addTransaction(Transaction transaction) async {
    try {
      var response = await http.post(
        Uri.parse('$_baseUrl/api/transactions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(transaction.toJson()),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data['Result'];
      } else {
        var data = json.decode(response.body);
        throw Exception(data['error'] ?? 'Failed to add transaction');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get all transactions
  Future<List<Transaction>> getTransactions() async {
    try {
      var response = await http.get(Uri.parse('$_baseUrl/api/transactions'));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return (data['Result'] as List)
            .map((transaction) => Transaction.fromJson(transaction))
            .toList();
      } else {
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update server URL
  void updateServerUrl(String newUrl) {
    // In a real app, you'd save this to shared preferences
    print('Server URL updated to: $newUrl');
  }

  // Update existing product
  Future<String> updateProduct(String barcode, Product product) async {
    try {
      print('Updating product: $barcode');
      print('Product data: ${json.encode(product.toJson())}');
      
      var response = await http.put(
        Uri.parse('$_baseUrl/api/products/$barcode'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(product.toJson()),
      );

      print('Update response status: ${response.statusCode}');
      print('Update response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          var data = json.decode(response.body);
          return data['Result'] ?? 'Product updated successfully';
        } catch (e) {
          print('JSON decode error on success: $e');
          return 'Product updated successfully';
        }
      } else {
        // Handle non-200 responses more robustly
        try {
          var data = json.decode(response.body);
          throw Exception(data['error'] ?? 'Failed to update product: ${response.statusCode}');
        } catch (jsonError) {
          // If JSON parsing fails, it might be an HTML error page
          print('Failed to parse error response as JSON: $jsonError');
          if (response.body.contains('<!doctype html>') || response.body.contains('<html>')) {
            throw Exception('Server error: The server returned an HTML error page. Status: ${response.statusCode}');
          } else {
            throw Exception('Failed to update product: ${response.statusCode} - ${response.body}');
          }
        }
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow; // Re-throw our custom exceptions
      }
      throw Exception('Network error: $e');
    }
  }

  // Delete product
  Future<String> deleteProduct(String barcode) async {
    try {
      var response = await http.delete(
        Uri.parse('$_baseUrl/api/products/$barcode'),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data['Result'];
      } else {
        var data = json.decode(response.body);
        throw Exception(data['error'] ?? 'Failed to delete product');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Search products
  Future<List<Product>> searchProducts(String query) async {
    try {
      var response = await http.get(
        Uri.parse('$_baseUrl/api/products/search/$query'),
      );
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return (data['Result'] as List)
            .map((product) => Product.fromJson(product))
            .toList();
      } else {
        throw Exception('Failed to search products: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      var response = await http.get(Uri.parse('$_baseUrl/api/stats'));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Customer Management
  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      var response = await http.get(Uri.parse('$_baseUrl/api/customers'));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['Result'] ?? []);
      } else {
        throw Exception('Failed to load customers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    try {
      var response = await http.get(
        Uri.parse('$_baseUrl/api/customers/search/$query'),
      );
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['Result'] ?? []);
      } else {
        throw Exception('Failed to search customers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<String> addCustomer(Map<String, dynamic> customer) async {
    try {
      var response = await http.post(
        Uri.parse('$_baseUrl/api/customers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(customer),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data['Result'];
      } else {
        var data = json.decode(response.body);
        throw Exception(data['error'] ?? 'Failed to add customer');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> getSalesSummary() async {
    try {
      var response = await http.get(Uri.parse('$_baseUrl/api/sales/summary'));
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to load sales summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update a transaction (for editing sales)
  Future<void> updateTransaction(
    int transactionId, {
    required String recipientName,
    required String recipientPhone,
    required int quantity,
    String? recipientPhoto,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'quantity': quantity,
      };
      
      // Only include photo if provided
      if (recipientPhoto != null) {
        requestBody['recipient_photo'] = recipientPhoto;
      }
      
      var response = await http.put(
        Uri.parse('$_baseUrl/api/transactions/$transactionId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode != 200) {
        try {
          var data = json.decode(response.body);
          throw Exception(data['error'] ?? 'Failed to update transaction');
        } catch (jsonError) {
          throw Exception('Server returned error ${response.statusCode}: ${response.reasonPhrase}');
        }
      }
    } on http.ClientException {
      throw Exception('Connection failed: Unable to reach server. Please check if the server is running and your network connection.');
    } on SocketException {
      throw Exception('Network error: Please check your internet connection and server status.');
    } on TimeoutException {
      throw Exception('Request timeout: Server is taking too long to respond. Please try again.');
    } catch (e) {
      if (e.toString().contains('WinError 233') || e.toString().contains('No process is on')) {
        throw Exception('Server connection failed: The server appears to be offline. Please start the server and try again.');
      }
      throw Exception('Network error: $e');
    }
  }

  // Update product quantity (for inventory adjustment)
  Future<void> updateProductQuantity(String barcode, int newQuantity) async {
    try {
      var response = await http.put(
        Uri.parse('$_baseUrl/api/products/$barcode/quantity'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'quantity': newQuantity,
        }),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode != 200) {
        try {
          var data = json.decode(response.body);
          throw Exception(data['error'] ?? 'Failed to update product quantity');
        } catch (jsonError) {
          throw Exception('Server returned error ${response.statusCode}: ${response.reasonPhrase}');
        }
      }
    } on http.ClientException {
      throw Exception('Connection failed: Unable to reach server. Please check if the server is running and your network connection.');
    } on SocketException {
      throw Exception('Network error: Please check your internet connection and server status.');
    } on TimeoutException {
      throw Exception('Request timeout: Server is taking too long to respond. Please try again.');
    } catch (e) {
      if (e.toString().contains('WinError 233') || e.toString().contains('No process is on')) {
        throw Exception('Server connection failed: The server appears to be offline. Please start the server and try again.');
      }
      throw Exception('Network error: $e');
    }
  }

  // Update customer information by phone number
  Future<void> updateCustomerByPhone(String oldPhone, String newName, String newPhone) async {
    try {
      var response = await http.put(
        Uri.parse('$_baseUrl/api/customers/phone/$oldPhone'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': newName,
          'phone': newPhone,
        }),
      );

      if (response.statusCode != 200) {
        var data = json.decode(response.body);
        throw Exception(data['error'] ?? 'Failed to update customer');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Delete transaction
  Future<void> deleteTransaction(int transactionId) async {
    try {
      var response = await http.delete(
        Uri.parse('$_baseUrl/api/transactions/$transactionId'),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode != 200) {
        try {
          var data = json.decode(response.body);
          throw Exception(data['error'] ?? 'Failed to delete transaction');
        } catch (jsonError) {
          throw Exception('Server returned error ${response.statusCode}: ${response.reasonPhrase}');
        }
      }
    } on http.ClientException {
      throw Exception('Connection failed: Unable to reach server. Please check if the server is running and your network connection.');
    } on SocketException {
      throw Exception('Network error: Please check your internet connection and server status.');
    } on TimeoutException {
      throw Exception('Request timeout: Server is taking too long to respond. Please try again.');
    } catch (e) {
      if (e.toString().contains('WinError 233') || e.toString().contains('No process is on')) {
        throw Exception('Server connection failed: The server appears to be offline. Please start the server and try again.');
      }
      throw Exception('Network error: $e');
    }
  }

  // Update transaction with better error handling
  Future<void> updateTransactionSafe(
    int transactionId, {
    required String recipientName,
    required String recipientPhone,
    required int quantity,
    String? recipientPhoto,
  }) async {
    try {
      await updateTransaction(
        transactionId,
        recipientName: recipientName,
        recipientPhone: recipientPhone,
        quantity: quantity,
        recipientPhoto: recipientPhoto,
      );
    } catch (e) {
      // If the specific transaction ID doesn't exist, that's okay for consolidated sales
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        print('Transaction $transactionId not found - this is normal for consolidated sales');
        return; // Don't throw error, just skip this update
      }
      rethrow; // Re-throw other errors
    }
  }

  // Delete photo file from server
  Future<void> deletePhotoFile(String photoPath, {String? customerName, String? customerPhone}) async {
    print('🌐 [InventoryController] Deleting photo: $photoPath');
    print('👤 [InventoryController] Customer: $customerName ($customerPhone)');
    print('🔗 [InventoryController] Request URL: $_baseUrl/api/photos/delete');
    
    try {
      final requestBody = {
        'photo_path': photoPath,
        'customer_name': customerName,
        'customer_phone': customerPhone,
      };
      print('📤 [InventoryController] Request body: ${json.encode(requestBody)}');
      
      var response = await http.delete(
        Uri.parse('$_baseUrl/api/photos/delete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 10));

      print('📡 [InventoryController] Response status: ${response.statusCode}');
      print('📄 [InventoryController] Response body: ${response.body}');

      if (response.statusCode != 200) {
        try {
          var data = json.decode(response.body);
          print('❌ [InventoryController] Server error: ${data['error']}');
          throw Exception(data['error'] ?? 'Failed to delete photo');
        } catch (jsonError) {
          print('❌ [InventoryController] Parse error: $jsonError');
          throw Exception('Server returned error ${response.statusCode}: ${response.reasonPhrase}');
        }
      } else {
        print('✅ [InventoryController] Photo deletion successful');
        
        // Parse response to show database update info
        try {
          var data = json.decode(response.body);
          if (data['database_updated'] != null) {
            print('🔄 [InventoryController] Database updated: ${data['database_updated']} transactions');
          }
        } catch (e) {
          // Ignore parsing errors for response data
        }
      }
    } on TimeoutException {
      print('⏱️ [InventoryController] Delete request timeout');
      throw Exception('Request timeout: Server is taking too long to respond');
    } on SocketException {
      print('🔌 [InventoryController] Cannot connect to server for delete');
      throw Exception('Network error: Cannot connect to server');
    } catch (e) {
      print('💥 [InventoryController] Delete error: $e');
      throw Exception('Network error: $e');
    }
  }
}
