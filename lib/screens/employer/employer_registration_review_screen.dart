import 'package:flutter/material.dart';
import '../../models/employer_registration_data.dart';

class EmployerRegistrationReviewScreen extends StatefulWidget {
  final EmployerRegistrationData registrationData;
  final VoidCallback onSubmit;
  final VoidCallback onPrevious;
  final bool isLoading;

  const EmployerRegistrationReviewScreen({
    super.key,
    required this.registrationData,
    required this.onSubmit,
    required this.onPrevious,
    required this.isLoading,
  });

  @override
  State<EmployerRegistrationReviewScreen> createState() => _EmployerRegistrationReviewScreenState();
}

class _EmployerRegistrationReviewScreenState extends State<EmployerRegistrationReviewScreen> {
  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Review & Submit',
            style: TextStyle(
              color: darkTeal,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please review your information before submitting',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),

          // Personal Information Section
          _buildSection(
            title: 'Personal Information',
            icon: Icons.person,
            children: [
              _buildInfoRow('Full Name', widget.registrationData.fullName),
              _buildInfoRow('Email', widget.registrationData.email),
              if (widget.registrationData.phoneNumber != null)
                _buildInfoRow('Phone', widget.registrationData.phoneNumber!),
              if (widget.registrationData.birthday != null)
                _buildInfoRow('Birthday', _formatDate(widget.registrationData.birthday!)),
              if (widget.registrationData.displayName != null)
                _buildInfoRow('Display Name', widget.registrationData.displayName!),
              if (widget.registrationData.username != null)
                _buildInfoRow('Username', widget.registrationData.username!),
            ],
          ),

          const SizedBox(height: 24),

          // Company Information Section
          _buildSection(
            title: 'Company Information',
            icon: Icons.business,
            children: [
              _buildInfoRow('Company Name', widget.registrationData.companyName),
              _buildInfoRow('Description', widget.registrationData.companyAbout),
              if (widget.registrationData.companyWebsite != null)
                _buildInfoRow('Website', widget.registrationData.companyWebsite!),
            ],
          ),

          const SizedBox(height: 24),

          // Contact Person Section
          _buildSection(
            title: 'Contact Person',
            icon: Icons.contact_phone,
            children: [
              _buildInfoRow('Name', widget.registrationData.contactPersonName),
              _buildInfoRow('Position', widget.registrationData.contactPersonPosition),
              _buildInfoRow('Email', widget.registrationData.contactPersonEmail),
              if (widget.registrationData.contactPersonPhone != null)
                _buildInfoRow('Phone', widget.registrationData.contactPersonPhone!),
            ],
          ),

          const SizedBox(height: 24),

          // Business Information Section
          _buildSection(
            title: 'Business Information',
            icon: Icons.location_on,
            children: [
              _buildInfoRow('Address', widget.registrationData.businessAddress),
              _buildInfoRow('City', widget.registrationData.city),
              _buildInfoRow('Province', widget.registrationData.province),
              _buildInfoRow('Postal Code', widget.registrationData.postalCode),
              _buildInfoRow('Country', widget.registrationData.country),
              _buildInfoRow('Industry', widget.registrationData.industry),
              _buildInfoRow('Company Size', widget.registrationData.companySize),
              _buildInfoRow('Business Type', widget.registrationData.businessType),
            ],
          ),

          const SizedBox(height: 24),

          // Legal Documents Section
          if (_hasLegalDocuments())
            _buildSection(
              title: 'Legal Documents',
              icon: Icons.description,
              children: [
                if (widget.registrationData.businessLicenseNumber != null)
                  _buildInfoRow('Business License', widget.registrationData.businessLicenseNumber!),
                if (widget.registrationData.taxIdNumber != null)
                  _buildInfoRow('Tax ID', widget.registrationData.taxIdNumber!),
                if (widget.registrationData.businessRegistrationNumber != null)
                  _buildInfoRow('Business Registration', widget.registrationData.businessRegistrationNumber!),
              ],
            ),

          const SizedBox(height: 32),

          // Important Notice
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Important Information',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Your registration will be reviewed by our admin team\n'
                  '• You will receive an email notification once approved\n'
                  '• The approval process typically takes 1-3 business days\n'
                  '• You can start posting jobs once approved\n'
                  '• Contact support if you have any questions',
                  style: TextStyle(
                    color: Colors.orange.withValues(alpha: 0.8),
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
                  onPressed: widget.isLoading ? null : widget.onPrevious,
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
                  onPressed: widget.isLoading ? null : widget.onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mediumSeaGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Submit Registration',
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: lightMint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: mediumSeaGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: darkTeal,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasLegalDocuments() {
    return widget.registrationData.businessLicenseNumber != null ||
           widget.registrationData.taxIdNumber != null ||
           widget.registrationData.businessRegistrationNumber != null;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
