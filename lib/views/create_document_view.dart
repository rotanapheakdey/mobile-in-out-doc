import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../viewmodels/document_viewmodel.dart';

class CreateDocumentView extends StatefulWidget {
  const CreateDocumentView({super.key});

  @override
  State<CreateDocumentView> createState() => _CreateDocumentViewState();
}

class _CreateDocumentViewState extends State<CreateDocumentView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _controlNoController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String? _selectedFilePath;
  String? _selectedFileName;

  @override
  void dispose() {
    _titleController.dispose();
    _controlNoController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docVM = Provider.of<DocumentViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Incoming Document'),
        backgroundColor: const Color(0xFF003F88),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Document Title / Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controlNoController,
              decoration: const InputDecoration(
                labelText: 'Official Control Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Intake Notes / Instructions (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // FILE PICKER BOX
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Text(
                    _selectedFileName ?? 'No file selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: const Color(0xFF003F88),
                    ),
                    icon: const Icon(Icons.search),
                    label: const Text('BROWSE STORAGE FOR PDF'),
                    onPressed: () async {
                      // FilePickerResult? result = await FilePicker.pickFiles(
                      //   type: FileType.custom,
                      //   allowedExtensions: ['pdf'],
                      // );
                      FilePickerResult? result = await FilePicker.pickFiles(
                        type: FileType.any,
                      );
                      if (result != null) {
                        setState(() {
                          _selectedFilePath = result.files.single.path;
                          _selectedFileName = result.files.single.name;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (docVM.errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  docVM.errorMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            docVM.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003F88),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text('REGISTER & UPLOAD'),
                    onPressed: () async {
                      if (_titleController.text.isEmpty ||
                          _controlNoController.text.isEmpty ||
                          _selectedFilePath == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please fill all required fields and attach a PDF.',
                            ),
                          ),
                        );
                        return;
                      }

                      bool ok = await docVM.registerNewDocument(
                        _titleController.text,
                        _controlNoController.text,
                        _commentController.text,
                        _selectedFilePath!,
                      );

                      if (ok && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
