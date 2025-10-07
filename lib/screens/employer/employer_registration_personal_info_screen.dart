import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/employer_registration_data.dart';
import '../../services/input_security_service.dart';
import '../../utils/safe_snackbar.dart';

class EmployerRegistrationPersonalInfoScreen extends StatefulWidget {
  final EmployerRegistrationData registrationData;
  final Function(EmployerRegistrationData) onDataChanged;
  final VoidCallback onNext;

  const EmployerRegistrationPersonalInfoScreen({
    super.key,
    required this.registrationData,
    required this.onDataChanged,
    required this.onNext,
  });

  @override
  State<EmployerRegistrationPersonalInfoScreen> createState() => _EmployerRegistrationPersonalInfoScreenState();
}

class _EmployerRegistrationPersonalInfoScreenState extends State<EmployerRegistrationPersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  DateTime? _selectedBirthday;

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
    _fullNameController.text = widget.registrationData.fullName;
    _emailController.text = widget.registrationData.email;
    _passwordController.text = widget.registrationData.password;
    _phoneController.text = widget.registrationData.phoneNumber ?? '';
    _displayNameController.text = widget.registrationData.displayName ?? '';
    _usernameController.text = widget.registrationData.username ?? '';
    _selectedBirthday = widget.registrationData.birthday;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _updateRegistrationData() {
    widget.onDataChanged(
      widget.registrationData.copyWith(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phoneNumber: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        displayName: _displayNameController.text.trim().isNotEmpty ? _displayNameController.text.trim() : null,
        username: _usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : null,
        birthday: _selectedBirthday,
      ),
    );
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Must be at least 18
    );

    if (picked != null && picked != _selectedBirthday && mounted) {
      setState(() {
        _selectedBirthday = picked;
      });
      _updateRegistrationData();
    }
  }

  bool _isValidPhilippinesPhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid Philippines mobile number
    return RegExp(r'^09\d{9}$').hasMatch(digitsOnly) ||
           RegExp(r'^639\d{9}$').hasMatch(digitsOnly);
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        SafeSnackBar.showError(
          context,
          message: 'Passwords do not match',
        );
        return;
      }

      if (_selectedBirthday == null) {
        SafeSnackBar.showError(
          context,
          message: 'Please select your birthday',
        );
        return;
      }

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
              'Personal Information',
              style: TextStyle(
                color: darkTeal,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about yourself to get started',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),

            // Full Name
            _buildTextField(
              controller: _fullNameController,
              label: 'Full Name *',
              hint: 'Enter your full name',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Full name is required';
                }
                final error = InputSecurityService.validateSecureName(value.trim(), 'Full name');
                return error;
              },
              onChanged: _updateRegistrationData,
            ),

            const SizedBox(height: 20),

            // Email
            _buildTextField(
              controller: _emailController,
              label: 'Email Address *',
              hint: 'Enter your email address',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                final error = InputSecurityService.validateSecureEmail(value.trim());
                return error;
              },
              onChanged: _updateRegistrationData,
            ),

            const SizedBox(height: 20),

            // Password
            _buildTextField(
              controller: _passwordController,
              label: 'Password *',
              hint: 'Create a strong password',
              icon: Icons.lock,
              obscureText: !_isPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: darkTeal.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                final error = InputSecurityService.validateSecurePassword(value);
                return error;
              },
              onChanged: _updateRegistrationData,
            ),

            const SizedBox(height: 20),

            // Confirm Password
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password *',
              hint: 'Confirm your password',
              icon: Icons.lock_outline,
              obscureText: !_isConfirmPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: darkTeal.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Phone Number
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: '09XXXXXXXXX or +63 9XX XXX XXXX',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  if (!_isValidPhilippinesPhoneNumber(value.trim())) {
                    return 'Invalid Philippines phone number format';
                  }
                }
                return null;
              },
              onChanged: _updateRegistrationData,
            ),

            const SizedBox(height: 20),

            // Birthday
            _buildDateField(
              label: 'Birthday *',
              value: _selectedBirthday,
              onTap: _selectBirthday,
            ),

            const SizedBox(height: 20),

            // Display Name (Optional)
            _buildTextField(
              controller: _displayNameController,
              label: 'Display Name',
              hint: 'How you want to be displayed (optional)',
              icon: Icons.badge,
              onChanged: _updateRegistrationData,
            ),

            const SizedBox(height: 20),

            // Username (Optional)
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              hint: 'Choose a unique username (optional)',
              icon: Icons.alternate_email,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final error = InputSecurityService.validateSecureUsername(value.trim());
                  return error;
                }
                return null;
              },
              onChanged: _updateRegistrationData,
            ),

            const SizedBox(height: 40),

            // Next Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mediumSeaGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
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
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
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
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged != null ? (_) => onChanged() : null,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: mediumSeaGreen),
            suffixIcon: suffixIcon,
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

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
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
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: darkTeal.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: mediumSeaGreen),
                const SizedBox(width: 12),
                Text(
                  value != null
                      ? '${value.day}/${value.month}/${value.year}'
                      : 'Select your birthday',
                  style: TextStyle(
                    color: value != null ? darkTeal : darkTeal.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_drop_down,
                  color: darkTeal.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
