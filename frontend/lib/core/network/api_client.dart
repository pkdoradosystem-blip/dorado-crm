import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
    );

    return _decode(response);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
      },
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
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    return _decode(response);
  }

  Future<void> delete(String path) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'API ${response.statusCode}: ${response.body}',
      );
    }
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'API ${response.statusCode}: ${response.body}',
      );
    }

    if (response.body.isEmpty) {
      return null;
    }

    return jsonDecode(response.body);
  }
}