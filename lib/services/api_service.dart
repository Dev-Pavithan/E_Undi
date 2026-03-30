import 'dart:convert';
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
    
    print('API: Attempting login to $uri');
    
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'device_email': email,
        'device_id': deviceId,
        'device_passcode': passcode,
      }),
    );

    print('API: Login response status: ${response.statusCode}');
    print('API: Login response body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Login failed (${response.statusCode})');
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
      print('Error checking device status: $e');
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
      print('Error fetching company info: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> createTransaction({
    required String comCode,
    required String deviceId,
    required String transAmount,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/createTransaction'),
      headers: _headers,
      body: jsonEncode({
        'com_code': comCode,
        'device_id': deviceId,
        'trans_amount': double.tryParse(transAmount) ?? 0.0,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
          jsonDecode(response.body)['message'] ?? 'Transaction failed');
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
    final response = await http.post(
      Uri.parse('$baseUrl/add-donor-transaction'),
      headers: _headers,
      body: jsonEncode({
        'com_code': comCode,
        'device_id': deviceId,
        'donor_fname': firstName,
        'donor_lname': lastName,
        'donor_email': email,
        'donor_phone': phone,
        'trans_amount': double.tryParse(transAmount) ?? 0.0,
        'trans_email_status': transEmailStatus,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
          jsonDecode(response.body)['message'] ?? 'Donor transaction failed');
    }
  }
}