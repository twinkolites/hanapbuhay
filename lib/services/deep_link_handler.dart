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

      // Handle custom scheme URLs (io.supabase.hanapbuhay://)
      if (uri.scheme == 'io.supabase.hanapbuhay') {
        await _handleCustomSchemeLink(uri);
        return;
      }

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

  /// Handle custom scheme deep links
  static Future<void> _handleCustomSchemeLink(Uri uri) async {
    try {
      debugPrint('🔗 Handling custom scheme link: $uri');
      debugPrint('🔗 Scheme: ${uri.scheme}, Host: ${uri.host}');
      debugPrint('🔗 Fragment: ${uri.fragment}');
      debugPrint('🔗 Query: ${uri.query}');

      if (uri.host == 'login-callback') {
        final registrationType = uri.queryParameters['registration_type'];
        final email = uri.queryParameters['email'];
        final tokenHash = uri.queryParameters['token_hash'];
        final type = uri.queryParameters['type'];
        final hasAccessToken = uri.queryParameters.containsKey('access_token');
        final hasRefreshToken = uri.queryParameters.containsKey('refresh_token');
        final error = uri.queryParameters['error'];
        final errorDescription = uri.queryParameters['error_description'];

        debugPrint('🔗 Deep link params:');
        debugPrint('   - type: $type');
        debugPrint('   - registration_type: $registrationType');
        debugPrint('   - hasAccessToken: $hasAccessToken');
        debugPrint('   - hasRefreshToken: $hasRefreshToken');
        debugPrint('   - error: $error');
        debugPrint('   - errorDescription: $errorDescription');

        // Check for errors first
        if (error != null) {
          debugPrint('❌ Deep link contains error: $error - $errorDescription');
          _showGenericErrorDialog(
            registrationType ?? 'applicant', 
            errorDescription ?? error
          );
          return;
        }

        // Handle token hash verification
        if (tokenHash != null && type != null) {
          debugPrint('🔗 Token hash verification detected');
          
          if (registrationType == 'employer') {
            debugPrint('🏢 Employer email confirmation detected');
            await _handleEmployerEmailConfirmation(tokenHash, type, email);
          } else {
            debugPrint('👤 Applicant email confirmation detected');
            await _handleRegularEmailConfirmation(tokenHash, type, email);
          }
        }
        // Handle access token (successful OAuth)
        else if (hasAccessToken && hasRefreshToken) {
          debugPrint('✅ OAuth tokens detected - user is authenticated');
          // User is already authenticated, navigate to appropriate screen
          _navigateToAppropriateScreen(registrationType);
        }
        else {
          debugPrint('⚠️ No valid authentication method detected in deep link');
          _showGenericErrorDialog(
            registrationType ?? 'applicant',
            'No valid authentication method found in the link'
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling custom scheme link: $e');
      _showGenericErrorDialog('applicant', e.toString());
    }
  }

  /// Navigate to appropriate screen based on user type
  static void _navigateToAppropriateScreen(String? userType) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (userType == 'employer') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const EmployerRegistrationScreen(),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
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
        _showExpiredTokenDialog('employer');
      }
    } catch (e) {
      debugPrint('❌ Error confirming employer email: $e');
      
      // Handle specific error types
      if (e is AuthException) {
        if (e.statusCode == '403' || e.message.contains('expired')) {
          _showExpiredTokenDialog('employer');
        } else if (e.message.contains('invalid')) {
          _showInvalidTokenDialog('employer');
        } else {
          _showGenericErrorDialog('employer', e.message);
        }
      } else {
        _showGenericErrorDialog('employer', e.toString());
      }
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
        _showExpiredTokenDialog('applicant');
      }
    } catch (e) {
      debugPrint('❌ Error confirming regular email: $e');
      
      // Handle specific error types
      if (e is AuthException) {
        if (e.statusCode == '403' || e.message.contains('expired')) {
          _showExpiredTokenDialog('applicant');
        } else if (e.message.contains('invalid')) {
          _showInvalidTokenDialog('applicant');
        } else {
          _showGenericErrorDialog('applicant', e.message);
        }
      } else {
        _showGenericErrorDialog('applicant', e.toString());
      }
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

  /// Show expired token dialog
  static void _showExpiredTokenDialog(String userType) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.access_time_filled,
              color: Colors.orange.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Link Expired',
                style: TextStyle(
                  color: Color(0xFF013237),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your email verification link has expired. This usually happens when:',
              style: TextStyle(
                color: const Color(0xFF013237).withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            _buildBulletPoint('The link is older than 1 hour'),
            _buildBulletPoint('You\'ve already used this link'),
            _buildBulletPoint('The link was clicked multiple times'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please request a new verification email from the registration screen.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
              _navigateToLogin();
            },
            child: Text(
              'Go to Login',
              style: TextStyle(
                color: const Color(0xFF013237).withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToRegistration(userType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CA771),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Request New Link',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Show invalid token dialog
  static void _showInvalidTokenDialog(String userType) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Invalid Link',
                style: TextStyle(
                  color: Color(0xFF013237),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This verification link appears to be invalid or corrupted.',
              style: TextStyle(
                color: const Color(0xFF013237).withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please try registering again or contact support if the problem persists.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
              _navigateToLogin();
            },
            child: Text(
              'Go to Login',
              style: TextStyle(
                color: const Color(0xFF013237).withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToRegistration(userType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CA771),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Show generic error dialog
  static void _showGenericErrorDialog(String userType, String errorMessage) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_outlined,
              color: Colors.orange.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Verification Error',
                style: TextStyle(
                  color: Color(0xFF013237),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We encountered an issue while verifying your email:',
              style: TextStyle(
                color: const Color(0xFF013237).withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                errorMessage,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToLogin();
            },
            child: Text(
              'Go to Login',
              style: TextStyle(
                color: const Color(0xFF013237).withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToRegistration(userType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CA771),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Build bullet point widget
  static Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: const Color(0xFF013237).withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFF013237).withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
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

  /// Navigate to registration screen based on user type
  static void _navigateToRegistration(String userType) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (userType == 'employer') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const EmployerRegistrationScreen(),
        ),
        (route) => false,
      );
    } else {
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
