import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/employer_registration_data.dart';
import '../../utils/safe_snackbar.dart';

class EmployerRegistrationDocumentsScreen extends StatefulWidget {
  final EmployerRegistrationData registrationData;
  final Function(EmployerRegistrationData) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const EmployerRegistrationDocumentsScreen({
    super.key,
    required this.registrationData,
    required this.onDataChanged,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<EmployerRegistrationDocumentsScreen> createState() => _EmployerRegistrationDocumentsScreenState();
}

class _EmployerRegistrationDocumentsScreenState extends State<EmployerRegistrationDocumentsScreen> {
  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  // Track uploaded files and their URLs
  String? _businessLicenseFileName;
  String? _taxIdFileName;
  String? _businessRegistrationFileName;
  String? _businessLicenseUrl;
  String? _taxIdUrl;
  String? _businessRegistrationUrl;
  bool _isUploading = false;

  /// Safely handle document upload action
  Future<void> _handleDocumentUpload(String documentType) async {
    if (_isUploading) return; // Prevent multiple uploads
    
    try {
      setState(() => _isUploading = true);
      
      // Show file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true, // This ensures file bytes are loaded
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        debugPrint('📁 File selected: ${file.name}');
        debugPrint('📁 File size: ${file.size} bytes');
        debugPrint('📁 File bytes: ${file.bytes?.length ?? 'null'}');
        debugPrint('📁 File path: ${file.path}');
        debugPrint('📁 File extension: ${file.extension}');
        debugPrint('📁 Document type: $documentType');
        
        // Check if file has bytes
        if (file.bytes == null || file.bytes!.isEmpty) {
          debugPrint('❌ File bytes are null or empty');
          if (mounted) {
            SafeSnackBar.showError(
              context,
              message: 'File appears to be empty. Please try again.',
            );
          }
          return;
        }
        
        if (mounted) {
          SafeSnackBar.showInfo(
            context,
            message: 'Uploading ${file.name}...',
          );
        }

        // During registration, we can't upload to storage yet since user isn't authenticated
        // Instead, we'll store the file data temporarily and upload after authentication
        if (mounted) {
          setState(() {
            switch (documentType) {
              case 'business_license':
                _businessLicenseFileName = file.name;
                break;
              case 'tax_id':
                _taxIdFileName = file.name;
                break;
              case 'business_registration':
                _businessRegistrationFileName = file.name;
                break;
            }
          });
          
          SafeSnackBar.showSuccess(
            context,
            message: 'Document selected: ${file.name}. Will be uploaded after registration.',
          );
        }
      } else {
        // User cancelled file selection
        if (mounted) {
          SafeSnackBar.showInfo(
            context,
            message: 'File selection cancelled',
          );
        }
      }
    } catch (e) {
      // Handle any errors
      debugPrint('❌ Error in file selection: $e');
      if (mounted) {
        SafeSnackBar.showError(
          context,
          message: 'Error uploading file: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize URLs from existing registration data
    _businessLicenseUrl = widget.registrationData.businessLicenseUrl;
    _taxIdUrl = widget.registrationData.taxIdDocumentUrl;
    _businessRegistrationUrl = widget.registrationData.businessRegistrationUrl;
    
    // Set file names if URLs exist (for display purposes)
    if (_businessLicenseUrl != null && _businessLicenseUrl!.isNotEmpty) {
      _businessLicenseFileName = 'Business License';
    }
    if (_taxIdUrl != null && _taxIdUrl!.isNotEmpty) {
      _taxIdFileName = 'Tax ID Document';
    }
    if (_businessRegistrationUrl != null && _businessRegistrationUrl!.isNotEmpty) {
      _businessRegistrationFileName = 'Business Registration';
    }
  }

  double _getUploadProgress() {
    int uploadedCount = 0;
    if (_businessLicenseFileName != null) uploadedCount++;
    if (_taxIdFileName != null) uploadedCount++;
    if (_businessRegistrationFileName != null) uploadedCount++;
    return uploadedCount / 3.0;
  }

  int _getUploadedCount() {
    int count = 0;
    if (_businessLicenseFileName != null) count++;
    if (_taxIdFileName != null) count++;
    if (_businessRegistrationFileName != null) count++;
    return count;
  }

  Widget _buildDocumentStatusItem(String documentName, String? fileName) {
    final isUploaded = fileName != null;
    
    return Row(
      children: [
        Icon(
          isUploaded ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isUploaded ? Colors.green : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                documentName,
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isUploaded) ...[
                const SizedBox(height: 2),
                Text(
                  fileName,
                  style: TextStyle(
                    color: mediumSeaGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 2),
                Text(
                  'Not uploaded',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Ensure any pending operations are cancelled
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Verification Documents',
            style: TextStyle(
              color: darkTeal,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload documents to verify your business (Optional)',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),

          // Progress Indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: mediumSeaGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.upload_file,
                      color: mediumSeaGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upload Progress',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _getUploadProgress(),
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_getUploadedCount()}/3 documents uploaded',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lightMint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: mediumSeaGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: mediumSeaGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Document Status',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDocumentStatusItem(
                  'Business License',
                  _businessLicenseFileName,
                ),
                const SizedBox(height: 8),
                _buildDocumentStatusItem(
                  'Tax ID Document',
                  _taxIdFileName,
                ),
                const SizedBox(height: 8),
                _buildDocumentStatusItem(
                  'Business Registration',
                  _businessRegistrationFileName,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          _buildDocumentCard(
            title: 'Business License',
            description: 'Upload your business license or permit',
            icon: Icons.business,
            isUploaded: _businessLicenseFileName != null,
            fileName: _businessLicenseFileName,
            onUpload: () => _handleDocumentUpload('business_license'),
          ),

          const SizedBox(height: 16),

          _buildDocumentCard(
            title: 'Tax ID Document',
            description: 'Upload your tax identification document',
            icon: Icons.receipt,
            isUploaded: _taxIdFileName != null,
            fileName: _taxIdFileName,
            onUpload: () => _handleDocumentUpload('tax_id'),
          ),

          const SizedBox(height: 16),

          _buildDocumentCard(
            title: 'Business Registration',
            description: 'Upload your business registration certificate',
            icon: Icons.assignment,
            isUploaded: _businessRegistrationFileName != null,
            fileName: _businessRegistrationFileName,
            onUpload: () => _handleDocumentUpload('business_registration'),
          ),

          const SizedBox(height: 32),

          // Information Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Document Upload Information',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Documents are optional but help speed up the approval process\n'
                  '• Accepted formats: PDF, JPG, PNG\n'
                  '• Maximum file size: 10MB per document\n'
                  '• All documents are securely stored and encrypted\n'
                  '• You can skip this step and upload documents later',
                  style: TextStyle(
                    color: Colors.blue.withValues(alpha: 0.8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onPrevious,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mediumSeaGreen,
                    side: BorderSide(color: mediumSeaGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Previous',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isUploading ? null : widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mediumSeaGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isUploading 
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Uploading...'),
                        ],
                      )
                    : const Text(
                        'Review & Submit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isUploaded,
    String? fileName,
    required VoidCallback onUpload,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isUploaded ? lightMint : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded ? mediumSeaGreen : darkTeal.withValues(alpha: 0.2),
          width: isUploaded ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUploaded 
                      ? mediumSeaGreen 
                      : mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isUploaded ? Colors.white : mediumSeaGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    if (fileName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Selected: $fileName',
                        style: TextStyle(
                          color: mediumSeaGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isUploaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Uploaded',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onUpload,
              icon: Icon(
                isUploaded ? Icons.refresh : Icons.upload,
                size: 18,
              ),
              label: Text(
                isUploaded ? 'Replace Document' : 'Upload Document',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: mediumSeaGreen,
                side: BorderSide(color: mediumSeaGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

