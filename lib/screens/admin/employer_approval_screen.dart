import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/admin_service.dart';
import '../../utils/safe_snackbar.dart';

class EmployerApprovalScreen extends StatefulWidget {
  const EmployerApprovalScreen({super.key});

  @override
  State<EmployerApprovalScreen> createState() => _EmployerApprovalScreenState();
}

class _EmployerApprovalScreenState extends State<EmployerApprovalScreen> {
  List<Map<String, dynamic>> _pendingApprovals = [];
  bool _isLoading = true;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    try {
      final approvals = await AdminService.getPendingApprovals();
      if (mounted) {
        setState(() {
          _pendingApprovals = approvals;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending approvals: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveEmployer(Map<String, dynamic> employer) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final success = await AdminService.approveEmployer(
        employerId: employer['id'],
        adminId: user.id,
        notes: 'Approved by admin',
      );

      if (success) {
        SafeSnackBar.showSuccess(
          context,
          message: '${employer['full_name']} approved successfully',
        );
        _loadPendingApprovals(); // Refresh the list
      } else {
        SafeSnackBar.showError(
          context,
          message: 'Failed to approve employer',
        );
      }
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Error: $e',
      );
    }
  }

  Future<void> _viewEmployerDocuments(Map<String, dynamic> employer) async {
    try {
      final employerId = employer['employer_id'] ?? employer['id'];
      final documents = await AdminService.getEmployerDocuments(employerId: employerId);
      
      if (documents.isEmpty) {
        SafeSnackBar.showInfo(
          context,
          message: 'No documents uploaded yet',
        );
        return;
      }

      // Show documents in a dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _buildDocumentsDialog(employer, documents),
        );
      }
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Error loading documents: $e',
      );
    }
  }

  Widget _buildDocumentsDialog(Map<String, dynamic> employer, List<Map<String, dynamic>> documents) {
    return AlertDialog(
      title: Text('Documents - ${employer['profiles']?['full_name'] ?? 'Unknown'}'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final doc = documents[index];
            final fileName = doc['name'] ?? 'Unknown file';
            final filePath = doc['path'] ?? '';
            
            return ListTile(
              leading: Text(
                _getFileIcon(fileName),
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(fileName),
              subtitle: Text(_formatFileSize(doc['size'] ?? 0)),
              trailing: IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () => _openDocument(filePath),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return '🖼️';
      default:
        return '📎';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _openDocument(String filePath) async {
    try {
      final signedUrl = await AdminService.getEmployerDocumentUrl(filePath: filePath);
      if (signedUrl != null) {
        final uri = Uri.parse(signedUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          SafeSnackBar.showError(
            context,
            message: 'Cannot open document',
          );
        }
      } else {
        SafeSnackBar.showError(
          context,
          message: 'Cannot generate document URL',
        );
      }
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Error opening document: $e',
      );
    }
  }

  Future<void> _rejectEmployer(Map<String, dynamic> employer) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final success = await AdminService.rejectEmployer(
        employerId: employer['id'],
        adminId: user.id,
        reason: 'Rejected by admin',
      );

      if (success) {
        SafeSnackBar.showWarning(
          context,
          message: '${employer['full_name']} rejected',
        );
        _loadPendingApprovals(); // Refresh the list
      } else {
        SafeSnackBar.showError(
          context,
          message: 'Failed to reject employer',
        );
      }
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Error: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: mediumSeaGreen),
      );
    }

    if (_pendingApprovals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: mediumSeaGreen.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Pending Approvals',
              style: TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All employers have been reviewed',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingApprovals.length,
      itemBuilder: (context, index) {
        final employer = _pendingApprovals[index];
        final company = employer['companies'] as List?;
        final companyData = company?.isNotEmpty == true ? company![0] : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: mediumSeaGreen.withValues(alpha: 0.1),
                      child: Text(
                        employer['full_name']?.substring(0, 1).toUpperCase() ?? 'E',
                        style: TextStyle(
                          color: mediumSeaGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employer['full_name'] ?? 'Unknown',
                            style: TextStyle(
                              color: darkTeal,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            employer['email'] ?? '',
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                if (companyData != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightMint,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Information',
                          style: TextStyle(
                            color: darkTeal,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Name: ${companyData['name'] ?? 'Not provided'}',
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                        if (companyData['about'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'About: ${companyData['about']}',
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _viewEmployerDocuments(employer),
                        icon: const Icon(Icons.description, size: 18),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mediumSeaGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        label: const Text('Documents'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _approveEmployer(employer),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _rejectEmployer(employer),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
