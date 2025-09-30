import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import 'login_screen.dart';
import '../services/input_security_service.dart';

// Using Supabase.instance.client directly instead of global variable

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  bool _acceptTerms = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _fullNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();
  DateTime? _selectedBirthday;
  StreamSubscription<AuthState>? _authSubscription;

  // Phone number validation
  bool _isPhoneNumber = false;
  String _formattedPhoneNumber = '';

  // Form key
  final _formKey = GlobalKey<FormState>();

  // Real-time validation states
  String? _fullNameError;
  String? _usernameError;
  String? _emailError;
  String? _phoneError;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    // Listen for auth state once user confirms email from deep link
    _setupVerificationListener();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fullNameController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  // Phone number validation methods
  bool _isValidPhilippinesPhoneNumber(String input) {
    // Remove all non-digit characters
    String digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');

    // Check if it's exactly 11 digits and starts with 09 (Philippine mobile format)
    if (digitsOnly.length == 11 && digitsOnly.startsWith('09')) {
      return true;
    }

    // Check if it's 13 digits starting with +63 or 63
    if (digitsOnly.length == 13 && digitsOnly.startsWith('63')) {
      String withoutCountryCode = digitsOnly.substring(2);
      return withoutCountryCode.startsWith('09') &&
          withoutCountryCode.length == 11;
    }

    return false;
  }

  String _formatPhoneNumber(String input) {
    // Remove all non-digit characters
    String digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');

    // If it starts with 63, remove it
    if (digitsOnly.startsWith('63') && digitsOnly.length == 13) {
      digitsOnly = digitsOnly.substring(2);
    }

    // Format as +63 9XX XXX XXXX (11-digit format starting with 09)
    if (digitsOnly.length == 11 && digitsOnly.startsWith('09')) {
      return '+63 ${digitsOnly.substring(0, 4)} ${digitsOnly.substring(4, 7)} ${digitsOnly.substring(7)}';
    }

    return input;
  }

  void _validateInput(String input) {
    setState(() {
      _isPhoneNumber = _isValidPhilippinesPhoneNumber(input);
      if (_isPhoneNumber) {
        _formattedPhoneNumber = _formatPhoneNumber(input);
      } else {
        _formattedPhoneNumber = '';
      }
    });
  }

  /// Real-time validation methods for UX (basic checks only)
  void _validateFullName(String value) {
    if (value.trim().isEmpty) {
      setState(() => _fullNameError = 'Full name is required');
      return;
    }
    // Basic format check for real-time feedback
    if (value.trim().length < 3) {
      setState(
        () => _fullNameError = 'Full name must be at least 3 characters',
      );
      return;
    }
    // Clear error if basic requirements are met
    setState(() => _fullNameError = null);
  }

  void _validateUsername(String value) {
    if (value.trim().isEmpty) {
      setState(() => _usernameError = 'Username is required');
      return;
    }
    // Basic format check for real-time feedback
    if (value.trim().length < 3) {
      setState(() => _usernameError = 'Username must be at least 3 characters');
      return;
    }
    // Clear error if basic requirements are met
    setState(() => _usernameError = null);
  }

  void _validateEmail(String value) {
    if (value.trim().isEmpty) {
      setState(() => _emailError = 'Email is required');
      return;
    }
    // Basic format check for real-time feedback
    if (!value.contains('@') || !value.contains('.')) {
      setState(() => _emailError = 'Please enter a valid email format');
      return;
    }
    // Clear error if basic format is valid
    setState(() => _emailError = null);
  }

  void _validatePhone(String value) {
    setState(() {
      if (value.trim().isNotEmpty) {
        if (!_isValidPhilippinesPhoneNumber(value.trim())) {
          _phoneError = 'Invalid phone number format';
        } else {
          _phoneError = null;
        }
      } else {
        _phoneError = null;
      }
    });
  }

  void _validatePassword(String value) {
    // Trigger form validation for confirm password when password changes
    if (_confirmPasswordController.text.isNotEmpty) {
      // Force validation of confirm password field
      _formKey.currentState?.validate();
    }
  }

  void _validateConfirmPassword(String value) {
    // Trigger form validation when confirm password changes
    _formKey.currentState?.validate();
  }

  void _setupVerificationListener() {
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      // Debug logs
      // print('🧪 Register: Auth change: $event, hasSession=${session != null}');

      if (session != null &&
          (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.userUpdated)) {
        final user = session.user;
        final confirmedAt = user.emailConfirmedAt;
        if (confirmedAt != null) {
          _onEmailConfirmed();
        }
      }
    });
  }

  void _onEmailConfirmed() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Email Confirmed!',
          style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Your email has been verified. You can now sign in.',
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.9),
            fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text(
              'Go to Login',
              style: TextStyle(
                color: mediumSeaGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Error',
          style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: const TextStyle(color: darkTeal)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: mediumSeaGreen)),
          ),
        ],
      ),
    );
  }

  Future<void> _signUp() async {
    // Clear any existing real-time validation errors
    setState(() {
      _fullNameError = null;
      _usernameError = null;
      _emailError = null;
      _phoneError = null;
    });

    // Basic form validation
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation
    if (_selectedBirthday == null) {
      _showErrorDialog('Please select your birthday');
      return;
    }

    // Use comprehensive security validation for all fields
    final fullNameError = InputSecurityService.validateSecureName(
      _fullNameController.text.trim(),
      'Full name',
    );
    if (fullNameError != null) {
      _showErrorDialog(fullNameError);
      return;
    }

    final usernameError = InputSecurityService.validateSecureUsername(
      _usernameController.text.trim(),
    );
    if (usernameError != null) {
      _showErrorDialog(usernameError);
      return;
    }

    final emailError = InputSecurityService.validateSecureEmail(
      _emailController.text.trim(),
    );
    if (emailError != null) {
      _showErrorDialog(emailError);
      return;
    }

    // Validate phone number if it's provided
    if (_phoneController.text.trim().isNotEmpty) {
      if (!_isValidPhilippinesPhoneNumber(_phoneController.text.trim())) {
        _showErrorDialog(
          'Invalid Philippines phone number!\n\n✅ Valid formats:\n• 09XXXXXXXXX (11 digits starting with 09)\n• +63 9XX XXX XXXX\n• 63 9XX XXX XXXX\n\n❌ Must start with 09 and be exactly 11 digits',
        );
        return;
      }
    }

    // Use comprehensive password validation
    final passwordError = InputSecurityService.validateSecurePassword(
      _passwordController.text.trim(),
    );
    if (passwordError != null) {
      _showErrorDialog(passwordError);
      return;
    }

    if (!_acceptTerms) {
      _showErrorDialog('Please accept the terms and privacy policy');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      bool success = await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _fullNameController.text.trim(),
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : _fullNameController.text.trim(),
        username: _usernameController.text.trim().toLowerCase(),
        phoneNumber: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        birthday: _selectedBirthday!.toIso8601String(),
      );

      if (success && mounted) {
        // Always show email verification dialog and redirect to login
        _showEmailVerificationDialog();
      } else if (mounted && authProvider.error != null) {
        _showErrorDialog(authProvider.error!);
      }
    } catch (e) {
      _showErrorDialog('An unexpected error occurred');
    }
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Email Verification Required',
          style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your account has been created successfully!',
              style: TextStyle(color: darkTeal, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Please check your email and click the verification link to activate your account.',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightMint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: paleGreen.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: mediumSeaGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You must verify your email before you can sign in to your account.',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
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
                border: Border.all(color: const Color(0xFFFFCC80), width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: const Color(0xFFE65100),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unverified accounts cannot access the app.',
                      style: TextStyle(
                        color: const Color(0xFFE65100),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: Text(
              'Go to Login',
              style: TextStyle(
                color: mediumSeaGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Stack(
              children: [
                // Background gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [lightMint, paleGreen],
                    ),
                  ),
                ),

                // Register element image - positioned at top
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    'assets/images/register_element.png',
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.contain,
                  ),
                ),

                // Main content container
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.75,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: _buildRegisterContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 20),

            // Form fields
            _buildFormFields(),
            const SizedBox(height: 18),

            // Terms and conditions
            _buildTermsAndConditions(),
            const SizedBox(height: 20),

            // Register button
            _buildRegisterButton(),
            const SizedBox(height: 16),

            // Login link
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: lightMint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: paleGreen.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.arrow_back, color: darkTeal, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Create Account',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Join us and start your job search journey',
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedBirthday ??
          DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: mediumSeaGreen,
              onPrimary: Colors.white,
              surface: lightMint,
              onSurface: darkTeal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
        _birthdayController.text =
            '${picked.month}/${picked.day}/${picked.year}';
      });
    }
  }

  Widget _buildBirthdayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Birthday *',
          style: TextStyle(
            color: darkTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _selectBirthday,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: lightMint.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: paleGreen.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.cake, color: mediumSeaGreen, size: 14),
                ),
                Expanded(
                  child: Text(
                    _birthdayController.text.isEmpty
                        ? 'Select your birthday'
                        : _birthdayController.text,
                    style: TextStyle(
                      color: _birthdayController.text.isEmpty
                          ? darkTeal.withValues(alpha: 0.5)
                          : darkTeal,
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: darkTeal.withValues(alpha: 0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Full Name
          _buildTextField(
            controller: _fullNameController,
            label: 'Full Name *',
            hint: 'Enter your full name (letters and spaces only)',
            icon: Icons.person_outline,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
              LengthLimitingTextInputFormatter(50),
            ],
            onChanged: _validateFullName,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Full name is required';
              }
              if (value.trim().length < 3) {
                return 'Full name must be at least 3 characters';
              }
              if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                return 'Full name can only contain letters and spaces';
              }
              return null;
            },
            errorText: _fullNameError,
          ),
          const SizedBox(height: 15),

          // Display Name
          _buildTextField(
            controller: _displayNameController,
            label: 'Display Name (Optional)',
            hint: 'Enter your display name',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 15),

          // Username
          _buildTextField(
            controller: _usernameController,
            label: 'Username *',
            hint:
                'Enter your username (3-20 chars, letters, numbers, underscore only)',
            icon: Icons.alternate_email,
            prefix: '@',
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
              LengthLimitingTextInputFormatter(20),
            ],
            onChanged: _validateUsername,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Username is required';
              }
              if (value.trim().length < 3) {
                return 'Username must be at least 3 characters';
              }
              if (value.trim().length > 20) {
                return 'Username must be no more than 20 characters';
              }
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                return 'Username can only contain letters, numbers, and underscores';
              }
              if (value.trim().startsWith('_') || value.trim().endsWith('_')) {
                return 'Username cannot start or end with underscore';
              }
              return null;
            },
            errorText: _usernameError,
          ),
          const SizedBox(height: 15),

          // Email
          _buildTextField(
            controller: _emailController,
            label: 'Email Address *',
            hint: 'Enter your email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            onChanged: _validateEmail,
            validator: (value) {
              // Use comprehensive security validation from InputSecurityService
              final emailError = InputSecurityService.validateSecureEmail(
                value,
              );
              if (emailError != null) {
                return emailError;
              }
              return null;
            },
            errorText: _emailError,
          ),
          const SizedBox(height: 15),

          // Phone Number
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number (Optional)',
            hint: 'Enter your Philippines phone number (09XXXXXXXXX)',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-\(\)]')),
              LengthLimitingTextInputFormatter(11),
            ],
            onChanged: (value) {
              _validateInput(value);
              _validatePhone(value);
            },
            errorText: _phoneError,
          ),
          const SizedBox(height: 15),

          // Birthday
          _buildBirthdayField(),
          const SizedBox(height: 15),

          // Password
          _buildTextField(
            controller: _passwordController,
            label: 'Password *',
            hint:
                'Enter your password (min 8, 1 upper, 1 lower, 1 number, 1 special)',
            icon: Icons.lock_outline,
            isPassword: true,
            isPasswordVisible: _isPasswordVisible,
            onTogglePassword: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
            onChanged: _validatePassword,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Password is required';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              if (!RegExp(r'[A-Z]').hasMatch(value)) {
                return 'Password must contain at least 1 uppercase letter';
              }
              if (!RegExp(r'[a-z]').hasMatch(value)) {
                return 'Password must contain at least 1 lowercase letter';
              }
              if (!RegExp(r'[0-9]').hasMatch(value)) {
                return 'Password must contain at least 1 number';
              }
              if (!RegExp(
                r'[!@#\$%\^&\*\(\)_\-\+=\[\]\{\}\|;:",\.<>\/\?~`]',
              ).hasMatch(value)) {
                return 'Password must contain at least 1 special character';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Confirm Password
          _buildTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password *',
            hint: 'Confirm your password',
            icon: Icons.lock_outline,
            isPassword: true,
            isPasswordVisible: _isConfirmPasswordVisible,
            onTogglePassword: () => setState(
              () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
            ),
            onChanged: _validateConfirmPassword,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    String? prefix,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
    String? Function(String?)? validator,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: darkTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword && !isPasswordVisible,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF013237), // darkTeal
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 11,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: mediumSeaGreen, size: 18),
            ),
            prefixText: prefix,
            prefixStyle: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: darkTeal.withValues(alpha: 0.6),
                    ),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: mediumSeaGreen, width: 2),
            ),
            filled: true,
            fillColor: lightMint.withValues(alpha: 0.3),
          ),
        ),
        // Valid phone number confirmation (only for phone fields)
        if (onChanged != null &&
            controller == _phoneController &&
            _isPhoneNumber &&
            _formattedPhoneNumber.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: mediumSeaGreen, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Valid: $_formattedPhoneNumber',
                  style: TextStyle(
                    color: mediumSeaGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        // Error text display (only show if there's an error)
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: const TextStyle(
              color: Color(0xFFF44336), // Error red color
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTermsAndConditions() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _acceptTerms = !_acceptTerms),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _acceptTerms ? mediumSeaGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _acceptTerms
                    ? mediumSeaGreen
                    : paleGreen.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: _acceptTerms
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 11,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsOfServiceScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Terms of Service',
                      style: TextStyle(
                        fontSize: 11,
                        color: mediumSeaGreen,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' and '),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 11,
                        color: mediumSeaGreen,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: authProvider.isLoading ? null : _signUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: mediumSeaGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadowColor: mediumSeaGreen.withValues(alpha: 0.3),
            ),
            child: authProvider.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'Sign in',
              style: TextStyle(
                color: mediumSeaGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
