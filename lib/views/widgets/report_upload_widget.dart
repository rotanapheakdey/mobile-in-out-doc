import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/document_model.dart';
import '../../viewmodels/document_viewmodel.dart';

class ReportUploadWidget extends StatefulWidget {
  final DocumentModel document;
  final DocumentViewModel docVM;

  const ReportUploadWidget({super.key, required this.document, required this.docVM});

  @override
  State<ReportUploadWidget> createState() => _ReportUploadWidgetState();
}

class _ReportUploadWidgetState extends State<ReportUploadWidget> {
  File? _selectedFile;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      // Validate 10MB limit
      if (file.lengthSync() > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File exceeds 10MB limit'), backgroundColor: Colors.red),
        );
      } else {
        setState(() => _selectedFile = file);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.attach_file),
          label: Text(_selectedFile == null ? 'Select Execution Report' : 'File Selected: ${_selectedFile!.path.split('/').last}'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
          icon: _isUploading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) 
              : const Icon(Icons.cloud_upload),
          label: Text(_isUploading ? 'UPLOADING...' : 'SUBMIT EXECUTION REPORT'),
          onPressed: (_isUploading || _selectedFile == null) ? null : () async {
            setState(() => _isUploading = true);
            
            // Logic to call POST /api/documents/{id}/report
            bool ok = await widget.docVM.uploadReport(widget.document.id, _selectedFile!);
            
            if (mounted) {
              setState(() => _isUploading = false);
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted! Routed to VDG.')));
                Navigator.pop(context, true);
              }
            }
          },
        ),
      ],
    );
  }
}