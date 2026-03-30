import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://eundibackend.wstsc.org.au/api";

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Origin': 'https://eundibackend.wstsc.org.au',
  };

  static Future<Map<String, dynamic>> loginDevice({
    required String email,
    required String deviceId,
    required String passcode,
  }) async {
    final uri = Uri.parse('$baseUrl/login-device');
    
    if (kDebugMode) {
      print('API: Attempting login to $uri');
    }
    
    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'device_email': email,
          'device_id': deviceId,
          'device_passcode': passcode,
        }),
      ).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('API: Login response status: ${response.statusCode}');
        print('API: Login response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Login failed (${response.statusCode})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('API Error: $e');
      }
      throw Exception('Unable to connect to server. Please check your internet connection.');
    }
  }

  static Future<Map<String, dynamic>?> checkDeviceStatus(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/device-details/$deviceId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return {'status': 'not_found'};
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking device status: $e');
      }
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchCompanyInfo(String comCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/company/info/$comCode'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching company info: $e');
      }
      return null;
    }
  }

  static Future<Map<String, dynamic>> createTransaction({
    required String comCode,
    required String deviceId,
    required String transAmount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/createTransaction'),
        headers: _headers,
        body: jsonEncode({
          'com_code': comCode,
          'device_id': deviceId,
          'trans_amount': double.tryParse(transAmount) ?? 0.0,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Transaction failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating transaction: $e');
      }
      throw Exception('Failed to process transaction. Please try again.');
    }
  }

  static Future<Map<String, dynamic>> addDonorTransaction({
    required String comCode,
    required String deviceId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String transAmount,
    String transEmailStatus = "send",
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add-donor-transaction'),
        headers: _headers,
        body: jsonEncode({
          'com_code': comCode,
          'device_id': deviceId,
          'donor_fname': firstName.trim(),
          'donor_lname': lastName.trim(),
          'donor_email': email.trim(),
          'donor_phone': phone.trim(),
          'trans_amount': double.tryParse(transAmount) ?? 0.0,
          'trans_email_status': transEmailStatus,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Donor transaction failed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding donor transaction: $e');
      }
      throw Exception('Failed to process donation. Please try again.');
    }
  }

  // Helper method to validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // Helper method to validate phone number
  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^[\d\s\-\(\)]+$');
    return phoneRegex.hasMatch(phone) && phone.length >= 8;
  }

  // Helper method to validate amount
  static bool isValidAmount(String amount) {
    final amountValue = double.tryParse(amount);
    return amountValue != null && amountValue > 0;
  }
}