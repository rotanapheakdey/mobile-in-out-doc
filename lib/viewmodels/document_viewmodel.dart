import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../services/document_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DocumentViewModel extends ChangeNotifier {
  final DocumentService _documentService = DocumentService();

  List<DocumentModel> _urgentDocuments = [];
  List<DocumentModel> get urgentDocuments => _urgentDocuments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Future<void> fetchUrgentFeed() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _urgentDocuments = await _documentService.getUrgentFeed();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> uploadStaffReport(int documentId, String localPath) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    bool success = await _documentService.uploadReportFile(documentId, localPath);

    if (success) {
      await fetchUrgentFeed(); 
    } else {
      _errorMessage = "File upload failed. Ensure server storage disk is writable.";
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<List<Map<String, dynamic>>> fetchDepartments() async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'auth_token');

    final String url = 'http://192.168.1.35/api/departments';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Decode the JSON array into a Flutter List of Maps
        List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print(' [API ERROR]: Failed to fetch departments. Status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print(' [NETWORK ERROR]: $e');
      return [];
    }
  }

  Future<bool> uploadOriginalDocument(int documentId, String localPath) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    final DocumentService apiService = DocumentService();
    bool success = await apiService.uploadOriginalFile(documentId, localPath);

    if (success) {
      await fetchUrgentFeed(); 
    } else {
      _errorMessage = "Scanned file upload failed. Check network or disk allocation.";
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> registerNewDocument(String title, String controlNo, String comment, String filePath) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    bool success = await _documentService.createNewDocument(title, controlNo, comment, filePath);

    if (success) {
      await fetchUrgentFeed(); // Refresh the dashboard tray instantly
    } else {
      _errorMessage = "Failed to create document. Verify server requirements.";
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  Future<bool> executeAction(int documentId, String action, [Map<String, dynamic>? payload]) async {
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'auth_token');

    String endpoint = '';
    if (action == 'direct') {
      endpoint = '/api/documents/$documentId/direct'; 
    } else if (action == 'dg-sign') {
      endpoint = '/api/documents/$documentId/dg-sign';
    } else {
      print('❌ [WORKFLOW ERROR]: Unknown action requested: $action');
      return false;
    }

    final String url = 'http://192.168.1.35$endpoint'; 

    print('🚀 [API OUTBOUND]: Executing $action on Document $documentId...');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: payload != null ? json.encode(payload) : null, 
      );

      print('📡 [API RESPONSE]: Status ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🎉 [SUCCESS]: ${data['message']}');
        
        
        return true;
      } else {
        print('❌ [API REJECTED]: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ [NETWORK CRASH]: $e');
      return false;
    }
  }
}