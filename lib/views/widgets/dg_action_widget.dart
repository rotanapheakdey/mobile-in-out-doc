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
  int? _selectedDepartmentId;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _departments = [];
  bool _isLoadingDepartments = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    final deps = await widget.docVM.fetchDepartments();
    if (mounted) {
      setState(() {
        _departments = deps;
        _isLoadingDepartments = false;
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String currentStatus = widget.document.status?.toUpperCase() ?? '';

    if (currentStatus == 'PENDING_DG_INIT') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _isLoadingDepartments
              ? const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator()))
              : DropdownButtonFormField<int>(
                  value: _selectedDepartmentId,
                  decoration: const InputDecoration(labelText: 'Assign Target Department', border: OutlineInputBorder()),
                  items: _departments.map((dept) => DropdownMenuItem<int>(value: dept['id'], child: Text('${dept['name']} (${dept['code']})'))).toList(),
                  onChanged: (val) => setState(() => _selectedDepartmentId = val),
                ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Executive Directives', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE01A22), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.assignment_turned_in),
            label: Text(_isSubmitting ? 'PROCESSING...' : 'AUTHORIZE & DIRECT'),
            onPressed: (_isSubmitting || _selectedDepartmentId == null) ? null : () async {
              setState(() => _isSubmitting = true);
              bool ok = await widget.docVM.executeAction(widget.document.id, 'direct', {
                'assigned_department_id': _selectedDepartmentId,
                'dg_note': _noteController.text.isNotEmpty ? _noteController.text : 'Please review and execute.',
              });
              if (mounted) {
                setState(() => _isSubmitting = false);
                if (ok) Navigator.pop(context, true);
              }
            },
          ),
        ],
      );
    }

    if (currentStatus == 'PENDING_DG_APPROVAL') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003F88), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
        icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.verified_user),
        label: Text(_isSubmitting ? 'SIGNING...' : 'EXECUTIVE SIGN-OFF'),
        onPressed: _isSubmitting ? null : () async {
          setState(() => _isSubmitting = true);
          bool ok = await widget.docVM.executeAction(widget.document.id, 'dg-sign');
          if (mounted) {
            setState(() => _isSubmitting = false);
            if (ok) Navigator.pop(context, true);
          }
        },
      );
    }

    return const SizedBox.shrink();
  }
}