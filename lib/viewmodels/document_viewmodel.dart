import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../services/document_service.dart';

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

  Future<bool> executeAction(int documentId, String endpointSuffix, [Map<String, dynamic>? body]) async {
    _isLoading = true;
    notifyListeners();

    bool success = await _documentService.processWorkflowAction(documentId, endpointSuffix, body);

    if (success) {
      await fetchUrgentFeed();
    } else {
      _errorMessage = "Action failed. Check workflow constraints.";
      _isLoading = false;
      notifyListeners();
    }
    return success;
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
}