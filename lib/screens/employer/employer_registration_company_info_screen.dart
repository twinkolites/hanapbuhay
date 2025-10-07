import 'package:flutter/material.dart';
import '../../models/employer_registration_data.dart';
import '../../services/input_security_service.dart';

class EmployerRegistrationCompanyInfoScreen extends StatefulWidget {
  final EmployerRegistrationData registrationData;
  final Function(EmployerRegistrationData) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const EmployerRegistrationCompanyInfoScreen({
    super.key,
    required this.registrationData,
    required this.onDataChanged,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<EmployerRegistrationCompanyInfoScreen> createState() => _EmployerRegistrationCompanyInfoScreenState();
}

class _EmployerRegistrationCompanyInfoScreenState extends State<EmployerRegistrationCompanyInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyAboutController = TextEditingController();
  final _companyWebsiteController = TextEditingController();
  final _contactPersonNameController = TextEditingController();
  final _contactPersonPositionController = TextEditingController();
  final _contactPersonEmailController = TextEditingController();
  final _contactPersonPhoneController = TextEditingController();

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _companyNameController.text = widget.registrationData.companyName;
    _companyAboutController.text = widget.registrationData.companyAbout;
    _companyWebsiteController.text = widget.registrationData.companyWebsite ?? '';
    _contactPersonNameController.text = widget.registrationData.contactPersonName;
    _contactPersonPositionController.text = widget.registrationData.contactPersonPosition;
    _contactPersonEmailController.text = widget.registrationData.contactPersonEmail;
    _contactPersonPhoneController.text = widget.registrationData.contactPersonPhone ?? '';
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAboutController.dispose();
    _companyWebsiteController.dispose();
    _contactPersonNameController.dispose();
    _contactPersonPositionController.dispose();
    _contactPersonEmailController.dispose();
    _contactPersonPhoneController.dispose();
    super.dispose();
  }

  void _updateRegistrationData() {
    widget.onDataChanged(
      widget.registrationData.copyWith(
        companyName: _companyNameController.text.trim(),
        companyAbout: _companyAboutController.text.trim(),
        companyWebsite: _companyWebsiteController.text.trim().isNotEmpty ? _companyWebsiteController.text.trim() : null,
        contactPersonName: _contactPersonNameController.text.trim(),
        contactPersonPosition: _contactPersonPositionController.text.trim(),
        contactPersonEmail: _contactPersonEmailController.text.trim(),
        contactPersonPhone: _contactPersonPhoneController.text.trim().isNotEmpty ? _contactPersonPhoneController.text.trim() : null,
      ),
    );
  }

  bool _isValidWebsite(String url) {
    if (url.trim().isEmpty) return true;
    return RegExp(r'^https?:\/\/.+').hasMatch(url.trim());
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      _updateRegistrationData();
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Company Information',
              style: TextStyle(
                color: darkTeal,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about your company',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),

            // Company Name
            _buildTextField(
              controller: _companyNameController,
              label: 'Company Name *',
              hint: 'Enter your company name',
              icon: Icons.business,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Company name is required';
                }
                final error = InputSecurityService.validateSecureOrganization(value.trim());
                return error;
              },
              onChanged: _updateRegistrationData,
            ),

            const SizedBox(height: 20),

            // Company Description
            _buildTextField(
              controller: _companyAboutController,
              label: 'Company Description *',
              hint: 'Describe your company, what you do, and your mission',
              icon: Icons.description,
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Company description is required';
                }
                if (value.trim().length < 20) {
                  return 'Please provide a more detailed description (at least 20 characters)';
                }
                // Use secure validation for additional security checks
                final sanitized = InputSecurityService.sanitizeText(value.trim());
                if (sanitized != value.trim()) {
                  return 'Company description contains invalid characters';
                }
                final suspiciousCheck = InputSecurityService.detectSuspiciousPatterns(value.trim(), 'Company description');
                if (suspiciousCheck != null) {
                  return suspiciousCheck;
                }
                return null;
              },
              onChanged: _updateRegistrationData,
            ),

            const SizedBox(height: 20),

            // Company Website
            _buildTextField(
              controller: _companyWebsiteController,
              label: 'Company Website',
              hint: 'https://www.yourcompany.com',
              icon: Icons.language,
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  if (!_isValidWebsite(value)) {
                    return 'Please enter a valid website URL (starting with http:// or https://)';
                  }
                  // Additional security validation
                  final suspiciousCheck = InputSecurityService.detectSuspiciousPatterns(value.trim(), 'Website URL');
                  if (suspiciousCheck != null) {
                    return suspiciousCheck;
                  }
                }
                return null;
              },
              onChanged: _updateRegistrationData,
            ),

            const SizedBox(height: 32),

            // Contact Person Section
            Container(
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
                      Icon(Icons.contact_phone, color: mediumSeaGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Contact Person Information',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This person will be the main contact for job postings and applications.',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Contact Person Name
                  _buildTextField(
                    controller: _contactPersonNameController,
                    label: 'Contact Person Name *',
                    hint: 'Enter contact person full name',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Contact person name is required';
                      }
                      final error = InputSecurityService.validateSecureName(value.trim(), 'Contact person name');
                      return error;
                    },
                    onChanged: _updateRegistrationData,
                  ),

                  const SizedBox(height: 16),

                  // Contact Person Position
                  _buildTextField(
                    controller: _contactPersonPositionController,
                    label: 'Position/Title *',
                    hint: 'e.g., HR Manager, Recruiter, CEO',
                    icon: Icons.work,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Contact person position is required';
                      }
                      final error = InputSecurityService.validateSecurePosition(value.trim());
                      return error;
                    },
                    onChanged: _updateRegistrationData,
                  ),

                  const SizedBox(height: 16),

                  // Contact Person Email
                  _buildTextField(
                    controller: _contactPersonEmailController,
                    label: 'Contact Email *',
                    hint: 'contact@yourcompany.com',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Contact email is required';
                      }
                      final error = InputSecurityService.validateSecureEmail(value.trim());
                      return error;
                    },
                    onChanged: _updateRegistrationData,
                  ),

                  const SizedBox(height: 16),

                  // Contact Person Phone
                  _buildTextField(
                    controller: _contactPersonPhoneController,
                    label: 'Contact Phone',
                    hint: '09XXXXXXXXX or +63 9XX XXX XXXX',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final error = InputSecurityService.validatePhilippinePhone(value.trim());
                        return error;
                      }
                      return null;
                    },
                    onChanged: _updateRegistrationData,
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
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mediumSeaGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Next Step',
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
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged != null ? (_) => onChanged() : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: mediumSeaGreen),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: darkTeal.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: darkTeal.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: mediumSeaGreen, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
