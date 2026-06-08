import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiService {
  // For physical device via USB: run `adb reverse tcp:3000 tcp:3000` and use localhost
  // For Wi-Fi: use your PC's local IP (currently 172.20.10.4)
  // static const String baseUrl = 'http://172.20.10.4:3000/api';
  // static const String baseUrl = 'http://192.168.1.26:3000/api';
  static const String baseUrl = 'https://ai-house-production.up.railway.app/api';

  Future<Map<String, dynamic>> uploadPlan(XFile groundFile, XFile? firstFloorFile, XFile? secondFloorFile, String projectName) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    request.fields['name'] = projectName;
    
    // Attach ground floor
    final groundBytes = await groundFile.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'ground_plan',
      groundBytes,
      filename: groundFile.name,
    ));

    // Attach first floor if provided
    if (firstFloorFile != null) {
      final firstBytes = await firstFloorFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'first_plan',
        firstBytes,
        filename: firstFloorFile.name,
      ));
    }

    // Attach second floor if provided
    if (secondFloorFile != null) {
      final secondBytes = await secondFloorFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'second_plan',
        secondBytes,
        filename: secondFloorFile.name,
      ));
    }

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      try {
        return json.decode(responseData);
      } catch (e) {
        throw Exception("Server returned invalid data: $responseData");
      }
    } else {
      try {
        final error = json.decode(responseData)['error'] ?? 'Upload failed';
        throw Exception(error);
      } catch (e) {
        throw Exception("Server Error (${response.statusCode}): $responseData");
      }
    }
  }

  Future<List<dynamic>> getAllProjects() async {
    final response = await http.get(Uri.parse('$baseUrl/projects'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load project history');
    }
  }

  Future<Map<String, dynamic>> getProject(String projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/project/$projectId'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load project');
    }
  }

  Future<Map<String, dynamic>> analyzeVastu(String projectId, {String lang = 'English'}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/analyze-vastu/$projectId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'lang': lang}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      try {
        final errorData = json.decode(response.body);
        throw Exception(errorData['details'] ?? errorData['error'] ?? 'Vastu analysis failed');
      } catch (e) {
        throw Exception('Server Error: ${response.statusCode}');
      }
    }
  }

  Future<List<dynamic>> searchMaterial(String query) async {
    final response = await http.post(
      Uri.parse('$baseUrl/material/search'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'query': query}),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) return decoded;
      return [decoded]; // Fallback if API returned object
    } else {
      throw Exception('Failed to search material');
    }
  }

  Future<Map<String, dynamic>> createRazorpayOrder(double amount) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payment/create-order'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'amount': amount}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create payment order');
    }
  }

  Future<Map<String, dynamic>> verifyRazorpayPayment(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payment/verify-payment'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Payment verification failed');
    }
  }

  static Future<Map<String, dynamic>?> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        try {
          return json.decode(response.body);
        } catch (e) {
          return {'error': 'Server Error (${response.statusCode})'};
        }
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
