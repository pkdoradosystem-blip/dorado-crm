import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

class AuthService {
  final ApiClient apiClient;

  AuthService(this.apiClient);

  static const _userKey = 'logged_in_user';

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
    String deviceName = 'Dorado CRM App',
  }) async {
    final response = await apiClient.post(
      '/api/v1/auth/login',
      {
        'login': login.trim(),
        'password': password,
        'device_name': deviceName,
      },
    );

    if (response is! Map) {
      throw Exception('Invalid login response');
    }

    final data = Map<String, dynamic>.from(response);
    final token = data['access_token']?.toString();

    if (token == null || token.isEmpty) {
      throw Exception('Access token not received');
    }

    await apiClient.saveToken(token);

    final userRaw = data['user'];

    if (userRaw is Map) {
      final user = Map<String, dynamic>.from(userRaw);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    }

    return data;
  }

  Future<Map<String, dynamic>?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_userKey);

    if (value == null || value.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(value);

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return null;
  }

  Future<bool> hasSession() async {
    final token = await apiClient.getToken();

    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final response = await apiClient.get('/api/v1/auth/me');

      if (response is Map) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _userKey,
          jsonEncode(Map<String, dynamic>.from(response)),
        );
      }

      return true;
    } catch (_) {
      await clearLocalSession();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await apiClient.post('/api/v1/auth/logout', {});
    } catch (_) {
      // Local logout must still work if internet/server is unavailable.
    }

    await clearLocalSession();
  }

  Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await apiClient.clearToken();
    await prefs.remove(_userKey);
  }
}