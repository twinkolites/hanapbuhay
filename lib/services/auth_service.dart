import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Rate limiting variables
  static final Map<String, List<DateTime>> _loginAttempts = {};
  static const int _maxAttemptsPerMinute = 5;
  static const int _maxAttemptsPerHour = 20;

  // Sign up with email and password
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    String? displayName,
    String? username,
    String? birthday,
  }) async {
    try {
      // Validate input
      if (email.trim().isEmpty || password.isEmpty || fullName.trim().isEmpty) {
        throw AuthException('All required fields must be filled');
      }

      // Check if username is already taken
      if (username != null && username.trim().isNotEmpty) {
        final existingUser = await _supabase
            .from('profiles')
            .select('id')
            .eq('username', username.trim().toLowerCase())
            .maybeSingle();

        if (existingUser != null) {
          throw AuthException('Username already taken');
        }
      }

      // For cross-device email verification, we'll use a hybrid approach:
      // 1. Configure Supabase to redirect to a web page
      // 2. The web page tries to open the app automatically
      // 3. If app doesn't open, shows instructions for manual access
      final AuthResponse response = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'display_name': displayName?.trim() ?? fullName.trim(),
          'username': username?.trim().toLowerCase(),
          'phone_number': phoneNumber?.trim(),
          'birthday': birthday,
          'role': 'applicant', // Explicitly set default role
        },
        // GitHub Pages URL for cross-device email verification
        emailRedirectTo: 'https://twinkolites.github.io/hanapbuhay/',
      );

      if (response.user != null) {
        // Create user profile in Supabase
        await _createOrUpdateUserProfile(response.user!, birthday: birthday);
      }

      return response;
    } catch (e) {
      debugPrint('Error signing up with email: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Input validation
      if (email.trim().isEmpty || password.isEmpty) {
        throw AuthException('Email and password are required');
      }

      // Rate limiting check
      if (_isRateLimited(email.trim().toLowerCase())) {
        throw AuthException('Too many login attempts. Please try again later.');
      }

      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (response.user != null) {
        // Log successful login
        await _logLoginAttempt(
          response.user!.id,
          true,
          email.trim().toLowerCase(),
        );

        // Save tokens locally
        await _saveTokens(
          response.session?.accessToken,
          response.session?.refreshToken,
        );
      }

      return response;
    } catch (e) {
      // Log failed login attempt
      await _logLoginAttempt(null, false, email.trim().toLowerCase());

      if (e is AuthException) {
        rethrow;
      }
      throw AuthException(
        'Authentication failed. Please check your credentials.',
      );
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      if (email.trim().isEmpty) {
        throw AuthException('Email is required');
      }

      await _supabase.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: 'io.supabase.hanapbuhay://login-callback/',
      );
    } catch (e) {
      debugPrint('Error resetting password: $e');
      rethrow;
    }
  }

  // Sign in with Google
  static Future<AuthResponse?> signInWithGoogle() async {
    try {
      // Start Google Sign-In process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Sign in to Supabase with Google OAuth
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user != null) {
        // Store user data in Supabase if it's a new user
        await _createOrUpdateUserProfile(response.user!);

        // Log successful login
        await _logLoginAttempt(
          response.user!.id,
          true,
          response.user!.email ?? 'google_oauth',
        );

        // Save tokens locally
        await _saveTokens(
          response.session?.accessToken,
          response.session?.refreshToken,
        );
      }

      return response;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Create or update user profile in Supabase
  static Future<void> _createOrUpdateUserProfile(
    User user, {
    String? birthday,
  }) async {
    try {
      // Check if user profile already exists
      final existingProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        // Create new user profile
        await _supabase.from('profiles').insert({
          'id': user.id,
          'email': user.email?.toLowerCase(),
          'full_name': user.userMetadata?['full_name'] ?? '',
          'display_name':
              user.userMetadata?['display_name'] ??
              user.userMetadata?['full_name'] ??
              '',
          'username': user.userMetadata?['username']?.toLowerCase() ?? '',
          'phone_number': user.userMetadata?['phone_number'] ?? '',
          'avatar_url': user.userMetadata?['avatar_url'] ?? '',
          'birthday': birthday ?? user.userMetadata?['birthday'],
          'role': user.userMetadata?['role'] ?? 'applicant',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Update existing profile
        await _supabase
            .from('profiles')
            .update({
              'email': user.email?.toLowerCase(),
              'full_name':
                  user.userMetadata?['full_name'] ??
                  existingProfile['full_name'],
              'display_name':
                  user.userMetadata?['display_name'] ??
                  existingProfile['display_name'],
              'username':
                  user.userMetadata?['username']?.toLowerCase() ??
                  existingProfile['username'],
              'phone_number':
                  user.userMetadata?['phone_number'] ??
                  existingProfile['phone_number'],
              'avatar_url':
                  user.userMetadata?['avatar_url'] ??
                  existingProfile['avatar_url'],
              'birthday':
                  birthday ??
                  user.userMetadata?['birthday'] ??
                  existingProfile['birthday'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
      }
    } catch (e) {
      debugPrint('Error creating/updating user profile: $e');
    }
  }

  // Save tokens locally
  static Future<void> _saveTokens(
    String? accessToken,
    String? refreshToken,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (accessToken != null) {
        await prefs.setString('access_token', accessToken);
      }
      if (refreshToken != null) {
        await prefs.setString('refresh_token', refreshToken);
      }
    } catch (e) {
      debugPrint('Error saving tokens: $e');
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();

      // Clear local tokens
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');

      // Clear rate limiting data
      _loginAttempts.clear();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // Get current user
  static User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Check if user is signed in
  static bool isSignedIn() {
    return _supabase.auth.currentUser != null;
  }

  // Rate limiting check
  static bool _isRateLimited(String identifier) {
    final now = DateTime.now();
    final attempts = _loginAttempts[identifier] ?? [];

    // Remove attempts older than 1 hour
    final recentAttempts = attempts
        .where((attempt) => now.difference(attempt).inMinutes < 60)
        .toList();

    // Check hourly limit
    if (recentAttempts.length >= _maxAttemptsPerHour) {
      return true;
    }

    // Check per-minute limit
    final lastMinuteAttempts = recentAttempts
        .where((attempt) => now.difference(attempt).inMinutes < 1)
        .toList();

    if (lastMinuteAttempts.length >= _maxAttemptsPerMinute) {
      return true;
    }

    // Add current attempt
    recentAttempts.add(now);
    _loginAttempts[identifier] = recentAttempts;

    return false;
  }

  // Log login attempts for security monitoring
  static Future<void> _logLoginAttempt(
    String? userId,
    bool success,
    String identifier,
  ) async {
    try {
      // Try to insert with basic columns first
      await _supabase.from('login_attempts').insert({
        'user_id': userId,
        'success': success,
        'identifier': identifier, // email or username used
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // If basic insert fails, try with minimal columns
      try {
        await _supabase.from('login_attempts').insert({
          'user_id': userId,
          'success': success,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e2) {
        // If all logging fails, just log the error but don't break authentication
        debugPrint('Failed to log login attempt: $e2');
      }
    }
  }

  // Clear rate limiting data (useful for testing or admin purposes)
  static void clearRateLimitData() {
    _loginAttempts.clear();
  }

  // Get rate limit status for an identifier
  static Map<String, dynamic> getRateLimitStatus(String identifier) {
    final attempts = _loginAttempts[identifier] ?? [];
    final now = DateTime.now();

    final lastMinuteAttempts = attempts
        .where((attempt) => now.difference(attempt).inMinutes < 1)
        .length;

    final lastHourAttempts = attempts
        .where((attempt) => now.difference(attempt).inMinutes < 60)
        .length;

    return {
      'identifier': identifier,
      'attempts_last_minute': lastMinuteAttempts,
      'attempts_last_hour': lastHourAttempts,
      'is_blocked':
          lastMinuteAttempts >= _maxAttemptsPerMinute ||
          lastHourAttempts >= _maxAttemptsPerHour,
    };
  }
}
