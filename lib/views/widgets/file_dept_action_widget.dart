import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/document_model.dart';
import '../../viewmodels/document_viewmodel.dart';

class FileDeptActionWidget extends StatelessWidget {
  final DocumentModel document;
  final DocumentViewModel docVM;

  const FileDeptActionWidget({
    super.key,
    required this.document,
    required this.docVM,
  });

  @override
  Widget build(BuildContext context) {
    // SITUATION A: PRE-DISPATCH ROUTING & INITIAL METADATA FILE ATTACHMENT
    if (document.status == 'pending_dispatch') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF003F88),
              side: const BorderSide(color: Color(0xFF003F88), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('UPLOAD SCANNED PRIMARY FILE (PDF)'),
            onPressed: () async {
              FilePickerResult? result = await FilePicker.pickFiles(
                type: FileType.any,
              );

              if (result != null && result.files.single.path != null) {
                String filePath = result.files.single.path!;
                bool uploaded = await docVM.uploadOriginalDocument(
                  document.id,
                  filePath,
                );

                if (uploaded && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Document file attached successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: const Icon(Icons.send_and_archive),
            label: const Text('DISPATCH TO DEPARTMENT'),
            onPressed: () async {
              bool ok = await docVM.executeAction(document.id, 'dispatch');
              if (ok && context.mounted) Navigator.pop(context);
            },
          ),
        ],
      );
    }

    // SITUATION B: COLD STORAGE IMMUTABLE LOCK
    if (document.status == 'dg_signed') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: const Icon(Icons.archive),
        label: const Text('VERIFY & LOCK TO ARCHIVE'),
        onPressed: () async {
          bool ok = await docVM.executeAction(document.id, 'archive');
          if (ok && context.mounted) Navigator.pop(context);
        },
      );
    }

    return const SizedBox.shrink();
  }
}
