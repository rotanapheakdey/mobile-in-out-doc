import 'package:flutter/material.dart';
import '../../models/document_model.dart';
import '../../viewmodels/document_viewmodel.dart';

class VdgActionWidget extends StatelessWidget {
  final DocumentModel document;
  final DocumentViewModel docVM;

  const VdgActionWidget({super.key, required this.document, required this.docVM});

  @override
  Widget build(BuildContext context) {
    if (document.status == 'pending_vdg_approval') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: const Icon(Icons.draw),
        label: const Text('COUNTERSIGN ACTION REPORT'),
        onPressed: () async {
          bool ok = await docVM.executeAction(document.id, 'vdg-sign');
          if (ok && context.mounted) Navigator.pop(context);
        },
      );
    }
    return const SizedBox.shrink();
  }
}