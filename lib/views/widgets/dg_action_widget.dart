import 'package:flutter/material.dart';
import '../../models/document_model.dart';
import '../../viewmodels/document_viewmodel.dart';

class DgActionWidget extends StatefulWidget {
  final DocumentModel document;
  final DocumentViewModel docVM;

  const DgActionWidget({super.key, required this.document, required this.docVM});

  @override
  State<DgActionWidget> createState() => _DgActionWidgetState();
}

class _DgActionWidgetState extends State<DgActionWidget> {
  int? _selectedDepartmentId = 2;

  @override
  Widget build(BuildContext context) {
    // STATE A: INITIAL DIRECTIVE ASSIGNMENT
    if (widget.document.status == 'pending_dg_init') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            value: _selectedDepartmentId,
            decoration: const InputDecoration(
              labelText: 'Assign Target Department',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 2, child: Text('Finance & Accounting (FIN)')),
              DropdownMenuItem(value: 5, child: Text('Digital Archives (DDA)')),
            ],
            onChanged: (val) => setState(() => _selectedDepartmentId = val),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE01A22), // Accent Signal Red
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.assignment_turned_in),
            label: const Text('AUTHORIZE & DIRECT'),
            onPressed: () async {
              bool ok = await widget.docVM.executeAction(widget.document.id, 'direct', {
                'assigned_department_id': _selectedDepartmentId,
                'dg_note': 'Execute review immediately.',
              });
              if (ok && context.mounted) Navigator.pop(context);
            },
          ),
        ],
      );
    }

    // STATE B: EXECUTIVE SIGN-OFF
    if (widget.document.status == 'pending_dg_approval') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003F88), // Brand Blue
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: const Icon(Icons.verified_user),
        label: const Text('EXECUTIVE SIGN-OFF'),
        onPressed: () async {
          bool ok = await widget.docVM.executeAction(widget.document.id, 'dg-sign');
          if (ok && context.mounted) Navigator.pop(context);
        },
      );
    }

    return const SizedBox.shrink();
  }
}