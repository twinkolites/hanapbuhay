import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../main.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  // Initialize auth state
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        _user = currentUser;
      }
      
      // Listen to auth state changes
      supabase.auth.onAuthStateChange.listen((data) {
        _user = data.session?.user;
        notifyListeners();
      });
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
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

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
