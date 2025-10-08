import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/employer_registration_data.dart';
import '../../services/employer_registration_service.dart';
import '../../utils/safe_snackbar.dart';
import 'employer_registration_personal_info_screen.dart';
import 'employer_registration_company_info_screen.dart';
import 'employer_registration_business_info_screen.dart';
import 'employer_registration_documents_screen.dart';
import 'employer_registration_review_screen.dart';
import '../login_screen.dart';

class EmployerRegistrationScreen extends StatefulWidget {
  const EmployerRegistrationScreen({super.key});

  @override
  State<EmployerRegistrationScreen> createState() => _EmployerRegistrationScreenState();
}

class _EmployerRegistrationScreenState extends State<EmployerRegistrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Registration data
  EmployerRegistrationData _registrationData = EmployerRegistrationData(
    fullName: '',
    email: '',
    password: '',
    companyName: '',
    companyAbout: '',
    businessAddress: '',
    city: '',
    province: '',
    postalCode: '',
    country: 'Philippines',
    industry: '',
    companySize: '',
    businessType: '',
    contactPersonName: '',
    contactPersonPosition: '',
    contactPersonEmail: '',
  );

  int _currentStep = 0;
  bool _isLoading = false;
  bool _isEmailVerified = false;
  String? _verificationEmail;
  Timer? _verificationCheckTimer;
  StreamSubscription<AuthState>? _authSubscription;

  // Color palette
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Personal Information',
      'subtitle': 'Tell us about yourself',
      'icon': Icons.person,
    },
    {
      'title': 'Company Information',
      'subtitle': 'Basic company details',
      'icon': Icons.business,
    },
    {
      'title': 'Business Details',
      'subtitle': 'Location and industry info',
      'icon': Icons.location_on,
    },
    {
      'title': 'Documents',
      'subtitle': 'Upload verification documents',
      'icon': Icons.description,
    },
    {
      'title': 'Review & Submit',
      'subtitle': 'Review your information',
      'icon': Icons.check_circle,
    },
  ];

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _animationController.forward();
    
    // Check for pending registration data and restore it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRestorePendingData();
      _checkEmailVerification();
      _startEmailVerificationListener();
    });

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((AuthState data) {
      final session = data.session;
      final user = session?.user;

      if (user != null && user.emailConfirmedAt != null) {
        _handleEmailVerificationSuccess(user.email);
      }

      if (data.event == AuthChangeEvent.signedOut) {
        _stopEmailVerificationListener();
        if (mounted) {
          setState(() {
            _isEmailVerified = false;
            _verificationEmail = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _verificationCheckTimer?.cancel();
    _authSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _updateRegistrationData(EmployerRegistrationData newData) {
    setState(() {
      _registrationData = newData;
      // If email changed, reset verification status
      if (_verificationEmail != newData.email) {
        _isEmailVerified = false;
        _verificationEmail = newData.email;
        if (newData.email.isNotEmpty) {
          _startEmailVerificationListener();
        } else {
          _stopEmailVerificationListener();
        }
      }
    });
  }


  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.email, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Verify Your Email'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('We\'ve sent a verification link to:'),
              const SizedBox(height: 8),
              Text(
                _registrationData.email,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please check your email and click the verification link to complete your employer account setup.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Your registration data has been saved securely. Email verification will complete your account setup.',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'If the link expires or doesn\'t work, you can request a new verification email.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
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
                Navigator.of(context).pop();
                // Navigate to login screen after email verification
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Go to Login'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resendVerificationEmail();
              },
              child: const Text('Resend Email'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resendVerificationEmail() async {
    try {
      final supabase = Supabase.instance.client;
      final normalizedEmail = _registrationData.email.trim().toLowerCase();
      final emailRedirectUrl = 'https://twinkolites.github.io/hanapbuhay/?email=${Uri.encodeComponent(normalizedEmail)}&registration_type=employer';
      
      // Ensure data is stored before resending
      await _storeRegistrationDataTemporarily();
      
      await supabase.auth.resend(
        type: OtpType.signup,
        email: normalizedEmail,
        emailRedirectTo: emailRedirectUrl,
      );
      
      SafeSnackBar.showSuccess(
        context,
        message: 'New verification email sent! Please check your inbox and spam folder.',
      );
      
      // Restart verification listener
      _startEmailVerificationListener();
      
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Failed to resend verification email: ${e.toString()}',
      );
    }
  }

  Future<void> _checkEmailVerification() async {
    // Check if user is authenticated and email is confirmed
    final authClient = Supabase.instance.client.auth;
    final currentSession = authClient.currentSession;

    if (currentSession == null) {
      // No session yet (user hasn't logged in after signup). Avoid calling getUser which throws.
      debugPrint('ℹ️ Skipping verification check - no active auth session. Waiting for sign-in or deep link.');
      return;
    }

    try {
      final response = await authClient.getUser();
      final user = response.user;

      if (user != null && user.emailConfirmedAt != null && !_isEmailVerified) {
        _handleEmailVerificationSuccess(user.email);
      }
    } catch (error) {
      // Silently ignore fetch errors (network/offline)
      debugPrint('⚠️ Email verification check failed: $error');
    }
  }

  void _startEmailVerificationListener() {
    if (_isEmailVerified) {
      return;
    }

    _verificationCheckTimer?.cancel();
    _verificationCheckTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_isEmailVerified) {
        _checkEmailVerification();
      } else {
        _verificationCheckTimer?.cancel();
      }
    });

    // Kick off an immediate check so the first update isn't delayed
    _checkEmailVerification();
    
    // Set a timeout to detect failed verification attempts
    Timer(const Duration(minutes: 5), () {
      if (!_isEmailVerified && mounted) {
        debugPrint('⏰ Email verification timeout - showing failure dialog');
        _handleEmailVerificationFailure();
      }
    });
  }

  void _stopEmailVerificationListener() {
    _verificationCheckTimer?.cancel();
    _verificationCheckTimer = null;
  }

  void _handleEmailVerificationFailure() {
    // Show dialog with options for failed verification
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Verification Failed'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your email verification failed. This could happen if:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text('• The verification link expired'),
              const Text('• The link was already used'),
              const Text('• There was a network issue'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Your registration data is saved. You can request a new verification email.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
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
                Navigator.of(context).pop();
                _clearPendingData();
              },
              child: const Text('Start Fresh'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to login screen
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Go to Login'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resendVerificationEmail();
              },
              child: const Text('Resend Email'),
            ),
          ],
        );
      },
    );
  }

  void _handleEmailVerificationSuccess(String? email) async {
    _stopEmailVerificationListener();

    if (!mounted || _isEmailVerified) {
      return;
    }

    setState(() {
      _isEmailVerified = true;
      _verificationEmail = email ?? _verificationEmail;
    });

    // Insert registration data into schema AFTER email confirmation
    try {
      // First, try to recover data from temporary storage
      await _recoverRegistrationDataFromStorage();
      
      // Then store the data permanently
      await _storeRegistrationData();
      
      // Clean up temporary storage
      await _cleanupTemporaryStorage();
      
      SafeSnackBar.showSuccess(
        context,
        message: 'Email verified successfully! Your employer account is now complete.',
      );
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Email verified but failed to complete registration: ${e.toString()}',
      );
    }

    // Navigate to login screen after successful verification
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    });
  }

  Future<void> _checkAndRestorePendingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedData = prefs.getString('pending_employer_registration');
      final storedEmail = prefs.getString('pending_employer_email');
      
      if (storedData != null && storedEmail != null) {
        final dataMap = jsonDecode(storedData) as Map<String, dynamic>;
        final restoredData = EmployerRegistrationData.fromJson(dataMap);
        
        // Only restore if the email matches and data is not empty
        if (restoredData.email.isNotEmpty && restoredData.email == storedEmail) {
          setState(() {
            _registrationData = restoredData;
            _verificationEmail = storedEmail;
          });
          
          debugPrint('🔄 Restored pending registration data for: ${storedEmail}');
          
          // Show restoration notification
          SafeSnackBar.showInfo(
            context,
            message: 'Your registration data has been restored. You can continue from where you left off.',
          );
          
          // Check if user is already verified
          await _checkEmailVerification();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to check/restore pending data: $e');
    }
  }

  Future<void> _recoverRegistrationDataFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedData = prefs.getString('pending_employer_registration');
      
      if (storedData != null) {
        final dataMap = jsonDecode(storedData) as Map<String, dynamic>;
        _registrationData = EmployerRegistrationData.fromJson(dataMap);
        debugPrint('🔄 Recovered registration data from storage');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to recover registration data: $e');
    }
  }

  Future<void> _cleanupTemporaryStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_employer_registration');
      await prefs.remove('pending_employer_email');
      debugPrint('🧹 Cleaned up temporary storage');
    } catch (e) {
      debugPrint('⚠️ Failed to cleanup temporary storage: $e');
    }
  }

  Future<void> _clearPendingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_employer_registration');
      await prefs.remove('pending_employer_email');
      
      // Reset registration data
      setState(() {
        _registrationData = EmployerRegistrationData(
          fullName: '',
          email: '',
          password: '',
          companyName: '',
          companyAbout: '',
          businessAddress: '',
          city: '',
          province: '',
          postalCode: '',
          country: 'Philippines',
          industry: '',
          companySize: '',
          businessType: '',
          contactPersonName: '',
          contactPersonPosition: '',
          contactPersonEmail: '',
        );
        _isEmailVerified = false;
        _verificationEmail = null;
        _currentStep = 0;
      });
      
      debugPrint('🗑️ Cleared all pending registration data');
      
      SafeSnackBar.showSuccess(
        context,
        message: 'Registration data cleared. You can start fresh.',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to clear pending data: $e');
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      // Add a small delay to prevent animation conflicts
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _currentStep++;
          });
        }
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      // Add a small delay to prevent animation conflicts
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _currentStep--;
          });
        }
      });
    }
  }

  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);

    try {
      // First, create the user account and send email verification
      await _createAccountAndSendVerification();
      
      // Show email verification dialog
      _showEmailVerificationDialog();
      
      // Start listening for email verification
      _startEmailVerificationListener();
      
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Failed to create account: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createAccountAndSendVerification() async {
    final supabase = Supabase.instance.client;
    final normalizedEmail = _registrationData.email.trim().toLowerCase();
    
    // Use proper callback URL as per web best practices
    final callbackUrl = 'io.supabase.hanapbuhay://login-callback';
    final emailRedirectUrl = 'https://twinkolites.github.io/hanapbuhay/?email=${Uri.encodeComponent(normalizedEmail)}&registration_type=employer';
    
    try {
      // Store registration data temporarily for persistence during verification
      await _storeRegistrationDataTemporarily();
      
      // Try to sign up the user with proper callback URL
      await supabase.auth.signUp(
        email: normalizedEmail,
        password: _registrationData.password.isNotEmpty 
            ? _registrationData.password 
            : 'temp_${DateTime.now().millisecondsSinceEpoch}',
        emailRedirectTo: emailRedirectUrl,
        data: {
          'registration_type': 'employer',
          'callback_url': callbackUrl,
          'role': 'employer', // Store role in user metadata
        },
      );
      
    } on AuthException catch (e) {
      // If user already exists, use resend method
      if (e.message.contains('already registered') || 
          e.message.contains('User already registered')) {
        
        // Use the proper resend method for existing users
        await supabase.auth.resend(
          type: OtpType.signup,
          email: normalizedEmail,
          emailRedirectTo: emailRedirectUrl,
        );
      } else {
        throw e; // Re-throw if it's a different error
      }
    }
  }

  Future<void> _storeRegistrationDataTemporarily() async {
    // Store registration data in SharedPreferences for persistence during verification
    try {
      final prefs = await SharedPreferences.getInstance();
      final registrationJson = jsonEncode(_registrationData.toJson());
      await prefs.setString('pending_employer_registration', registrationJson);
      await prefs.setString('pending_employer_email', _registrationData.email);
      debugPrint('💾 Stored registration data temporarily for persistence');
    } catch (e) {
      debugPrint('⚠️ Failed to store registration data temporarily: $e');
    }
  }

  Future<void> _storeRegistrationData() async {
    // Store registration data in SharedPreferences or similar
    // This will be used after email verification to complete the registration
    // For now, we'll use a simple approach with the existing service
    
    try {
      // Call the registration service to store the data
      final result = await EmployerRegistrationService.registerEmployer(
        registrationData: _registrationData,
      );
      
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Failed to store registration data');
      }
      
    } catch (e) {
      // If storing fails, we still want to send the email verification
      // The user can complete registration after email verification
      debugPrint('Warning: Failed to store registration data: $e');
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
            children: _steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive || isCompleted
                            ? mediumSeaGreen
                            : Colors.grey.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCompleted ? Icons.check : step['icon'],
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    if (index < _steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? mediumSeaGreen
                                : Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return EmployerRegistrationPersonalInfoScreen(
          registrationData: _registrationData,
          onDataChanged: _updateRegistrationData,
          onNext: _nextStep,
        );
      case 1:
        return EmployerRegistrationCompanyInfoScreen(
          registrationData: _registrationData,
          onDataChanged: _updateRegistrationData,
          onNext: _nextStep,
          onPrevious: _previousStep,
        );
      case 2:
        return EmployerRegistrationBusinessInfoScreen(
          registrationData: _registrationData,
          onDataChanged: _updateRegistrationData,
          onNext: _nextStep,
          onPrevious: _previousStep,
        );
      case 3:
        return EmployerRegistrationDocumentsScreen(
          registrationData: _registrationData,
          onDataChanged: _updateRegistrationData,
          onNext: _nextStep,
          onPrevious: _previousStep,
        );
      case 4:
        return EmployerRegistrationReviewScreen(
          registrationData: _registrationData,
          onSubmit: _submitRegistration,
          onPrevious: _previousStep,
          isLoading: _isLoading,
        );
      default:
        return const SizedBox.shrink();
    }
  }


  @override
  Widget build(BuildContext context) {
    // Periodically check email verification status
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isEmailVerified) {
        _checkEmailVerification();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: darkTeal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Employer Registration',
          style: TextStyle(
            color: darkTeal,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Step indicator
              _buildStepIndicator(),
              
              // Step content
              Expanded(
                child: _buildStepContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
