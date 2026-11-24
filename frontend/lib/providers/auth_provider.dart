import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/api_exception.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _token != null && _user != null;
  String? get errorMessage => _errorMessage;

  /// Check stored token and auto-login on app launch
  Future<bool> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(AppConstants.tokenKey);
      final storedUser = prefs.getString(AppConstants.userKey);

      if (_token != null && _token!.isNotEmpty) {
        if (storedUser != null) {
          _user = UserModel.fromJson(jsonDecode(storedUser));
        }

        // Verify token with backend
        try {
          final res = await _api.get(ApiEndpoints.profile);
          if (res.statusCode == 200 && res.data['user'] != null) {
            _user = UserModel.fromJson(res.data['user']);
            await prefs.setString(AppConstants.userKey, jsonEncode(_user!.toJson()));
          }
        } catch (_) {
          // If offline or backend temporarily unreachable, keep stored session
        }
      }
    } catch (e) {
      _token = null;
      _user = null;
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }

    return isAuthenticated;
  }

  /// User Registration
  Future<bool> register({
    required String name,
    required String email,
    required String mobile,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        ApiEndpoints.register,
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'mobile': mobile.trim(),
          'password': password,
        },
      );

      if (res.statusCode == 201 && res.data['success'] == true) {
        _token = res.data['token'];
        _user = UserModel.fromJson(res.data['user']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, _token!);
        await prefs.setString(AppConstants.userKey, jsonEncode(_user!.toJson()));

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Registration failed: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// User Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        ApiEndpoints.login,
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      if (res.statusCode == 200 && res.data['success'] == true) {
        _token = res.data['token'];
        _user = UserModel.fromJson(res.data['user']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey, _token!);
        await prefs.setString(AppConstants.userKey, jsonEncode(_user!.toJson()));

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Login failed: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Update Profile
  Future<bool> updateProfile({required String name, required String mobile}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.put(
        ApiEndpoints.profile,
        data: {'name': name.trim(), 'mobile': mobile.trim()},
      );

      if (res.statusCode == 200 && res.data['user'] != null) {
        _user = UserModel.fromJson(res.data['user']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.userKey, jsonEncode(_user!.toJson()));

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to update profile: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Change Password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.post(
        ApiEndpoints.changePassword,
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

      _isLoading = false;
      notifyListeners();
      return res.statusCode == 200 && res.data['success'] == true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Password update failed: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Logout
  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
