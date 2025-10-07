import 'package:flutter/material.dart';
import '../../models/employer_registration_data.dart';
import '../../services/input_security_service.dart';

class EmployerRegistrationBusinessInfoScreen extends StatefulWidget {
  final EmployerRegistrationData registrationData;
  final Function(EmployerRegistrationData) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const EmployerRegistrationBusinessInfoScreen({
    super.key,
    required this.registrationData,
    required this.onDataChanged,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<EmployerRegistrationBusinessInfoScreen> createState() => _EmployerRegistrationBusinessInfoScreenState();
}

class _EmployerRegistrationBusinessInfoScreenState extends State<EmployerRegistrationBusinessInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _businessLicenseController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _businessRegistrationController = TextEditingController();

  String _selectedCountry = 'Philippines';
  String _selectedIndustry = '';
  String _selectedCompanySize = '';
  String _selectedBusinessType = '';

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  // Dropdown options
  final List<String> _industries = [
    'Technology',
    'Healthcare',
    'Finance',
    'Education',
    'Manufacturing',
    'Retail',
    'Food & Beverage',
    'Real Estate',
    'Construction',
    'Transportation',
    'Media & Entertainment',
    'Consulting',
    'Non-profit',
    'Government',
    'Other',
  ];

  final List<String> _companySizes = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '501-1000',
    '1000+',
  ];

  final List<String> _businessTypes = [
    'Corporation',
    'Partnership',
    'Sole Proprietorship',
    'LLC',
    'Non-profit',
    'Government',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _businessAddressController.text = widget.registrationData.businessAddress;
    _cityController.text = widget.registrationData.city;
    _provinceController.text = widget.registrationData.province;
    _postalCodeController.text = widget.registrationData.postalCode;
    _businessLicenseController.text = widget.registrationData.businessLicenseNumber ?? '';
    _taxIdController.text = widget.registrationData.taxIdNumber ?? '';
    _businessRegistrationController.text = widget.registrationData.businessRegistrationNumber ?? '';
    
    _selectedCountry = widget.registrationData.country;
    _selectedIndustry = widget.registrationData.industry;
    _selectedCompanySize = widget.registrationData.companySize;
    _selectedBusinessType = widget.registrationData.businessType;
  }

  @override
  void dispose() {
    _businessAddressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _businessLicenseController.dispose();
    _taxIdController.dispose();
    _businessRegistrationController.dispose();
    super.dispose();
  }

  void _updateRegistrationData() {
    widget.onDataChanged(
      widget.registrationData.copyWith(
        businessAddress: _businessAddressController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        country: _selectedCountry,
        industry: _selectedIndustry,
        companySize: _selectedCompanySize,
        businessType: _selectedBusinessType,
        businessLicenseNumber: _businessLicenseController.text.trim().isNotEmpty ? _businessLicenseController.text.trim() : null,
        taxIdNumber: _taxIdController.text.trim().isNotEmpty ? _taxIdController.text.trim() : null,
        businessRegistrationNumber: _businessRegistrationController.text.trim().isNotEmpty ? _businessRegistrationController.text.trim() : null,
      ),
    );
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
              'Business Information',
              style: TextStyle(
                color: darkTeal,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about your business location and details',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),

            // Business Address
            _buildTextField(
              controller: _businessAddressController,
              label: 'Business Address *',
              hint: 'Enter your complete business address',
              icon: Icons.location_on,
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Business address is required';
                }
                final error = InputSecurityService.validateSecureAddress(value.trim());
                return error;
              },
              onChanged: _updateRegistrationData,
            ),

            const SizedBox(height: 20),

            // City and Province Row
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'City *',
                    hint: 'Enter city',
                    icon: Icons.location_city,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'City is required';
                      }
                      final error = InputSecurityService.validateSecureName(value.trim(), 'City');
                      return error;
                    },
                    onChanged: _updateRegistrationData,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextField(
                    controller: _provinceController,
                    label: 'Province *',
                    hint: 'Enter province',
                    icon: Icons.map,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Province is required';
                      }
                      final error = InputSecurityService.validateSecureName(value.trim(), 'Province');
                      return error;
                    },
                    onChanged: _updateRegistrationData,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Postal Code and Country Row
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildTextField(
                    controller: _postalCodeController,
                    label: 'Postal Code *',
                    hint: 'Enter postal code',
                    icon: Icons.local_post_office,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Postal code is required';
                      }
                      // Philippine postal codes are typically 4 digits
                      if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) {
                        return 'Postal code must be 4 digits';
                      }
                      return null;
                    },
                    onChanged: _updateRegistrationData,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildDropdown(
                    label: 'Country *',
                    value: _selectedCountry,
                    items: const ['Philippines'],
                    icon: Icons.public,
                    onChanged: (value) {
                      setState(() {
                        _selectedCountry = value!;
                      });
                      _updateRegistrationData();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Industry
            _buildDropdown(
              label: 'Industry *',
              value: _selectedIndustry,
              items: _industries,
              icon: Icons.business_center,
              onChanged: (value) {
                setState(() {
                  _selectedIndustry = value!;
                });
                _updateRegistrationData();
              },
            ),

            const SizedBox(height: 20),

            // Company Size
            _buildDropdown(
              label: 'Company Size *',
              value: _selectedCompanySize,
              items: _companySizes,
              icon: Icons.people,
              onChanged: (value) {
                setState(() {
                  _selectedCompanySize = value!;
                });
                _updateRegistrationData();
              },
            ),

            const SizedBox(height: 20),

            // Business Type
            _buildDropdown(
              label: 'Business Type *',
              value: _selectedBusinessType,
              items: _businessTypes,
              icon: Icons.account_balance,
              onChanged: (value) {
                setState(() {
                  _selectedBusinessType = value!;
                });
                _updateRegistrationData();
              },
            ),

            const SizedBox(height: 32),

            // Legal Documents Section
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
                      Icon(Icons.description, color: mediumSeaGreen),
                      const SizedBox(width: 8),
                      Text(
                        'Legal Documents (Optional)',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These documents help verify your business legitimacy and may speed up the approval process.',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Business License Number
                  _buildTextField(
                    controller: _businessLicenseController,
                    label: 'Business License Number',
                    hint: 'Enter business license number',
                    icon: Icons.business,
                    onChanged: _updateRegistrationData,
                  ),

                  const SizedBox(height: 16),

                  // Tax ID Number
                  _buildTextField(
                    controller: _taxIdController,
                    label: 'Tax ID Number',
                    hint: 'Enter tax identification number',
                    icon: Icons.receipt,
                    onChanged: _updateRegistrationData,
                  ),

                  const SizedBox(height: 16),

                  // Business Registration Number
                  _buildTextField(
                    controller: _businessRegistrationController,
                    label: 'Business Registration Number',
                    hint: 'Enter business registration number',
                    icon: Icons.assignment,
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

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
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
        DropdownButtonFormField<String>(
          value: value.isEmpty ? null : value,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Container(
                width: double.infinity,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          isExpanded: true,
          menuMaxHeight: 300,
          decoration: InputDecoration(
            hintText: label.contains('Company Size') ? 'Select number of employees' : 'Select $label',
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
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '$label is required';
            }
            return null;
          },
        ),
      ],
    );
  }
}
