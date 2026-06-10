import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerView extends StatelessWidget {
  final String pdfUrl;
  final String documentTitle;

  const PdfViewerView({
    super.key, 
    required this.pdfUrl, 
    required this.documentTitle
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(documentTitle),
        backgroundColor: const Color(0xFF003F88), 
        foregroundColor: Colors.white,
      ),
      body: SfPdfViewer.network(
        pdfUrl,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load report: ${details.description}'),
              backgroundColor: const Color(0xFFE01A22),
            ),
          );
        },
      ),
    );
  }
}