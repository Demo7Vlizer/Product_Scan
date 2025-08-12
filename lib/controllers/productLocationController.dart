import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/productLocation.dart';
import '../services/network/request_service.dart';

class ProductLocationController {
  String get _baseUrl => RequestClient.baseUrl;
  
  // Get all product locations with pagination
  Future<ProductLocationResponse> getProductLocations({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/product-locations?page=$page&per_page=$perPage'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ProductLocationResponse.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to get product locations');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Search product locations
  Future<List<ProductLocation>> searchProductLocations(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/product-locations/search/${Uri.encodeComponent(query)}'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<ProductLocation> locations = [];
        if (data['Result'] != null) {
          for (var item in data['Result']) {
            locations.add(ProductLocation.fromJson(item));
          }
        }
        return locations;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to search product locations');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Add product location
  Future<String> addProductLocation(
    String productName,
    String locationName,
    List<String>? imageDataList,
    String? notes,
  ) async {
    try {
      final Map<String, dynamic> requestData = {
        'product_name': productName,
        'location_name': locationName,
        'notes': notes ?? '',
      };

      if (imageDataList != null && imageDataList.isNotEmpty) {
        requestData['image_data_list'] = imageDataList;
        // Also keep backward compatibility
        requestData['image_data'] = imageDataList.first;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/product-locations'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Result'] ?? 'Product location added successfully';
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to add product location');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Update product location
  Future<String> updateProductLocation(
    int locationId,
    String productName,
    String locationName,
    String? imageData,
    String? notes,
  ) async {
    try {
      final Map<String, dynamic> requestData = {
        'product_name': productName,
        'location_name': locationName,
        'notes': notes ?? '',
      };

      if (imageData != null && imageData.isNotEmpty) {
        requestData['image_data'] = imageData;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/api/product-locations/$locationId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Result'] ?? 'Product location updated successfully';
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to update product location');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Delete product location
  Future<String> deleteProductLocation(int locationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/product-locations/$locationId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Result'] ?? 'Product location deleted successfully';
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to delete product location');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Update product location with photo deletion support
  Future<String> updateProductLocationWithPhotoDeletion(
    int locationId,
    String productName,
    String locationName,
    List<String>? newImageDataList,
    String? notes,
    List<String> imagesToDelete,
  ) async {
    try {
      final Map<String, dynamic> requestData = {
        'product_name': productName,
        'location_name': locationName,
        'notes': notes ?? '',
        'images_to_delete': imagesToDelete,
      };

      if (newImageDataList != null && newImageDataList.isNotEmpty) {
        requestData['image_data_list'] = newImageDataList;
        // Also keep backward compatibility
        requestData['image_data'] = newImageDataList.first;
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/api/product-locations/$locationId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['Result'] ?? 'Product location updated successfully';
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to update product location');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Get product name suggestions
  Future<List<String>> getProductSuggestions(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/product-locations/suggestions/${Uri.encodeComponent(query)}'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<String> suggestions = [];
        if (data['Result'] != null) {
          for (var item in data['Result']) {
            suggestions.add(item.toString());
          }
        }
        return suggestions;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to get suggestions');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }
}
