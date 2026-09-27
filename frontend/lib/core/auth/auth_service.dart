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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await apiClient.post(
      '/api/v1/auth/change-password',
      {
        'old_password': currentPassword,
        'new_password': newPassword,
      },
    );

    if (response is! Map) {
      throw Exception('Invalid password change response');
    }

    final data = Map<String, dynamic>.from(response);

    // Backend returns the updated user.
    final userRaw = data['user'];

    if (userRaw is Map) {
      final user = Map<String, dynamic>.from(userRaw);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _userKey,
        jsonEncode(user),
      );
    } else {
      // If backend does not return user,
      // update the locally saved force-reset flag.
      final currentUser = await getSavedUser();

      if (currentUser != null) {
        currentUser['force_password_reset'] = false;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _userKey,
          jsonEncode(currentUser),
        );
      }
    }
  }

  Future<Map<String, dynamic>> verifyForgotPassword({
    required String login,
    required String dateOfBirth,
    required String petName,
  }) async {
    final response = await apiClient.post(
      '/api/v1/auth/forgot-password/verify',
      {
        'login': login.trim(),
        'date_of_birth': dateOfBirth.trim(),
        'pet_name': petName.trim(),
      },
    );

    if (response is! Map) {
      throw Exception('Invalid verification response');
    }

    final data = Map<String, dynamic>.from(response);

    if (data['verified'] != true) {
      throw Exception('Unable to verify employee details');
    }

    final resetToken = data['reset_token']?.toString();

    if (resetToken == null || resetToken.isEmpty) {
      throw Exception('Reset token not received');
    }

    return data;
  }

  Future<void> resetForgotPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await apiClient.post(
      '/api/v1/auth/forgot-password/reset',
      {
        'reset_token': resetToken,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );

    if (response is! Map) {
      throw Exception('Invalid password reset response');
    }

    final data = Map<String, dynamic>.from(response);

    if (data['success'] != true) {
      throw Exception(
        data['message']?.toString() ?? 'Password reset failed',
      );
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
