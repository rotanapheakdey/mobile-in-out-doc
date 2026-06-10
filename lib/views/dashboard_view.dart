import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/document_viewmodel.dart';
import '../models/document_model.dart';
import 'document_detail_view.dart'; 
import 'login_view.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'create_document_view.dart';


class DashboardView extends StatefulWidget {
  final String userRole;

  const DashboardView({super.key, required this.userRole});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState(); 
    
    // Fetch the live data immediately when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DocumentViewModel>(context, listen: false).fetchUrgentFeed();
    });
  }

  // Helper method to give your 7 phases clean, professional enterprise colors
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_dg_init': 
        return const Color(0xFFE01A22); 
      case 'pending_dispatch': 
        return Colors.orangeAccent;
      case 'dg_directed': 
        return const Color(0xFF003F88); 
      case 'pending_vdg_approval': 
        return Colors.purple;
      case 'pending_dg_approval': 
        return const Color(0xFF003F88); 
      case 'dg_signed': 
        return Colors.teal;
      case 'completed_archive': 
        return Colors.green;
      default: 
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final docVM = Provider.of<DocumentViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('INB Dashboard (${widget.userRole.toUpperCase()})'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => docVM.fetchUrgentFeed(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthViewModel>(context, listen: false).logout();
              
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginView()),
                  (route) => false, 
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: widget.userRole == 'file_dept'
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFE01A22), // INB Signal Red
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('NEW DOCUMENT', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateDocumentView()),
                );
              },
            )
          : null,
      body: docVM.isLoading
          ? const Center(child: CircularProgressIndicator())
          : docVM.errorMessage.isNotEmpty
          ? Center(
              child: Text(
                docVM.errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => docVM.fetchUrgentFeed(),
              child: docVM.urgentDocuments.isEmpty
                  ? const Center(child: Text('Your urgent tray is clean.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docVM.urgentDocuments.length,
                      itemBuilder: (context, index) {
                        final DocumentModel doc = docVM.urgentDocuments[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DocumentDetailView(
                                    document: doc,
                                    userRole: widget.userRole,
                                  ),
                                ),
                              );
                            },
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              doc.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Control No: ${doc.controlNo}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                if (doc.fileDeptComment != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Notes: "${doc.fileDeptComment}"',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Chip(
                              label: Text(
                                doc.status.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                              backgroundColor: _getStatusColor(doc.status),
                              side: BorderSide.none,
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}