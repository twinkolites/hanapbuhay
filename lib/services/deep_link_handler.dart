import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import '../screens/employer/employer_registration_screen.dart';
import '../screens/login_screen.dart';

class DeepLinkHandler {
  static StreamSubscription<Uri>? _linkSubscription;
  static bool _isInitialized = false;
  static late AppLinks _appLinks;

  /// Initialize deep link handling for the app
  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleDeepLink(uri.toString());
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  /// Handle incoming deep links
  static Future<void> _handleDeepLink(String link) async {
    try {
      final uri = Uri.parse(link);
      debugPrint('🔗 Deep link received: $link');

      // Check if this is an email confirmation link
      if (uri.host.contains('twinkolites.github.io') || 
          uri.host.contains('hanapbuhay')) {
        
        final registrationType = uri.queryParameters['registration_type'];
        final email = uri.queryParameters['email'];
        final tokenHash = uri.queryParameters['token_hash'];
        final type = uri.queryParameters['type'];

        debugPrint('📧 Email confirmation detected:');
        debugPrint('  - Registration type: $registrationType');
        debugPrint('  - Email: $email');
        debugPrint('  - Token hash: ${tokenHash?.substring(0, 8)}...');
        debugPrint('  - Type: $type');

        // Handle employer registration confirmation
        if (registrationType == 'employer' && tokenHash != null && type != null) {
          await _handleEmployerEmailConfirmation(tokenHash, type, email);
        }
        // Handle regular email confirmation
        else if (tokenHash != null && type != null) {
          await _handleRegularEmailConfirmation(tokenHash, type, email);
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling deep link: $e');
    }
  }

  /// Handle employer-specific email confirmation
  static Future<void> _handleEmployerEmailConfirmation(
    String tokenHash, 
    String type, 
    String? email
  ) async {
    try {
      debugPrint('🏢 Processing employer email confirmation...');
      
      final supabase = Supabase.instance.client;
      
      // Verify the email confirmation
      final response = await supabase.auth.verifyOTP(
        tokenHash: tokenHash,
        type: OtpType.email,
      );

      if (response.user != null) {
        debugPrint('✅ Employer email confirmed successfully');
        
        // Store employer registration context
        await _storeEmployerRegistrationContext(email);
        
        // Navigate to employer registration screen
        _navigateToEmployerRegistration();
      } else {
        debugPrint('❌ Employer email confirmation failed - no user returned');
      }
    } catch (e) {
      debugPrint('❌ Error confirming employer email: $e');
    }
  }

  /// Handle regular email confirmation
  static Future<void> _handleRegularEmailConfirmation(
    String tokenHash, 
    String type, 
    String? email
  ) async {
    try {
      debugPrint('📧 Processing regular email confirmation...');
      
      final supabase = Supabase.instance.client;
      
      // Verify the email confirmation
      final response = await supabase.auth.verifyOTP(
        tokenHash: tokenHash,
        type: OtpType.email,
      );

      if (response.user != null) {
        debugPrint('✅ Regular email confirmed successfully');
        
        // Navigate to login screen
        _navigateToLogin();
      } else {
        debugPrint('❌ Regular email confirmation failed - no user returned');
      }
    } catch (e) {
      debugPrint('❌ Error confirming regular email: $e');
    }
  }

  /// Store employer registration context for later use
  static Future<void> _storeEmployerRegistrationContext(String? email) async {
    if (email != null) {
      // Store in SharedPreferences or similar for persistence
      // This helps the employer registration screen know the email is verified
      debugPrint('💾 Storing employer registration context for: $email');
    }
  }

  /// Navigate to employer registration screen
  static void _navigateToEmployerRegistration() {
    // Use a global navigator key or context to navigate
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const EmployerRegistrationScreen(),
        ),
        (route) => false,
      );
    }
  }

  /// Navigate to login screen
  static void _navigateToLogin() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }

  /// Dispose of deep link handling
  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _isInitialized = false;
  }
}

// Global navigator key for navigation from anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
