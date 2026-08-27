import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  final String baseUrl;
  VoidCallback? onUnauthorized;
  
  ApiClient({this.baseUrl = 'http://10.0.2.2:3000/api/v1', this.onUnauthorized});

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } catch (e) {
      _handleNetworkError(e);
    }
  }
  
  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 10));
      return _processResponse(response);
    } catch (e) {
      _handleNetworkError(e);
    }
  }

  void _handleNetworkError(dynamic e) {
    if (e is ApiException) throw e;
    throw ApiException(0, 'NETWORK_ERROR', 'A network error occurred: $e');
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      String code = 'UNKNOWN';
      String message = 'An unknown error occurred';
      
      try {
        final errorPayload = jsonDecode(response.body);
        code = errorPayload['error']?['code'] ?? code;
        message = errorPayload['error']?['message'] ?? message;
      } catch (_) {}

      if (response.statusCode == 401) {
        onUnauthorized?.call();
      }

      throw ApiException(response.statusCode, code, message);
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  ApiException(this.statusCode, this.code, this.message);

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
