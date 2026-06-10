import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/document_model.dart'; 

class DocumentService {
  static const String baseUrl = 'http://192.168.1.35/api';
  // static const String baseUrl = 'http://10.0.2.2/api';

  final storage = const FlutterSecureStorage();

  // HELPER: Get token for requests
  Future<String?> _getToken() async {
    return await storage.read(key: 'auth_token');
  }

  // 1. CORE TRAFFIC FEEDS
  Future<List<DocumentModel>> getUrgentFeed() async {
    try {
      String? token = await _getToken();

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

// 2. INITIALIZE NEW DOCUMENT (Phase 1: File Dept Intake)
  Future<bool> createNewDocument(String title, String controlNo, String comment, String filePath) async {
    try {
      String? token = await _getToken();

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/documents'));
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.fields['title'] = title;
      request.fields['control_no'] = controlNo;
      if (comment.isNotEmpty) {
        request.fields['file_dept_comment'] = comment;
      }

      // 💡 MATCHED: Uses 'filePath' because it matches the argument above
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 3. STANDARD WORKFLOW BUTTON ACTIONS (Direct, Sign, Archive)
  Future<bool> processWorkflowAction(int documentId, String endpointSuffix, [Map<String, dynamic>? body]) async {
    try {
      String? token = await _getToken();

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
      String? token = await _getToken();

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/documents/$documentId/report'));
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.files.add(await http.MultipartFile.fromPath('report_file', localFilePath));

      var streamedResponse = await request.send();
      return streamedResponse.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 5. FILE DEPT MULTIPART UPLOAD ENGINE (Phase 2: Upload Original Scanned Letter)
  Future<bool> uploadOriginalFile(int documentId, String localFilePath) async {
    try {
      String? token = await _getToken();

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/documents/$documentId/upload-scanned'));
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.files.add(await http.MultipartFile.fromPath('file', localFilePath));

      var streamedResponse = await request.send();
      return streamedResponse.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}