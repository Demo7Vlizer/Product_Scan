import 'dart:convert';
import 'dart:io';
import 'package:eopystocknew/util/nothing.dart';
import 'package:eopystocknew/util/request_type.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:meta/meta.dart';

class RequestClient {
  static String _baseUrl = "http://192.168.1.100:8080";
  static String get baseUrl => _baseUrl;
  
  static Future<void> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedUrl = prefs.getString('server_url');
    
    if (savedUrl != null) {
      _baseUrl = savedUrl;
    } else {
      // Set a default URL - auto-detection will be manual only
      _baseUrl = 'http://192.168.1.100:8080';
      print('💡 No server URL configured. Use Settings > Auto-Detect Server or enter manually.');
    }
  }
  
  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    if (!url.startsWith('http://')) {
      url = 'http://$url';
    }
    _baseUrl = url;
    await prefs.setString('server_url', url);
  }
  
  // Simple method to get server URL from server itself (if reachable)
  static Future<bool> findServerAutomatically() async {
    print('🔍 Looking for server...');
    
    // Try localhost first (for development)
    List<String> commonServerIPs = [
      'http://localhost:8080',
      'http://127.0.0.1:8080',
      'http://192.168.1.100:8080',
      'http://192.168.0.100:8080',
    ];
    
    for (String testUrl in commonServerIPs) {
      print('🔍 Testing: $testUrl...');
      if (await _testServerConnection(testUrl)) {
        print('✅ Found server at: $testUrl');
        _baseUrl = testUrl;
        await saveServerUrl(testUrl);
        return true;
      }
    }
    
    print('❌ Server not found at common addresses');
    print('💡 Please enter server IP manually in Settings');
    return false;
  }
  
  static Future<String?> _getLocalIP() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && 
              !addr.isLoopback && 
              addr.address.startsWith('192.168')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    return null;
  }
  
  static Future<bool> _testServerConnection(String url) async {
    try {
      final client = Client();
      final response = await client.get(
        Uri.parse('$url/api/server-status'),
      ).timeout(Duration(seconds: 3));
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  static Future<void> refreshServerIP() async {
    print('🔄 Refreshing server IP...');
    if (await findServerAutomatically()) {
      print('✅ Server IP updated successfully');
    } else {
      print('❌ Failed to update server IP');
    }
  }
  
  static Future<String?> getDeviceIP() async {
    return await _getLocalIP();
  }
  final Client _client;

  RequestClient(this._client);

  Future<Response> request({
    required RequestType requestType,
    required String path,
    dynamic parameter = Nothing,
  }) async {
    //->
    switch (requestType) {
      case RequestType.GET:
        return _client.get(Uri.parse("$_baseUrl/$path"));
      case RequestType.POST:
        return _client.post(
          Uri.parse("$_baseUrl/$path"),
          headers: {"Content-Type": "application/json"},
          body: json.encode(parameter),
        );
      case RequestType.DELETE:
        return _client.delete(Uri.parse("$_baseUrl/$path"));
    }
  }
}
