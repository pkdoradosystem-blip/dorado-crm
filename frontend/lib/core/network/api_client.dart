import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class ApiClient {
  static const String _tokenKey = 'access_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, String>> _headers({
    bool includeJson = true,
  }) async {
    final token = await getToken();

    return {
      if (includeJson) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(includeJson: false),
    );

    return _decode(response);
  }

  Future<http.Response> getBytes(String path) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(includeJson: false),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }

    return response;
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    return _decode(response);
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.put(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(includeJson: false),
    );

    return _decode(response);
  }

  Future<dynamic> multipartPost(
    String path, {
    required List<int> fileBytes,
    required String fileName,
    String fileField = 'file',
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
    );

    final token = await getToken();

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (fields != null) {
      request.fields.addAll(fields);
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    dynamic data;

    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = response.body;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'API ${response.statusCode}';

      if (data is Map && data['detail'] != null) {
        message = data['detail'].toString();
      } else if (response.body.isNotEmpty) {
        message = response.body;
      }

      throw Exception(message);
    }

    return data;
  }
}
