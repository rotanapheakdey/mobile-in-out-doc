import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/document_model.dart'; 

class ApiService {
  static const String baseUrl = 'http://10.0.2.2/api';
  final storage = const FlutterSecureStorage();

  // 0. INITIALIZE NEW DOCUMENT (Phase 1: File Dept Intake)
  Future<bool> createNewDocument(String title, String controlNo, String comment, String filePath) async {
    try {
      String? token = await storage.read(key: 'auth_token');

      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/documents') 
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      // Attach the form text fields
      request.fields['title'] = title;
      request.fields['control_no'] = controlNo;
      if (comment.isNotEmpty) {
        request.fields['file_dept_comment'] = comment;
      }

      // Attach the physical file
      request.files.add(
        await http.MultipartFile.fromPath('scanned_file', filePath)
      );

      var streamedResponse = await request.send();
      return streamedResponse.statusCode == 201 || streamedResponse.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 1. AUTHENTICATION HANDSHAKE
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Accept': 'application/json'},
        body: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Saved the correct backend payload key silently
        await storage.write(key: 'auth_token', value: data['access_token']);
        await storage.write(key: 'user_role', value: data['user']['role']);

        return {'success': true, 'role': data['user']['role']};
      } else {
        return {'success': false, 'message': 'Invalid credentials'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Check server.'};
    }
  }

  // 2. CORE TRAFFIC FEEDS
  Future<List<DocumentModel>> getUrgentFeed() async {
    try {
      String? token = await storage.read(key: 'auth_token');

      final response = await http.get(
        Uri.parse('$baseUrl/documents/urgent'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> docList = data['documents'];

        return docList.map((json) => DocumentModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load feed. Server returned ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching urgent feed: $e');
    }
  }

  // 3. STANDARD WORKFLOW BUTTON ACTIONS (Direct, Sign, Archive)
  Future<bool> processWorkflowAction(int documentId, String endpointSuffix, [Map<String, dynamic>? body]) async {
    try {
      String? token = await storage.read(key: 'auth_token');

      final response = await http.post(
        Uri.parse('$baseUrl/documents/$documentId/$endpointSuffix'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body != null ? jsonEncode(body) : null,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 4. MULTIPART FILE UPLOAD ENGINE (Phase 4: Staff Uploads Report)
  Future<bool> uploadReportFile(int documentId, String localFilePath) async {
    try {
      String? token = await storage.read(key: 'auth_token');

      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/documents/$documentId/report')
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.files.add(
        await http.MultipartFile.fromPath('report_file', localFilePath)
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 5. FILE DEPT MULTIPART UPLOAD ENGINE 
  Future<bool> uploadOriginalFile(int documentId, String localFilePath) async {
    try {
      String? token = await storage.read(key: 'auth_token');

      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/documents/$documentId/upload-scanned')
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.files.add(
        await http.MultipartFile.fromPath('scanned_file', localFilePath)
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}