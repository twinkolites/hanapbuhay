import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/stay_signed_in_service.dart';
import '../main.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'applicant/home_screen.dart';
import 'employer/home_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'employer/employer_registration_screen.dart';
import 'employer/employer_application_status_screen.dart';
import 'employer/email_verification_blocked_screen.dart';
import '../services/input_security_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _isPasswordVisible = false;
  bool _isCheckingSession = true;
  bool _staySignedIn = true;

  // Error messages for real-time validation
  String? _emailError;
  String? _passwordError;

  late AnimationController _animationController;

  /// Real-time email validation for UX (basic checks only)
  void _validateEmail(String value) {
    if (value.isEmpty) {
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

  /// Real-time password validation for UX (basic checks only)
  void _validatePassword(String value) {
    if (value.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      return;
    }

    // Basic length check for real-time feedback
    if (value.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
      return;
    }

    // Clear error if basic requirements are met
    setState(() => _passwordError = null);
  }

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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

    // Load stay signed in preference and check session
    _initializeSession();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Initialize session and load preferences
  Future<void> _initializeSession() async {
    try {
      // Load stay signed in preference
      final shouldStaySignedIn = await StaySignedInService.shouldStaySignedIn();
      if (mounted) {
        setState(() {
          _staySignedIn = shouldStaySignedIn;
        });
      }
      
      // Check if we have a valid session based on user preference
      final hasValidSession = await StaySignedInService.validateSessionOnStartup();
      
      if (hasValidSession) {
        // User has a valid session and wants to stay signed in
        await _checkUserRoleAndNavigate();
      } else {
        // No valid session, user needs to log in
        if (mounted) {
          setState(() {
            _isCheckingSession = false;
          });
        }
      }
    } catch (e) {
      print('Session initialization error: $e');
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    }
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
            fontSize: 14,
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

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Clear any existing real-time validation errors
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    // Use secure email validation (comprehensive security checks)
    final emailError = InputSecurityService.validateSecureEmail(email);
    if (emailError != null) {
      _showErrorDialog(emailError);
      return;
    }

    // Validate password format (comprehensive security checks)
    final passwordError = InputSecurityService.validateSecurePassword(password);
    if (passwordError != null) {
      _showErrorDialog(passwordError);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      bool success = await authProvider.signInWithEmail(
        email: email,
        password: password,
      );

      if (success && mounted) {
        // Check if email is verified
        final user = supabase.auth.currentUser;
        if (user != null && user.emailConfirmedAt == null) {
          _showEmailNotVerifiedDialog();
          return;
        }

        // Add a small delay to ensure any pending animations complete
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Check user role and handle employer approval workflow
        await _checkUserRoleAndNavigate();
      } else if (mounted && authProvider.error != null) {
        _showErrorDialog(authProvider.error!);
      }
    } catch (e) {
      _showErrorDialog('An unexpected error occurred');
    }
  }

  void _showEmailNotVerifiedDialog() {
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2), width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: const Color(0xFFF44336),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Access Denied: Email not verified',
                      style: TextStyle(
                        color: const Color(0xFFF44336),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your email address has not been verified. You must verify your email before you can access the app.',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: mediumSeaGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'What to do:',
                          style: TextStyle(
                            color: darkTeal,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Check your email inbox (and spam folder)\n2. Click the verification link in the email\n3. Return here and try signing in again',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.8),
                      fontSize: 12,
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
                      'Unverified accounts cannot access any features.',
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
              // Sign out the user since they can't proceed without verification
              supabase.auth.signOut();
            },
            child: Text(
              'I Understand',
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


  // Check user role and handle employer approval workflow
  Future<void> _checkUserRoleAndNavigate() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showErrorDialog('No user found after login.');
        return;
      }
      
      // First check if email is verified
      if (user.emailConfirmedAt == null) {
        debugPrint('📧 Email not verified for user: ${user.email}');
        // Navigate to email verification blocked screen
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationBlockedScreen(email: user.email ?? ''),
          ),
        );
        return;
      }
      
      debugPrint('✅ Email verified for user: ${user.email}');
      
      // Get user profile and verification status
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      
      final role = profile != null && profile['role'] != null
          ? profile['role'] as String
          : 'applicant';
      
      // Add a small delay to prevent animation conflicts
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (!mounted) return;
      
      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else if (role == 'employer') {
        // Check employer verification status
        await _checkEmployerApprovalStatus(user.id);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in _checkUserRoleAndNavigate: $e');
      _showErrorDialog('Failed to check user role. Defaulting to applicant.');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  // Check employer approval status and handle accordingly
  Future<void> _checkEmployerApprovalStatus(String userId) async {
    try {
      // Check employer verification status
      final verification = await supabase
          .from('employer_verification')
          .select('verification_status, rejection_reason, admin_notes')
          .eq('employer_id', userId)
          .maybeSingle();
      
      if (verification == null) {
        // No verification record found - navigate to status screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const EmployerApplicationStatusScreen()),
        );
        return;
      }
      
      final status = verification['verification_status'] as String?;
      
      switch (status) {
        case 'approved':
          // Navigate to employer dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EmployerHomeScreen()),
          );
          break;
        case 'pending':
        case 'rejected':
        default:
          // Navigate to employer application status screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EmployerApplicationStatusScreen()),
          );
          break;
      }
    } catch (e) {
      _showErrorDialog('Failed to check employer approval status.');
    }
  }

  Widget _buildCreateAccountLink() {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  );
                },
                child: Text(
                  'Create account',
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Are you an employer? ",
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EmployerRegistrationScreen()),
                  );
                },
                child: Text(
                  'Register as Employer',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking session
    if (_isCheckingSession) {
      return Scaffold(
        backgroundColor: lightMint,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: mediumSeaGreen,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.business_center,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Hanap Buhay',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Checking your session...',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: mediumSeaGreen,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

                // Login element image - positioned at top
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Image.asset(
                    'assets/images/login_element.png',
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
                    height: MediaQuery.of(context).size.height * 0.65,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: _buildLoginContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome text
            const Text(
              'Welcome Back!',
              style: TextStyle(
                color: darkTeal,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sign in to continue your job search',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 20),

            // Login form
            _buildLoginForm(),
            const SizedBox(height: 15),

            // Options row: Stay signed in (left) + Forgot password (right)
            _buildOptionsRow(),
            const SizedBox(height: 15),

            // Login button
            _buildLoginButton(),
            const SizedBox(height: 20),


            // Create account link
            _buildCreateAccountLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        // Email field
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Enter your email address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          onChanged: _validateEmail,
          errorText: _emailError,
        ),
        const SizedBox(height: 15),

        // Password field
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          isPassword: true,
          isPasswordVisible: _isPasswordVisible,
          onTogglePassword: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
          onChanged: _validatePassword,
          errorText: _passwordError,
        ),
      ],
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
    Function(String)? onChanged,
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
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword && !isPasswordVisible,
          keyboardType: keyboardType,
          onChanged: onChanged,
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
              height: 16,
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: mediumSeaGreen, size: 12),
            ),

            suffixIcon: isPassword
                ? IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: darkTeal.withValues(alpha: 0.6),
                      size: 16,
                    ),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
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

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ForgotPasswordScreen(),
            ),
          );
        },
        child: Text(
          'Forgot password?',
          style: TextStyle(
            color: mediumSeaGreen,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Checkbox(
              value: _staySignedIn,
              activeColor: mediumSeaGreen,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              onChanged: (value) async {
                setState(() {
                  _staySignedIn = value ?? false;
                });
                
                // Save the preference using the service
                await StaySignedInService.saveStaySignedInPreference(_staySignedIn);
                
                // If user unchecks "Stay Signed In", immediately sign out
                if (!_staySignedIn) {
                  await supabase.auth.signOut();
                  await StaySignedInService.clearSessionData();
                }
              },
            ),
            const SizedBox(width: 6),
            Text(
              'Stay signed in',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        _buildForgotPassword(),
      ],
    );
  }

  Widget _buildLoginButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: authProvider.isLoading ? null : _signIn,
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
                    'Sign In',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
          ),
        );
      },
    );
  }

}
