import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'login_screen.dart';
import '../services/input_security_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const ResetPasswordScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _birthdayController = TextEditingController();
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  DateTime? _selectedBirthday;

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
  }

  @override
  void dispose() {
    // Clear session when leaving reset password screen for security
    _clearSession();
    _animationController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  /// Clear the session when user leaves the reset password screen
  Future<void> _clearSession() async {
    try {
      // Sign out to clear any temporary session
      await supabase.auth.signOut();
    } catch (e) {
      // Silently handle session cleanup errors to avoid disrupting navigation
      print('Session cleanup warning: $e');
    }
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
            onPressed: () {
              Navigator.pop(context);
              if (message.contains('Invalid or expired')) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text('OK', style: TextStyle(color: mediumSeaGreen)),
          ),
        ],
      ),
    );
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 6570),
      ), // 18 years ago
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

  Future<bool> _verifyBirthday() async {
    if (_selectedBirthday == null) return false;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      final response = await supabase
          .from('profiles')
          .select('birthday')
          .eq('id', user.id)
          .single();

      final storedBirthday = response['birthday'] as String?;
      if (storedBirthday == null) {
        _showErrorDialog(
          'Birthday not found in your profile. Please contact support.',
        );
        return false;
      }

      final storedDate = DateTime.parse(storedBirthday);
      final selectedDate = _selectedBirthday!;

      return storedDate.year == selectedDate.year &&
          storedDate.month == selectedDate.month &&
          storedDate.day == selectedDate.day;
    } catch (e) {
      print('Error verifying birthday: $e');
      _showErrorDialog('Error verifying birthday. Please try again.');
      return false;
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: mediumSeaGreen, size: 28),
            const SizedBox(width: 8),
            const Text(
              'Success!',
              style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Your password has been successfully reset. For security reasons, you have been signed out. Please log in again with your new password.',
          style: TextStyle(color: darkTeal),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
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

  void _handleCancelReset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Password Reset?',
          style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel the password reset process? You will need to request a new reset link if you change your mind.',
          style: TextStyle(color: darkTeal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog
            child: Text(
              'Continue Reset',
              style: TextStyle(color: mediumSeaGreen),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Cancel Reset',
              style: TextStyle(color: Color(0xFFF44336)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword() async {
    // First verify birthday for security
    final birthdayVerified = await _verifyBirthday();
    if (!birthdayVerified) {
      _showErrorDialog(
        'Incorrect birthday. Please enter your correct date of birth.',
      );
      return;
    }

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    // Use secure password validation
    final passwordError = InputSecurityService.validateSecurePassword(
      newPassword,
    );
    if (passwordError != null) {
      _showErrorDialog(passwordError);
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorDialog('Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Update the user's password
      await supabase.auth.updateUser(UserAttributes(password: newPassword));

      // Sign out the user to force re-login
      await supabase.auth.signOut();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (e is AuthException) {
        _showErrorDialog(e.message);
      } else {
        _showErrorDialog('Failed to reset password. Please try again.');
      }
    }
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
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Icon
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(Icons.lock_reset, size: 30, color: mediumSeaGreen),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Center(
              child: Text(
                'Reset Your Password',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Center(
              child: Text(
                'For security, please verify your birthday and enter a new password.',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 25),

            // Birthday verification field
            _buildBirthdayField(),
            const SizedBox(height: 18),

            // Password requirements
            _buildPasswordRequirements(),
            const SizedBox(height: 18),

            // New password field
            _buildPasswordField(
              controller: _newPasswordController,
              label: 'New Password',
              hint: 'Enter your new password',
              isVisible: _isNewPasswordVisible,
              onToggle: () => setState(
                () => _isNewPasswordVisible = !_isNewPasswordVisible,
              ),
            ),
            const SizedBox(height: 15),

            // Confirm password field
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm New Password',
              hint: 'Confirm your new password',
              isVisible: _isConfirmPasswordVisible,
              onToggle: () => setState(
                () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
              ),
            ),
            const SizedBox(height: 25),

            // Reset password button
            _buildResetButton(),

            const SizedBox(height: 20),

            // Back to login
            _buildBackToLogin(),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthdayField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Birthday Verification',
          style: TextStyle(
            color: darkTeal,
            fontSize: 12,
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: paleGreen.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: mediumSeaGreen, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedBirthday != null
                        ? '${_selectedBirthday!.month}/${_selectedBirthday!.day}/${_selectedBirthday!.year}'
                        : 'Select your birthday',
                    style: TextStyle(
                      color: _selectedBirthday != null
                          ? darkTeal
                          : darkTeal.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: darkTeal.withValues(alpha: 0.6),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter your date of birth for security verification',
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    final newPassword = _newPasswordController.text;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightMint.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: paleGreen.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements:',
            style: TextStyle(
              color: darkTeal,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _buildRequirement('At least 8 characters', newPassword.length >= 8),
          _buildRequirement(
            'One uppercase letter',
            newPassword.contains(RegExp(r'[A-Z]')),
          ),
          _buildRequirement(
            'One lowercase letter',
            newPassword.contains(RegExp(r'[a-z]')),
          ),
          _buildRequirement(
            'One number',
            newPassword.contains(RegExp(r'[0-9]')),
          ),
          _buildRequirement(
            'One special character',
            '!@#\$%^&*()_+-=[]{}|;:,.<>?'
                .split('')
                .any((char) => newPassword.contains(char)),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 12,
            color: isMet ? mediumSeaGreen : darkTeal.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: isMet ? mediumSeaGreen : darkTeal.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isVisible,
    required VoidCallback onToggle,
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
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: !isVisible,
          onChanged: (_) => setState(() {}), // Refresh password requirements
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 11,
            ),
            prefixIcon: Container(
              height: 16,
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.lock_outline, color: mediumSeaGreen, size: 12),
            ),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: darkTeal.withValues(alpha: 0.6),
                size: 16,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.5),
                width: 1.5,
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
      ],
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _resetPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: mediumSeaGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: mediumSeaGreen.withValues(alpha: 0.3),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Reset Password',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBackToLogin() {
    return Center(
      child: TextButton(
        onPressed: _handleCancelReset,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, size: 14, color: const Color(0xFFF44336)),
            const SizedBox(width: 4),
            Text(
              'Cancel Reset',
              style: TextStyle(
                color: const Color(0xFFF44336),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
