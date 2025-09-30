import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import 'reset_password_screen.dart';
import '../main.dart';
import '../services/input_security_service.dart';
import 'dart:async';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isEmailSent = false;
  StreamSubscription? _authSubscription;

  // Countdown timer for resend email
  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  bool _canResend = true;

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

    // Set up token checker
    _setupTokenChecker();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _authSubscription?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _setupTokenChecker() {
    // Auth state changes are handled in main.dart for magic link flow
    // When user clicks the link, main.dart handles navigation
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Error',
          style: TextStyle(
            color: darkTeal,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(color: darkTeal, fontSize: 11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: mediumSeaGreen, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _startCountdown() {
    _countdownSeconds = 60; // 60 seconds countdown
    _canResend = false;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdownSeconds > 0) {
            _countdownSeconds--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      _showErrorDialog('Please enter the OTP');
      return;
    }

    if (otp.length < 6) {
      _showErrorDialog('OTP must be at least 6 characters');
      return;
    }

    // Maximum suspicious pattern detection for OTP
    final otpSuspiciousCheck = InputSecurityService.detectSuspiciousPatterns(
      otp,
      'OTP',
    );
    if (otpSuspiciousCheck != null) {
      _showErrorDialog(otpSuspiciousCheck);
      return;
    }

    setState(() {
      // We'll use the existing loading state from the button
    });

    try {
      final response = await supabase.auth.verifyOTP(
        type: OtpType.recovery,
        token: otp,
        email: _emailController.text.trim(),
      );

      if (response.session != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('OTP verified successfully!'),
            backgroundColor: mediumSeaGreen,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to reset password screen with session
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ResetPasswordScreen(
                  accessToken: response.session!.accessToken,
                  refreshToken: response.session!.refreshToken ?? '',
                ),
              ),
            );
          }
        });
      } else {
        _showErrorDialog('Invalid OTP. Please try again.');
      }
    } catch (e) {
      if (e is AuthException) {
        _showErrorDialog(e.message);
      } else {
        _showErrorDialog('Failed to verify OTP. Please try again.');
      }
    }
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    // Use secure email validation
    final emailError = InputSecurityService.validateSecureEmail(email);
    if (emailError != null) {
      _showErrorDialog(emailError);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      bool success = await authProvider.resetPassword(email);

      if (success && mounted) {
        setState(() {
          _isEmailSent = true;
        });

        // Start countdown timer
        _startCountdown();
      } else if (mounted && authProvider.error != null) {
        _showErrorDialog(authProvider.error!);
      }
    } catch (e) {
      _showErrorDialog('Failed to send reset email. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: darkTeal.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back_ios_new, color: darkTeal, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _isEmailSent ? _buildSuccessContent() : _buildResetContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildResetContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Icon
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(Icons.lock_reset, size: 32, color: mediumSeaGreen),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Center(
              child: Text(
                'Forgot Password?',
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
                'Enter your email address and we\'ll send you an OTP to reset your password.',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Email field
            _buildEmailField(),
            const SizedBox(height: 24),

            // Send reset button
            _buildSendResetButton(),
            const SizedBox(height: 24),

            // Back to login
            _buildBackToLogin(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Icon
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  Icons.email_outlined,
                  size: 32,
                  color: mediumSeaGreen,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Center(
              child: Text(
                'Check Your Email',
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
                'We\'ve sent a One-Time Password (OTP) to',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            // Email display
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: lightMint.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: paleGreen.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _emailController.text.trim(),
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // OTP Input Field
            _buildOtpField(),
            const SizedBox(height: 20),

            // Verify OTP Button
            _buildVerifyOtpButton(),
            const SizedBox(height: 20),

            // Resend email button
            _buildResendButton(),
            const SizedBox(height: 16),

            // Countdown progress indicator
            if (!_canResend) ...[
              Container(
                width: double.infinity,
                height: 3,
                decoration: BoxDecoration(
                  color: lightMint.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _countdownSeconds / 60.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: mediumSeaGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please wait before requesting another email',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],

            // Back to login
            _buildBackToLogin(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Address',
          style: TextStyle(
            color: darkTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Enter your email address',
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
              child: Icon(
                Icons.email_outlined,
                color: mediumSeaGreen,
                size: 12,
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

  Widget _buildSendResetButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: authProvider.isLoading ? null : _sendResetEmail,
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
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Send OTP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildResendButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton(
            onPressed: (authProvider.isLoading || !_canResend)
                ? null
                : _sendResetEmail,
            style: OutlinedButton.styleFrom(
              foregroundColor: _canResend
                  ? mediumSeaGreen
                  : darkTeal.withValues(alpha: 0.4),
              side: BorderSide(
                color: _canResend
                    ? mediumSeaGreen
                    : darkTeal.withValues(alpha: 0.2),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: authProvider.isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: mediumSeaGreen,
                      strokeWidth: 2,
                    ),
                  )
                : !_canResend
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: darkTeal.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Resend in ${_countdownSeconds}s',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: darkTeal.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Resend OTP',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildOtpField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'One-Time Password (OTP)',
          style: TextStyle(
            color: darkTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          ),
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: TextStyle(
              color: darkTeal.withValues(alpha: 0.3),
              fontSize: 18,
              letterSpacing: 3,
            ),
            prefixIcon: Container(
              height: 16,
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.security, color: mediumSeaGreen, size: 12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
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
        const SizedBox(height: 6),
        Text(
          'Enter the 6-digit code sent to your email',
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyOtpButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: authProvider.isLoading ? null : _verifyOtp,
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
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Verify OTP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildBackToLogin() {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_ios, size: 14, color: mediumSeaGreen),
            const SizedBox(width: 4),
            Text(
              'Back to Login',
              style: TextStyle(
                color: mediumSeaGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
