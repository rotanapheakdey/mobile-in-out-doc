import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentPdfViewer extends StatefulWidget {
  final int documentId;

  const DocumentPdfViewer({super.key, required this.documentId});

  @override
  State<DocumentPdfViewer> createState() => _DocumentPdfViewerState();
}

class _DocumentPdfViewerState extends State<DocumentPdfViewer> {
  late Future<Uint8List> _pdfFuture;

  @override
  void initState() {
    super.initState();
    _pdfFuture = _downloadCleanPdf();
  }

  Future<Uint8List> _downloadCleanPdf() async {
    final String url = 'http://192.168.1.35/api/documents/${widget.documentId}/download';
    const storage = FlutterSecureStorage();
    String? token = await storage.read(key: 'auth_token');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/pdf',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      if (response.bodyBytes.isEmpty) throw "Server returned an empty file.";
      return response.bodyBytes;
    } else {
      throw "Server Error: Status ${response.statusCode}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 550, 
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<Uint8List>(
        future: _pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003F88))),
                  SizedBox(height: 14),
                  Text('Loading document...', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text('Download Failed:\n${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return SfPdfViewer.memory(
              snapshot.data!,
              canShowScrollHead: true,
              pageLayoutMode: PdfPageLayoutMode.continuous,
            );
          }

          return const Center(child: Text('No file data available.'));
        },
      ),
    );
  }
}