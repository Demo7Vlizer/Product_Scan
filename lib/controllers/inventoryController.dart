import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:eopystocknew/models/product.dart';
import 'package:eopystocknew/models/transaction.dart';
import 'package:eopystocknew/services/network/request_service.dart';

class InventoryController {
  String get _baseUrl => RequestClient.baseUrl;

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
      var response = await http.get(
        Uri.parse('$_baseUrl/api/products/$barcode'),
      );
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['Result'] != null) {
          return Product.fromJson(data['Result']);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null; // Product not found
      } else {
        throw Exception('Failed to load product: ${response.statusCode}');
      }
    } catch (e) {
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
      var response = await http.put(
        Uri.parse('$_baseUrl/api/products/$barcode'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(product.toJson()),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data['Result'];
      } else {
        var data = json.decode(response.body);
        throw Exception(data['error'] ?? 'Failed to update product');
      }
    } catch (e) {
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
}
