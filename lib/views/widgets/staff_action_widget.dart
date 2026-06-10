import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/document_model.dart';
import '../../viewmodels/document_viewmodel.dart';

class StaffActionWidget extends StatelessWidget {
  final DocumentModel document;
  final DocumentViewModel docVM;

  const StaffActionWidget({
    super.key,
    required this.document,
    required this.docVM,
  });

  @override
  Widget build(BuildContext context) {
    if (document.status == 'dg_directed') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003F88),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: const Icon(Icons.upload_file),
        label: const Text('UPLOAD ACTION REPORT (PDF)'),
        onPressed: () async {
          FilePickerResult? result = await FilePicker.pickFiles(
            type: FileType.any,
          );

          if (result != null && result.files.single.path != null) {
            String filePath = result.files.single.path!;
            bool ok = await docVM.uploadStaffReport(document.id, filePath);
            if (ok && context.mounted) {
              Navigator.pop(context);
            }
          }
        },
      );
    }
    return const SizedBox.shrink();
  }
}
