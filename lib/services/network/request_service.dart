import 'dart:convert';
import 'package:eopystocknew/util/nothing.dart';
import 'package:eopystocknew/util/request_type.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:meta/meta.dart';

class RequestClient {
  static String _baseUrl = "http://10.211.37.172:8080";
  static String get baseUrl => _baseUrl;
  static Future<void> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? _baseUrl;
  }
  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = url;
    await prefs.setString('server_url', url);
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
