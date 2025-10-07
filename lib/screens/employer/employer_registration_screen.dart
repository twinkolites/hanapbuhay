import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    
    // Check email verification status on app resume
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEmailVerification();
    });
  }

  @override
  void dispose() {
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
      }
    });
  }

  Future<void> _verifyEmail() async {
    if (_registrationData.email.isEmpty) {
      SafeSnackBar.showError(
        context,
        message: 'Please enter your email address first.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First, try to sign up the user to create an account
      final supabase = Supabase.instance.client;
      
      try {
        await supabase.auth.signUp(
          email: _registrationData.email,
          password: _registrationData.password.isNotEmpty 
              ? _registrationData.password 
              : 'temp_${DateTime.now().millisecondsSinceEpoch}',
          emailRedirectTo: 'https://twinkolites.github.io/hanapbuhay/',
        );
        
        _showEmailVerificationDialog();
        setState(() => _isLoading = false);
      } on AuthException catch (e) {
        // If user already exists, use resend method
        if (e.message.contains('already registered') || 
            e.message.contains('User already registered')) {
          
          // Use the proper resend method for existing users
          await supabase.auth.resend(
            type: OtpType.signup,
            email: _registrationData.email,
            emailRedirectTo: 'https://twinkolites.github.io/hanapbuhay/',
          );
          
          _showEmailVerificationDialog();
          setState(() => _isLoading = false);
        } else {
          throw e; // Re-throw if it's a different error
        }
      }
    } on AuthException catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Error sending verification email: ${e.message}',
      );
      setState(() => _isLoading = false);
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Error sending verification email. Please try again.',
      );
      setState(() => _isLoading = false);
    }
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
                'Please check your email and click the verification link to continue with your registration.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You cannot proceed without email verification.',
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
              },
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _verifyEmail();
              },
              child: const Text('Resend Email'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkEmailVerification() async {
    // Check if user is authenticated and email is confirmed
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.emailConfirmedAt != null && !_isEmailVerified) {
      setState(() {
        _isEmailVerified = true;
        _verificationEmail = user.email;
      });
      
      if (mounted) {
        SafeSnackBar.showSuccess(
          context,
          message: 'Email verified successfully! You can now proceed.',
        );
      }
    }
  }

  void _nextStep() {
    // Check if email verification is required when moving from step 0 (personal info)
    if (_currentStep == 0 && !_isEmailVerified) {
      _verifyEmail();
      return;
    }

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
    // Ensure email is verified before submission
    if (!_isEmailVerified) {
      SafeSnackBar.showError(
        context,
        message: 'Please verify your email address before submitting.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await EmployerRegistrationService.registerEmployer(
        registrationData: _registrationData,
      );

      if (result['success'] == true) {
        // Check if email confirmation is required
        if (result['requiresEmailConfirmation'] == true) {
          SafeSnackBar.showSuccess(
            context,
            message: result['message'] ?? 'Registration submitted successfully! Please check your email for verification.',
          );
          
          // Show email confirmation dialog
          _showEmailConfirmationDialog(result['email']);
        } else if (result['requiresManualLogin'] == true) {
          // Account created but manual login required
          SafeSnackBar.showSuccess(
            context,
            message: result['message'] ?? 'Account created successfully! Please log in to complete your registration.',
          );
          
          // Navigate to login screen after a delay
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        } else {
          // Normal successful registration
          SafeSnackBar.showSuccess(
            context,
            message: 'Registration completed successfully!',
          );

          // Wait a moment for the session to be established
          await Future.delayed(const Duration(seconds: 1));
          
          if (mounted) {
            // Check if user is authenticated and navigate accordingly
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null) {
              // User is authenticated, navigate to login screen which will handle role checking
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            } else {
              // User is not authenticated, show error and navigate to login
              SafeSnackBar.showError(
                context,
                message: 'Authentication session not established. Please log in manually.',
              );
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            }
          }
        }
      } else {
        SafeSnackBar.showError(
          context,
          message: result['message'] ?? 'Registration failed. Please try again.',
        );
      }
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'An unexpected error occurred. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Email verification status
          if (_registrationData.email.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isEmailVerified 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isEmailVerified 
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEmailVerified ? Icons.verified : Icons.warning,
                    color: _isEmailVerified ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isEmailVerified 
                          ? 'Email verified: ${_registrationData.email}'
                          : 'Email verification required: ${_registrationData.email}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isEmailVerified ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!_isEmailVerified)
                    TextButton(
                      onPressed: _verifyEmail,
                      child: const Text('Verify', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          // Step indicator
          Row(
            children: _steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;
              final canProceed = index == 0 ? _isEmailVerified : true;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive || isCompleted
                            ? mediumSeaGreen
                            : canProceed
                                ? Colors.grey.withValues(alpha: 0.3)
                                : Colors.red.withValues(alpha: 0.3),
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
                                : canProceed
                                    ? Colors.grey.withValues(alpha: 0.3)
                                    : Colors.red.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
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

  void _showEmailConfirmationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.email, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Check Your Email'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('We\'ve sent a confirmation link to:'),
              const SizedBox(height: 8),
              Text(
                email,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please check your email and click the confirmation link to complete your employer account setup.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'After confirming your email, you can log in to access your employer dashboard.',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Go to Login'),
            ),
          ],
        );
      },
    );
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
