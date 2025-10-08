import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/applicant/home_screen.dart';
import 'screens/employer/home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/applicant/job_preferences_screen.dart';
import 'screens/employer/employer_registration_screen.dart';
import 'config/app_config.dart';
import 'services/ai_screening_service.dart';
import 'services/job_recommendation_service.dart';
import 'services/deep_link_handler.dart';
import 'services/stay_signed_in_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: ".env");

  // Print configuration in debug mode
  AppConfig.printConfig();

  // Validate configuration
  if (!AppConfig.isConfigValid) {
    print('❌ Invalid configuration detected!');
    print('❌ Please check your environment variables.');
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Initialize AI Screening Service
  AIScreeningService.initialize();
  
  // Initialize Job Recommendation Service
  JobRecommendationService.initialize();

  // Initialize Deep Link Handler
  DeepLinkHandler.initialize();

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _authSubscription;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupDeepLinkHandling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App is being paused or terminated
        StaySignedInService.handleAppTermination();
        break;
      case AppLifecycleState.resumed:
        // App is being resumed
        break;
      case AppLifecycleState.inactive:
        // App is inactive (e.g., phone call)
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        break;
    }
  }

  void _setupDeepLinkHandling() {
    // Initialize app links
    _appLinks = AppLinks();

    // Listen to auth state changes for deep link handling
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      print('🔄 Auth state change: $event'); // Debug print
      print('🔄 Has session: ${session != null}'); // Debug print
    });

    // Handle incoming links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        print('📱 Deep link received while app running: $uri');
        _handleDeepLink(uri);
      },
      onError: (Object err) {
        print('❌ Deep link error: $err');
      },
    );

    // Handle initial link when app is launched
    _handleInitialLink();
  }

  void _handleInitialLink() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        print('🚀 Initial deep link: $initialUri');
        _handleDeepLink(initialUri);
      } else {
        print('📭 No initial deep link');
      }
    } catch (e) {
      print('❌ Error handling initial link: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    print('🔗 Handling deep link: $uri'); // Debug print
    print('🔗 Scheme: ${uri.scheme}, Host: ${uri.host}'); // Debug print
    print('🔗 Fragment: ${uri.fragment}'); // Debug print
    print('🔗 Query: ${uri.query}'); // Debug print

    // Handle custom scheme links only
    if (uri.scheme == 'io.supabase.hanapbuhay') {
      // Extract tokens from the URI fragment or query parameters
      final fragment = uri.fragment;
      final query = uri.query;

      // Try fragment first, then query
      final params = Uri.splitQueryString(
        fragment.isNotEmpty ? fragment : query,
      );

      final accessToken = params['access_token'];
      final refreshToken = params['refresh_token'];
      final type = params['type'];
      final error = params['error'];
      final errorDescription = params['error_description'];
      final registrationType = params['registration_type'];
      final tokenHash = params['token_hash'];
      final email = params['email'];

      print('🔗 Deep link params:'); // Debug print
      print('   - type: $type'); // Debug print
      print('   - registration_type: $registrationType'); // Debug print
      print('   - hasAccessToken: ${accessToken != null}'); // Debug print
      print('   - hasRefreshToken: ${refreshToken != null}'); // Debug print
      print('   - error: $error'); // Debug print
      print('   - errorDescription: $errorDescription'); // Debug print

      // Handle errors
      if (error != null) {
        print('❌ Auth error: $error - $errorDescription');
        _showAuthError(error, errorDescription);
        return;
      }

      // Handle different deep link scenarios for hybrid verification flow
      if (tokenHash != null && type != null) {
        print('🔗 Token hash verification detected'); // Debug print
        
        // Check if this is an employer registration
        if (registrationType == 'employer') {
          print('🏢 Employer email confirmation detected'); // Debug print
          _handleEmployerTokenHashVerification(tokenHash, type, email);
        } else if (registrationType == 'applicant') {
          print('👤 Applicant email confirmation detected'); // Debug print
          _handleApplicantTokenHashVerification(tokenHash, type, email);
        } else {
          print('📧 Regular email confirmation detected'); // Debug print
          _handleTokenHashVerification(tokenHash, type, email);
        }
      } else if (type == 'signup' && accessToken != null) {
        print('🔗 Email confirmation detected'); // Debug print
        
        // Check if this is an employer registration
        if (registrationType == 'employer') {
          print('🏢 Employer email confirmation detected'); // Debug print
          _handleEmployerEmailConfirmation(accessToken, refreshToken);
        } else if (registrationType == 'applicant') {
          print('👤 Applicant email confirmation detected'); // Debug print
          _handleApplicantEmailConfirmation(accessToken, refreshToken);
        } else {
          print('📧 Regular email confirmation detected'); // Debug print
          _handleEmailConfirmation(accessToken, refreshToken);
        }
      } else if (accessToken != null) {
        // Handle generic auth callback with access token
        print('🔗 Generic auth callback detected'); // Debug print
        _handleEmailConfirmation(accessToken, refreshToken);
      } else if (type == 'recovery' && accessToken != null) {
        // Handle password recovery (if needed in future)
        print('🔗 Password recovery detected'); // Debug print
        _handleEmailConfirmation(accessToken, refreshToken);
      } else {
        // No tokens found - this could be a manual app open from web verification
        // Just navigate to the appropriate screen based on auth state
        print(
          '🔗 App opened without tokens - checking auth state',
        ); // Debug print
        _handleAppOpenWithoutTokens();
      }
    } else {
      print('🔗 Scheme does not match expected patterns'); // Debug print
    }
  }

  void _handleAppOpenWithoutTokens() {
    // Handle when app is opened without tokens (e.g., from web verification page)
    // Check current auth state and navigate appropriately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null && currentUser.emailConfirmedAt != null) {
          // User is verified - show success message and go to login for security
          print(
            '✅ User verified from web - showing success then login for security',
          ); // Debug print
          _showWebVerificationSuccess(context);
        } else if (currentUser != null &&
            currentUser.emailConfirmedAt == null) {
          // User logged in but not verified - show verification needed
          print('⚠️ User logged in but not verified'); // Debug print
          _showVerificationNeeded(context);
        } else {
          // No user logged in - go to login
          print('🔐 No user logged in - navigating to login'); // Debug print
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    });
  }

  void _showWebVerificationSuccess(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Email Verified Successfully!',
          style: TextStyle(
            color: Color(0xFF013237),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your email has been verified! For security, please sign in with your password.',
              style: TextStyle(color: Color(0xFF013237)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF9E7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC0E6BA), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Color(0xFF4CA771), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This extra step keeps your account secure.',
                      style: TextStyle(color: Color(0xFF013237), fontSize: 12),
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
            child: const Text(
              'Sign In',
              style: TextStyle(
                color: Color(0xFF4CA771),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVerificationNeeded(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Email Verification Required',
          style: TextStyle(
            color: Color(0xFF013237),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Your account needs email verification. Please check your email and click the verification link.',
          style: TextStyle(color: Color(0xFF013237)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF4CA771))),
          ),
        ],
      ),
    );
  }

  void _handleApplicantTokenHashVerification(String tokenHash, String type, String? email) async {
    print('👤 Handling applicant token hash verification'); // Debug print

    try {
      final supabase = Supabase.instance.client;
      
      // Verify the email confirmation using token hash
      final response = await supabase.auth.verifyOTP(
        tokenHash: tokenHash,
        type: OtpType.email,
      );

      if (response.user != null) {
        print('✅ Applicant email confirmed successfully via token hash'); // Debug print
        
        // Show success toast and navigate to login screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = _navigatorKey.currentContext;
          if (context != null) {
            _showApplicantAccountCreatedSuccess(context);
          }
        });
      } else {
        print('❌ Applicant email confirmation failed - no user returned'); // Debug print
      }
    } catch (e) {
      print('❌ Error confirming applicant email via token hash: $e'); // Debug print
      
      // Show error message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _navigatorKey.currentContext;
        if (context != null) {
          _showEmailConfirmationError(context, e.toString());
        }
      });
    }
  }

  void _handleApplicantEmailConfirmation(String accessToken, String? refreshToken) {
    print('👤 Handling applicant email confirmation'); // Debug print

    // Set the session manually
    supabase.auth
        .setSession(accessToken)
        .then((_) {
          print('✅ Applicant session set successfully'); // Debug print

          // Show success toast and navigate to login screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = _navigatorKey.currentContext;
            if (context != null) {
              _showApplicantAccountCreatedSuccess(context);
            }
          });
        })
        .catchError((error) {
          print('❌ Error setting applicant session: $error'); // Debug print

          // Show error message
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = _navigatorKey.currentContext;
            if (context != null) {
              _showEmailConfirmationError(context, error.toString());
            }
          });
        });
  }

  void _showApplicantAccountCreatedSuccess(BuildContext context) {
    // Show success toast first
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Account created successfully! Email verified.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CA771),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
    
    // Then show the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Welcome to Hanapbuhay!',
          style: TextStyle(
            color: Color(0xFF013237),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your account has been successfully created and verified!',
              style: TextStyle(
                color: Color(0xFF013237),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You can now sign in and start exploring job opportunities.',
              style: TextStyle(color: Color(0xFF013237), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF9E7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC0E6BA), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.work, color: Color(0xFF4CA771), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Start browsing jobs and apply for positions that match your skills.',
                      style: TextStyle(color: Color(0xFF013237), fontSize: 12),
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
            child: const Text(
              'Sign In',
              style: TextStyle(
                color: Color(0xFF4CA771),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleEmployerTokenHashVerification(String tokenHash, String type, String? email) async {
    print('🏢 Handling employer token hash verification'); // Debug print

    try {
      final supabase = Supabase.instance.client;
      
      // Verify the email confirmation using token hash
      final response = await supabase.auth.verifyOTP(
        tokenHash: tokenHash,
        type: OtpType.email,
      );

      if (response.user != null) {
        print('✅ Employer email confirmed successfully via token hash'); // Debug print
        
        // Show success message and navigate to employer registration screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = _navigatorKey.currentContext;
          if (context != null) {
            _showEmployerEmailConfirmationSuccess(context);
          }
        });
      } else {
        print('❌ Employer email confirmation failed - no user returned'); // Debug print
      }
    } catch (e) {
      print('❌ Error confirming employer email via token hash: $e'); // Debug print
      
      // Show error message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _navigatorKey.currentContext;
        if (context != null) {
          _showEmailConfirmationError(context, e.toString());
        }
      });
    }
  }

  void _handleTokenHashVerification(String tokenHash, String type, String? email) async {
    print('📧 Handling regular token hash verification'); // Debug print

    try {
      final supabase = Supabase.instance.client;
      
      // Verify the email confirmation using token hash
      final response = await supabase.auth.verifyOTP(
        tokenHash: tokenHash,
        type: OtpType.email,
      );

      if (response.user != null) {
        print('✅ Regular email confirmed successfully via token hash'); // Debug print
        
        // Show success message and navigate to appropriate screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = _navigatorKey.currentContext;
          if (context != null) {
            _showEmailConfirmationSuccess(context);
          }
        });
      } else {
        print('❌ Regular email confirmation failed - no user returned'); // Debug print
      }
    } catch (e) {
      print('❌ Error confirming regular email via token hash: $e'); // Debug print
      
      // Handle specific error cases
      if (e.toString().contains('otp_expired') || e.toString().contains('Email link is invalid')) {
        // Show expired link dialog with options
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = _navigatorKey.currentContext;
          if (context != null) {
            _showExpiredLinkDialog(context, email);
          }
        });
      } else {
        // Show generic error message
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = _navigatorKey.currentContext;
          if (context != null) {
            _showEmailConfirmationError(context, e.toString());
          }
        });
      }
    }
  }

  void _handleEmployerEmailConfirmation(String accessToken, String? refreshToken) {
    print('🏢 Handling employer email confirmation'); // Debug print

    // Set the session manually
    supabase.auth
        .setSession(accessToken)
        .then((_) {
          print('✅ Employer session set successfully'); // Debug print

          // Show success message and navigate to employer registration screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = _navigatorKey.currentContext;
            if (context != null) {
              _showEmployerEmailConfirmationSuccess(context);
            }
          });
        })
        .catchError((error) {
          print('❌ Error setting employer session: $error'); // Debug print

          // Show error message
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = _navigatorKey.currentContext;
            if (context != null) {
              _showEmailConfirmationError(context, error.toString());
            }
          });
        });
  }

  void _handleEmailConfirmation(String accessToken, String? refreshToken) {
    print('✅ Handling email confirmation'); // Debug print

    // Set the session manually
    supabase.auth
        .setSession(accessToken)
        .then((_) {
          print('✅ Session set successfully'); // Debug print

          // Show success message and navigate to appropriate screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = _navigatorKey.currentContext;
            if (context != null) {
              _showEmailConfirmationSuccess(context);
            }
          });
        })
        .catchError((error) {
          print('❌ Error setting session: $error'); // Debug print

          // Show error message
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = _navigatorKey.currentContext;
            if (context != null) {
              _showEmailConfirmationError(context, error.toString());
            }
          });
        });
  }

  void _showEmployerEmailConfirmationSuccess(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Employer Email Confirmed!',
          style: TextStyle(
            color: Color(0xFF013237),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your employer email has been successfully verified!',
              style: TextStyle(
                color: Color(0xFF013237),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You can now continue with your employer registration process.',
              style: TextStyle(color: Color(0xFF013237), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF9E7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC0E6BA), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.business, color: Color(0xFF4CA771), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complete your employer profile to start posting jobs.',
                      style: TextStyle(color: Color(0xFF013237), fontSize: 12),
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
              // Navigate to employer registration screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmployerRegistrationScreen(),
                ),
              );
            },
            child: const Text(
              'Continue Registration',
              style: TextStyle(
                color: Color(0xFF4CA771),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailConfirmationSuccess(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Email Confirmed!',
          style: TextStyle(
            color: Color(0xFF013237),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your email has been successfully verified!',
              style: TextStyle(
                color: Color(0xFF013237),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Welcome to Hanapbuhay! You can now access all features of the app.',
              style: TextStyle(color: Color(0xFF013237), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF9E7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC0E6BA), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF4CA771), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your account is now active and ready to use.',
                      style: TextStyle(color: Color(0xFF013237), fontSize: 12),
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
              // Navigate to appropriate home screen based on user role
              _navigateToHomeScreen(context);
            },
            child: const Text(
              'Get Started',
              style: TextStyle(
                color: Color(0xFF4CA771),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpiredLinkDialog(BuildContext context, String? email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Verification Link Expired',
          style: TextStyle(
            color: Color(0xFF013237),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      'This verification link has expired or has already been used.',
                      style: TextStyle(
                        color: const Color(0xFFE65100),
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
              'Don\'t worry! You can still complete your registration by signing in with your email and password.',
              style: TextStyle(
                color: const Color(0xFF013237),
                fontSize: 14,
              ),
            ),
            if (email != null) ...[
              const SizedBox(height: 12),
              Text(
                'Email: $email',
                style: TextStyle(
                  color: const Color(0xFF013237),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF9E7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFC0E6BA), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: const Color(0xFF4CA771), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If you haven\'t created an account yet, please register first.',
                      style: TextStyle(
                        color: const Color(0xFF013237),
                        fontSize: 12,
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
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
            child: const Text(
              'Register',
              style: TextStyle(
                color: Color(0xFF4CA771),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text(
              'Sign In',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CA771),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailConfirmationError(BuildContext context, String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Verification Failed',
          style: TextStyle(
            color: Color(0xFF013237),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We encountered an issue verifying your email.',
              style: TextStyle(
                color: Color(0xFF013237),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Error: $error',
              style: const TextStyle(color: Color(0xFF013237), fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Color(0xFFF44336), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please try again or contact support if the problem persists.',
                      style: TextStyle(color: Color(0xFF013237), fontSize: 12),
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
            child: const Text(
              'Go to Login',
              style: TextStyle(
                color: Color(0xFF4CA771),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAuthError(String error, String? description) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Authentication Error',
              style: TextStyle(
                color: Color(0xFF013237),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error: $error',
                  style: const TextStyle(
                    color: Color(0xFF013237),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF013237),
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFFCDD2),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Color(0xFFF44336),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please try again or contact support if the problem persists.',
                          style: TextStyle(
                            color: Color(0xFF013237),
                            fontSize: 12,
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
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Go to Login',
                  style: TextStyle(
                    color: Color(0xFF4CA771),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    });
  }

  void _navigateToHomeScreen(BuildContext context) async {
    // Add a small delay to prevent animation conflicts
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Check if widget is still mounted
    if (!mounted) return;
    
    // Get user role and navigate accordingly
    final user = supabase.auth.currentUser;
    if (user != null) {
      final role = user.userMetadata?['role'] as String? ?? 'applicant';

      if (role == 'admin') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
          );
        }
      } else if (role == 'employer') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EmployerHomeScreen()),
          );
        }
      } else {
        // Check if user needs onboarding
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.refreshUserStatus();
        
        if (mounted) {
          if (authProvider.shouldShowOnboarding) {
            // Navigate to onboarding for new users
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OnboardingWrapper(),
              ),
            );
          } else {
            // Navigate to home screen for existing users
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      }
    } else {
      // Fallback to login screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Hanapbuhay',
        theme: ThemeData(primarySwatch: Colors.green),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Fade animation for the logo
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Slide animation - moves logo from bottom to center (behind bottom element)
    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0.0, 0.3), // Start slightly lower
          end: const Offset(0.0, -0.1), // End slightly above center
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );

    // Start animation when screen loads
    _animationController.forward();

    // Navigate to next screen after animation completes
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Wait a bit then navigate to welcome screen
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 600),
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const WelcomeScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      final slide =
                          Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                          );
                      final fade = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeIn,
                      );
                      return FadeTransition(
                        opacity: fade,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFEAF9E7,
      ), // Your specified background color
      body: Stack(
        children: [
          // Logo with fade-in and slide-up animation
          Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
          // Bottom element - static at the bottom
          Positioned(
            bottom: -1,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/bottom_element.png',
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xFF4CAF50)],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  const Spacer(flex: 3),

                  // Get Started Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CA771),
                        foregroundColor: Colors.white,
                        elevation: 10,
                        shadowColor: const Color(
                          0xFF4CA771,
                        ).withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onboarding wrapper that handles the new user flow
class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({super.key});

  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading while checking user status
        if (authProvider.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFFEAF9E7),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4CA771),
              ),
            ),
          );
        }

        // If user has completed onboarding, go to home screen
        if (authProvider.hasCompletedOnboarding) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          });
          return const Scaffold(
            backgroundColor: Color(0xFFEAF9E7),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4CA771),
              ),
            ),
          );
        }

        // Show onboarding screen for new users
        return const OnboardingScreen();
      },
    );
  }
}

/// Onboarding screen that guides new users through job preference setup
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF9E7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              
              // Welcome message
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF013237).withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // AI icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CA771), Color(0xFF013237)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.psychology,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      'Welcome to HanapBuhay!',
                      style: TextStyle(
                        color: const Color(0xFF013237),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      'Let\'s personalize your job search experience by setting up your preferences. Our AI will use this information to recommend the best jobs for you.',
                      style: TextStyle(
                        color: const Color(0xFF013237).withValues(alpha: 0.7),
                        fontSize: 16,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Features list
                    Column(
                      children: [
                        _buildFeatureItem(
                          icon: Icons.work_outline,
                          text: 'Personalized job recommendations',
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          icon: Icons.trending_up,
                          text: 'Career growth opportunities',
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          icon: Icons.location_on,
                          text: 'Location-based matching',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Action buttons
              Column(
                children: [
                  // Start onboarding button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JobPreferencesScreen(),
                          ),
                        );
                        
                        if (result == true) {
                          // Mark onboarding as completed
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          await authProvider.markOnboardingCompleted();
                          
                          // Navigate to home screen
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const HomeScreen()),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CA771),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Set Up My Preferences',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Skip button
                  TextButton(
                    onPressed: () async {
                      // Mark onboarding as completed even if skipped
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      await authProvider.markOnboardingCompleted();
                      
                      // Navigate to home screen
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                      );
                    },
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        color: const Color(0xFF013237).withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF4CA771).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF4CA771),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: const Color(0xFF013237).withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
