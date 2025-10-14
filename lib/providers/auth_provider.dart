import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/new_user_detection_service.dart';
import '../services/stay_signed_in_service.dart';
import '../services/job_preferences_service.dart';
import '../services/onesignal_notification_service.dart';
import '../main.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  bool _isNewUser = false;
  bool _hasCompletedOnboarding = false;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isNewUser => _isNewUser;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get shouldShowOnboarding => _isNewUser && !_hasCompletedOnboarding;

  // Initialize auth state
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Use the StaySignedInService to validate session
      final hasValidSession = await StaySignedInService.validateSessionOnStartup();
      
      if (hasValidSession) {
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          _user = currentUser;
          await _checkUserStatus();
        }
      } else {
        _user = null;
        _isNewUser = false;
        _hasCompletedOnboarding = false;
      }
      
      // Listen to auth state changes
      supabase.auth.onAuthStateChange.listen((data) async {
        _user = data.session?.user;
        if (_user != null) {
          await _checkUserStatus();
          // Subscribe to OneSignal notifications when user logs in
          await OneSignalNotificationService.subscribeUser(_user!.id);
        } else {
          _isNewUser = false;
          _hasCompletedOnboarding = false;
          // Unsubscribe from notifications when user logs out
          await OneSignalNotificationService.unsubscribeUser(_user?.id ?? '');
        }
        notifyListeners();
      });
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check if user is suspended
  bool _isSuspended = false;
  String? _suspensionReason;
  
  bool get isSuspended => _isSuspended;
  String? get suspensionReason => _suspensionReason;

  // Check user status (new user, onboarding completion, suspension)
  Future<void> _checkUserStatus() async {
    if (_user == null) return;
    
    try {
      // Check suspension status
      await _checkSuspensionStatus();
      
      // Only check onboarding if not suspended
      if (!_isSuspended) {
        final status = await NewUserDetectionService.getOnboardingStatus(_user!.id);
        _isNewUser = status['isNewUser'] ?? false;
        _hasCompletedOnboarding = status['hasCompletedOnboarding'] ?? false;
        
        debugPrint('🔍 User status for ${_user!.id}: isNew=$_isNewUser, completed=$_hasCompletedOnboarding');
      }
    } catch (e) {
      debugPrint('❌ Error checking user status: $e');
      _isNewUser = false;
      _hasCompletedOnboarding = false;
    }
  }

  // Check if user account is suspended
  Future<void> _checkSuspensionStatus() async {
    if (_user == null) return;
    
    try {
      final response = await supabase
          .from('profiles')
          .select('is_suspended, suspension_reason')
          .eq('id', _user!.id)
          .maybeSingle();
      
      if (response != null) {
        final wasSuspended = _isSuspended;
        _isSuspended = response['is_suspended'] == true;
        _suspensionReason = response['suspension_reason'] as String?;
        
        if (_isSuspended && !wasSuspended) {
          // User just got suspended
          debugPrint('⚠️ User ${_user!.id} is suspended: $_suspensionReason');
          notifyListeners(); // Notify listeners to show suspension screen
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking suspension status: $e');
    }
  }

  // Get user role
  String getUserRole() {
    if (_user == null) return 'applicant';
    return _user!.userMetadata?['role'] as String? ?? 'applicant';
  }

  // Check if user is employer
  bool get isEmployer => getUserRole() == 'employer';

  // Check if user is applicant
  bool get isApplicant => getUserRole() == 'applicant' || getUserRole().isEmpty;

  // Sign in with email
  Future<bool> signInWithEmail({required String email, required String password}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await AuthService.signInWithEmail(email: email, password: password);
      
      // Check suspension status immediately after login
      final user = supabase.auth.currentUser;
      if (user != null) {
        final profileResponse = await supabase
            .from('profiles')
            .select('is_suspended, suspension_reason')
            .eq('id', user.id)
            .maybeSingle();
        
        if (profileResponse != null && profileResponse['is_suspended'] == true) {
          _isSuspended = true;
          _suspensionReason = profileResponse['suspension_reason'] as String?;
          
          // Sign out the suspended user
          await supabase.auth.signOut();
          _user = null;
          
          _error = 'Account suspended';
          return false;
        }
      }
      
      // Mark session as valid after successful login (respects user preference)
      await StaySignedInService.markSessionAsValid();
      
      return true;
      
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await AuthService.signInWithGoogle();
      return true;
      
    } catch (e) {
      _error = 'Google Sign-In failed: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign up
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String displayName,
    required String username,
    String? phoneNumber,
    String? birthday,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await AuthService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        displayName: displayName,
        username: username,
        phoneNumber: phoneNumber,
        birthday: birthday,
      );
      return true;
      
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await supabase.auth.signOut();
      
      // Clear all session data and preferences
      await StaySignedInService.clearSessionData();
      await JobPreferencesService.clearPreferencesData();
      
      // Unsubscribe from OneSignal notifications
      if (_user != null) {
        await OneSignalNotificationService.unsubscribeUser(_user!.id);
      }
      
      _user = null;
      
    } catch (e) {
      _error = 'Sign out failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await AuthService.resetPassword(email);
      return true;
    } catch (e) {
      _error = 'Password reset failed: $e';
      notifyListeners();
      return false;
    }
  }

  // Check if user email is verified
  bool get isEmailVerified {
    if (_user == null) return false;
    return _user!.emailConfirmedAt != null;
  }

  // Mark onboarding as completed
  Future<void> markOnboardingCompleted() async {
    if (_user == null) return;
    
    try {
      await NewUserDetectionService.markOnboardingCompleted(_user!.id);
      _hasCompletedOnboarding = true;
      _isNewUser = false;
      notifyListeners();
      
      debugPrint('✅ Onboarding marked as completed for user: ${_user!.id}');
    } catch (e) {
      debugPrint('❌ Error marking onboarding as completed: $e');
    }
  }

  // Refresh user status (useful after completing onboarding)
  Future<void> refreshUserStatus() async {
    await _checkUserStatus();
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
