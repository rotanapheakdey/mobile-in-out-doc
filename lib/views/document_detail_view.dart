import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/document_model.dart';
import '../viewmodels/document_viewmodel.dart';
import 'widgets/dg_action_widget.dart';
import 'widgets/vdg_action_widget.dart';
import 'widgets/staff_action_widget.dart';
import 'widgets/file_dept_action_widget.dart';
import 'widgets/document_pdf_viewer.dart'; // Import separated component

class DocumentDetailView extends StatefulWidget {
  final DocumentModel document;
  final String userRole;

  const DocumentDetailView({super.key, required this.document, required this.userRole});

  @override
  State<DocumentDetailView> createState() => _DocumentDetailViewState();
}

class _DocumentDetailViewState extends State<DocumentDetailView> {
  @override
  void initState() {
    super.initState();

  }

  @override
  Widget build(BuildContext context) {
    
    final docVM = Provider.of<DocumentViewModel>(context);
    bool hasFile = widget.document.filePath != null && widget.document.filePath!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Document'),
        backgroundColor: const Color(0xFF003F88),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(24.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(widget.document.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Control Number: ${widget.document.controlNo}', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Current Status: ${widget.document.status.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF003F88))),
                  const Divider(height: 32),

                  if (hasFile) ...[
                    const Text('Attached Document File:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    
                    DocumentPdfViewer(documentId: widget.document.id),
                    
                    const SizedBox(height: 24),
                  ],

                  if (widget.document.fileDeptComment != null) ...[
                    const Text('Notes / Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('"${widget.document.fileDeptComment}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 30),
                  ],
                ]),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (docVM.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      _buildActionInterface(docVM), 
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionInterface(DocumentViewModel docVM) {
    switch (widget.userRole) {
      case 'dg':
        return DgActionWidget(document: widget.document, docVM: docVM);
      case 'vdg':
        return VdgActionWidget(document: widget.document, docVM: docVM);
      case 'staff':
        return StaffActionWidget(document: widget.document, docVM: docVM);
      case 'file_dept':
        return FileDeptActionWidget(document: widget.document, docVM: docVM);
      default:
        return const Center(
          child: Text('Awaiting out-of-band workflow progression.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
        );
    }
  }
}