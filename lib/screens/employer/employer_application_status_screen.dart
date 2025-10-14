import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/employer_registration_service.dart';
import 'package:intl/intl.dart';
import '../../utils/safe_snackbar.dart';
import '../login_screen.dart';
import 'home_screen.dart';

class EmployerApplicationStatusScreen extends StatefulWidget {
  const EmployerApplicationStatusScreen({super.key});

  @override
  State<EmployerApplicationStatusScreen> createState() => _EmployerApplicationStatusScreenState();
}

class _EmployerApplicationStatusScreenState extends State<EmployerApplicationStatusScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _verificationStatus;
  Map<String, dynamic>? _companyInfo;
  String? _error;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadApplicationStatus();
  }

  /// Enhanced document upload flow with better UX
  Future<void> _uploadDocsFlow() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        SafeSnackBar.showError(context, message: 'Please log in first');
        return;
      }

      // Determine which docs are missing from current status
      final missing = _computeMissingDocs();
      if (missing.isEmpty) {
        SafeSnackBar.showInfo(context, message: 'All documents are already uploaded');
        return;
      }

      // Show document selection dialog
      final selectedDocs = await _showDocumentSelectionDialog(missing);
      if (selectedDocs.isEmpty) return;

      // Upload selected documents with progress
      await _uploadDocumentsWithProgress(user.id, selectedDocs);
      
      // Reload to reflect latest URLs and update the checklist
      await _loadApplicationStatus();
    } catch (e) {
      debugPrint('Upload docs flow error: $e');
      SafeSnackBar.showError(context, message: 'Upload failed: $e');
    }
  }

  /// Show document selection dialog with file validation
  Future<Map<String, PlatformFile>> _showDocumentSelectionDialog(List<String> missingDocs) async {
    final Map<String, PlatformFile> selectedDocs = {};
    
    for (final docLabel in missingDocs) {
      final docKey = _getDocKeyFromLabel(docLabel);
      if (docKey == null) continue;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Validate file
        if (!_validateFile(file)) continue;
        
        // Show preview and confirmation
        final confirmed = await _showFileConfirmationDialog(docLabel, file);
        if (confirmed) {
          selectedDocs[docKey] = file;
        }
      }
    }
    
    return selectedDocs;
  }

  /// Validate uploaded file
  bool _validateFile(PlatformFile file) {
    // Check file size (max 10MB)
    const maxSize = 10 * 1024 * 1024; // 10MB
    if (file.size > maxSize) {
      SafeSnackBar.showError(context, message: 'File too large. Maximum size is 10MB');
      return false;
    }

    // Check file has data
    if (file.bytes == null || file.bytes!.isEmpty) {
      SafeSnackBar.showError(context, message: 'File appears to be empty');
      return false;
    }

    return true;
  }

  /// Show file confirmation dialog with preview
  Future<bool> _showFileConfirmationDialog(String docType, PlatformFile file) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.upload_file, color: mediumSeaGreen, size: 24),
            const SizedBox(width: 8),
            Text(
              'Confirm $docType Upload',
              style: TextStyle(
                color: darkTeal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightMint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(_getFileIcon(file.name), color: mediumSeaGreen, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          style: TextStyle(
                            color: darkTeal,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(file.size),
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Make sure the document is clear and readable',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: darkTeal.withValues(alpha: 0.7),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: mediumSeaGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Upload documents with progress indicator
  Future<void> _uploadDocumentsWithProgress(String userId, Map<String, PlatformFile> docs) async {
    if (docs.isEmpty) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
            ),
            const SizedBox(height: 16),
            Text(
              'Uploading ${docs.length} document(s)...',
              style: TextStyle(
                color: darkTeal,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we process your files',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      int successCount = 0;
      int totalCount = docs.length;

      for (final entry in docs.entries) {
        final docType = entry.key;
        final file = entry.value;

        try {
          final result = await EmployerRegistrationService.uploadEmployerDocument(
            userId: userId,
            documentType: docType,
            file: file,
          );

          if (result['success'] == true) {
            successCount++;
          }
        } catch (e) {
          debugPrint('Failed to upload $docType: $e');
        }
      }

      // Close progress dialog
      if (mounted) Navigator.pop(context);

      // Show results
      if (successCount == totalCount) {
        SafeSnackBar.showSuccess(
          context,
          message: 'All documents uploaded successfully!',
        );
      } else if (successCount > 0) {
        SafeSnackBar.showWarning(
          context,
          message: 'Uploaded $successCount/$totalCount documents. Some failed.',
        );
      } else {
        SafeSnackBar.showError(
          context,
          message: 'Failed to upload documents. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      SafeSnackBar.showError(context, message: 'Upload failed: $e');
    }
  }

  /// Map UI labels to document type keys
  String? _getDocKeyFromLabel(String label) {
    if (label.toLowerCase().contains('license')) return 'business_license';
    if (label.toLowerCase().contains('tax id')) return 'tax_id';
    if (label.toLowerCase().contains('registration')) return 'business_registration';
    return null;
  }

  /// Get file icon based on extension
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Build compact document row with individual upload button
  Widget _buildCompactDocumentRow(String docLabel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Document icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: mediumSeaGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getDocumentIcon(docLabel),
              color: mediumSeaGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          
          // Document name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  docLabel,
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Required for verification',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Individual upload button
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => _uploadSingleDocument(docLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Upload',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get document icon based on type
  IconData _getDocumentIcon(String docLabel) {
    if (docLabel.toLowerCase().contains('license')) return Icons.business_center;
    if (docLabel.toLowerCase().contains('tax')) return Icons.receipt_long;
    if (docLabel.toLowerCase().contains('registration')) return Icons.assignment;
    return Icons.description;
  }

  /// Upload single document
  Future<void> _uploadSingleDocument(String docLabel) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        SafeSnackBar.showError(context, message: 'Please log in first');
        return;
      }

      final docKey = _getDocKeyFromLabel(docLabel);
      if (docKey == null) return;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      
      // Validate file
      if (!_validateFile(file)) return;
      
      // Show confirmation dialog
      final confirmed = await _showFileConfirmationDialog(docLabel, file);
      if (!confirmed) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
              ),
              const SizedBox(height: 16),
              Text(
                'Uploading $docLabel...',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we process your file',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );

      // Upload document
      final uploadResult = await EmployerRegistrationService.uploadEmployerDocument(
        userId: user.id,
        documentType: docKey,
        file: file,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (uploadResult['success'] == true) {
        SafeSnackBar.showSuccess(
          context,
          message: '$docLabel uploaded successfully!',
        );
        // Reload status
        await _loadApplicationStatus();
      } else {
        SafeSnackBar.showError(
          context,
          message: 'Failed to upload $docLabel. Please try again.',
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      SafeSnackBar.showError(context, message: 'Upload failed: $e');
    }
  }

  // UI helpers
  Color _statusColor(String s) {
    switch (s) {
      case 'approved':
        return const Color(0xFF4CAF50); // green
      case 'rejected':
        return const Color(0xFFF44336); // red
      case 'pending':
      default:
        return const Color(0xFFFFA000); // amber
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.hourglass_empty;
    }
  }

  Widget _buildStatusPill(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _loadApplicationStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'No authenticated user found';
          _isLoading = false;
        });
        return;
      }

      // Load verification status
      final verificationResponse = await Supabase.instance.client
          .from('employer_verification')
          .select('*')
          .eq('employer_id', user.id)
          .maybeSingle();

      // Load company info
      final companyResponse = await Supabase.instance.client
          .from('companies')
          .select('name, about, created_at')
          .eq('owner_id', user.id)
          .maybeSingle();

      setState(() {
        _verificationStatus = verificationResponse;
        _companyInfo = companyResponse;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load application status: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Failed to sign out: $e',
      );
    }
  }

  Widget _buildStatusCard() {
    if (_verificationStatus == null) {
      return _buildNoStatusCard();
    }

    final status = _verificationStatus!['verification_status'] as String?;
    final submittedAt = _verificationStatus!['created_at'] as String?;
    final adminNotes = _verificationStatus!['admin_notes'] as String?;
    final rejectionReason = _verificationStatus!['rejection_reason'] as String?;

    switch (status) {
      case 'pending':
        return _buildPendingCard(submittedAt, adminNotes);
      case 'approved':
        return _buildApprovedCard();
      case 'rejected':
        return _buildRejectedCard(rejectionReason);
      default:
        return _buildNoStatusCard();
    }
  }

  Widget _buildNoStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            color: Colors.orange,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Application Not Found',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your employer application could not be found. Please contact support.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(String? submittedAt, String? adminNotes) {
    final submittedDate = submittedAt != null 
        ? DateTime.parse(submittedAt).toLocal()
        : null;

    final missingDocs = _computeMissingDocs();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            color: Colors.orange,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Application Under Review',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your employer application is currently being reviewed by our admin team.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          if (submittedDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightMint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: paleGreen.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: mediumSeaGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Submitted: ${_formatDate(submittedDate)}',
                    style: TextStyle(
                      color: darkTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (adminNotes != null && adminNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Admin Notes:',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    adminNotes,
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (missingDocs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF7FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with progress
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Documents needed',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      // Compact progress indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(_computeCompletionPercent() * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Compact document list with individual upload buttons
                  ...missingDocs.map((docLabel) => _buildCompactDocumentRow(docLabel)).toList(),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBDEFB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'What happens next?',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Our admin team will review your application within 1-3 business days\n• You will receive an email notification when your application is processed\n• Once approved, you can access your employer dashboard',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Application Approved!',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Congratulations! Your employer account has been approved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to employer dashboard
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmployerHomeScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Go to Dashboard',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedCard(String? rejectionReason) {
    List<Widget> _suggestedFixChips() {
      final List<Widget> chips = [];
      final reason = (rejectionReason ?? '').toLowerCase();
      void addChip(String label, VoidCallback onTap) {
        chips.add(ActionChip(label: Text(label), onPressed: onTap));
      }
      if (reason.contains('blurry') || reason.contains('unreadable')) {
        addChip('Re-upload clearer license', () async {
          await _uploadDocsFlow();
        });
      }
      if (reason.contains('missing') && (reason.contains('registration') || reason.contains('business registration'))) {
        addChip('Upload business registration', () async { await _uploadDocsFlow(); });
      }
      if (reason.contains('missing') && reason.contains('tax')) {
        addChip('Upload Tax ID', () async { await _uploadDocsFlow(); });
      }
      if (reason.contains('license')) {
        addChip('Upload business license', () async { await _uploadDocsFlow(); });
      }
      if (reason.contains('mismatch') || reason.contains('mismatched') || reason.contains('does not match')) {
        addChip('Edit company info', () => _openEditCompanySheet());
      }
      if (reason.contains('address') || reason.contains('city') || reason.contains('province') || reason.contains('postal')) {
        addChip('Edit business address', () => _openEditCompanySheet(initialSection: 'address'));
      }
      if (chips.isEmpty) {
        addChip('Edit company info', () => _openEditCompanySheet());
        addChip('Upload documents', () async { await _uploadDocsFlow(); });
      }
      return chips;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.cancel,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Application Rejected',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unfortunately, your employer application has been rejected.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Reason for rejection:',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rejectionReason,
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedFixChips(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCC80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.support_agent, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Need help?',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'If you believe this was an error or would like to reapply, please contact our support team.',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Compact document upload section for rejected applications
          if (_computeMissingDocs().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightMint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.upload_file, color: mediumSeaGreen, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Upload missing documents',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._computeMissingDocs().map((docLabel) => _buildCompactDocumentRow(docLabel)).toList(),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Resubmit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) return;
                String? note;
                // Quick note dialog
                await showDialog<void>(
                  context: context,
                  builder: (ctx) {
                    final controller = TextEditingController();
                    return AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Row(
                        children: [
                          Icon(Icons.message, color: mediumSeaGreen, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Message to admin (optional)',
                            style: TextStyle(
                              color: darkTeal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: controller,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Describe what you updated',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: mediumSeaGreen.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: mediumSeaGreen),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: lightMint,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: mediumSeaGreen, size: 16),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'This message will be sent to the admin team for review',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            foregroundColor: darkTeal.withValues(alpha: 0.7),
                          ),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            note = controller.text.trim();
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mediumSeaGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Continue'),
                        ),
                      ],
                    );
                  },
                );
                final ok = await EmployerRegistrationService.resubmitEmployerApplication(
                  employerId: user.id,
                  messageToAdmin: note,
                );
                if (ok) {
                  SafeSnackBar.showSuccess(context, message: 'Resubmitted for review');
                  await _loadApplicationStatus();
                } else {
                  SafeSnackBar.showError(context, message: 'Failed to resubmit');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Fix and resubmit'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final formatter = DateFormat('MMM d, y • h:mm a');
    return formatter.format(date);
  }

  List<String> _computeMissingDocs() {
    if (_verificationStatus == null) return const [];
    final missing = <String>[];
    if ((_verificationStatus!['business_license_url'] as String?) == null ||
        (_verificationStatus!['business_license_url'] as String?)!.isEmpty) {
      missing.add('Business license document');
    }
    if ((_verificationStatus!['tax_id_document_url'] as String?) == null ||
        (_verificationStatus!['tax_id_document_url'] as String?)!.isEmpty) {
      missing.add('Tax ID document');
    }
    if ((_verificationStatus!['business_registration_url'] as String?) == null ||
        (_verificationStatus!['business_registration_url'] as String?)!.isEmpty) {
      missing.add('Business registration document');
    }
    return missing;
  }

  /// Compute accurate completion percent (0..1)
  double _computeCompletionPercent() {
    if (_verificationStatus == null) return 0;
    int total = 3;
    int done = 0;
    if ((_verificationStatus!['business_license_url'] as String?)?.isNotEmpty == true) done++;
    if ((_verificationStatus!['tax_id_document_url'] as String?)?.isNotEmpty == true) done++;
    if ((_verificationStatus!['business_registration_url'] as String?)?.isNotEmpty == true) done++;
    return total == 0 ? 0 : done / total;
  }

  Widget _buildStatusContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: mediumSeaGreen),
            const SizedBox(height: 16),
            Text(
              'Loading application status...',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadApplicationStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return _buildStatusCard();
  }

  void _openEditCompanySheet({String? initialSection}) {
    final owner = Supabase.instance.client.auth.currentUser;
    if (owner == null) return;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: _companyInfo?['name'] ?? '');
    final aboutCtrl = TextEditingController(text: _companyInfo?['about'] ?? '');
    final addressCtrl = TextEditingController(text: _verificationStatus?['business_address'] ?? '');
    final cityCtrl = TextEditingController(text: _verificationStatus?['city'] ?? '');
    final provinceCtrl = TextEditingController(text: _verificationStatus?['province'] ?? '');
    final postalCtrl = TextEditingController(text: _verificationStatus?['postal_code'] ?? '');
    final countryCtrl = TextEditingController(text: _verificationStatus?['country'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit, color: mediumSeaGreen),
                        const SizedBox(width: 8),
                        const Text('Edit company information', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Company name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: aboutCtrl,
                      decoration: const InputDecoration(labelText: 'About'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(children: const [Text('Business address', style: TextStyle(fontWeight: FontWeight.w600))]),
                    const SizedBox(height: 6),
                    TextFormField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Street address')),
                    const SizedBox(height: 8),
                    TextFormField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City')),
                    const SizedBox(height: 8),
                    TextFormField(controller: provinceCtrl, decoration: const InputDecoration(labelText: 'Province')),
                    const SizedBox(height: 8),
                    TextFormField(controller: postalCtrl, decoration: const InputDecoration(labelText: 'Postal code')),
                    const SizedBox(height: 8),
                    TextFormField(controller: countryCtrl, decoration: const InputDecoration(labelText: 'Country')),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final ok = await EmployerRegistrationService.updateCompanyAndDetails(
                              ownerId: owner.id,
                              companyUpdates: {
                                if (nameCtrl.text.trim().isNotEmpty) 'name': nameCtrl.text.trim(),
                                'about': aboutCtrl.text.trim(),
                              },
                              detailsUpdates: {
                                'business_address': addressCtrl.text.trim(),
                                'city': cityCtrl.text.trim(),
                                'province': provinceCtrl.text.trim(),
                                'postal_code': postalCtrl.text.trim(),
                                'country': countryCtrl.text.trim(),
                              },
                            );
                            if (ok) {
                              // Optionally mark under_review to signal update without resubmit
                              await _loadApplicationStatus();
                              if (mounted) Navigator.pop(ctx);
                              SafeSnackBar.showSuccess(context, message: 'Company info updated');
                            } else {
                              SafeSnackBar.showError(context, message: 'Failed to update');
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: mediumSeaGreen, foregroundColor: Colors.white),
                          child: const Text('Save changes'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Application Status',
          style: TextStyle(
            color: darkTeal,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: Icon(Icons.logout, color: darkTeal),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: RefreshIndicator(
            onRefresh: _loadApplicationStatus,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Text(
                  'Employer Application',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              if (_verificationStatus != null &&
                  (_verificationStatus!['verification_status'] as String?) != null)
                Center(
                  child: _buildStatusPill(
                    (_verificationStatus!['verification_status'] as String?)!,
                  ),
                ),
              const SizedBox(height: 15),
              Center(
              child: Text(
                'Track your application status and next steps',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              ),
              const SizedBox(height: 24),

              // Company info if available
              if (_companyInfo != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: mediumSeaGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.business,
                          color: mediumSeaGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _companyInfo!['name'] ?? 'Company Name',
                              style: TextStyle(
                                color: darkTeal,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_companyInfo!['about'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _companyInfo!['about'],
                                style: TextStyle(
                                  color: darkTeal.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Status card
              _buildStatusContent(),

              const SizedBox(height: 24),

              // Refresh button
              if (!_isLoading && _error == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loadApplicationStatus,
                    icon: Icon(Icons.refresh, color: mediumSeaGreen),
                    label: Text(
                      'Refresh Status',
                      style: TextStyle(color: mediumSeaGreen),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: mediumSeaGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    ),
  );
  }
}
  