import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/safe_snackbar.dart';
import '../login_screen.dart';

class EmailVerificationBlockedScreen extends StatefulWidget {
  final String email;
  
  const EmailVerificationBlockedScreen({super.key, required this.email});

  @override
  State<EmailVerificationBlockedScreen> createState() => _EmailVerificationBlockedScreenState();
}

class _EmailVerificationBlockedScreenState extends State<EmailVerificationBlockedScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  Future<void> _checkEmailVerificationStatus() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        SafeSnackBar.showError(context, message: 'No authenticated user found. Please log in.');
        return;
      }

      // Check if email is verified
      if (user.emailConfirmedAt != null) {
        SafeSnackBar.showSuccess(context, message: 'Email verified! Checking application status...');
        
        // Wait a moment for the success message
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          // Navigate back to login screen to trigger role checking
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } else {
        SafeSnackBar.showInfo(context, message: 'Email not yet verified. Please check your email and click the confirmation link.');
      }
    } catch (e) {
      SafeSnackBar.showError(context, message: 'Error checking verification status: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isLoading = true);

    try {
      // Use the correct Supabase auth.resend() method with OtpType.signup
      // This is the proper way according to Supabase Flutter documentation (2024/2025)
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
        emailRedirectTo: 'https://twinkolites.github.io/hanapbuhay/',
      );

      // The resend method in newer Supabase SDK doesn't return errors in the traditional way
      // If no exception is thrown, it succeeded
      SafeSnackBar.showSuccess(
        context, 
        message: 'Verification email sent! Please check your inbox and spam folder.'
      );
    } on AuthException catch (e) {
      // Handle Supabase-specific auth errors
      SafeSnackBar.showError(
        context, 
        message: 'Failed to resend verification email: ${e.message}'
      );
    } catch (e) {
      // Handle general errors
      SafeSnackBar.showError(
        context, 
        message: 'Failed to resend verification email: $e'
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      SafeSnackBar.showError(context, message: 'Failed to sign out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        title: const Text(
          'Email Verification Required',
          style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold),
        ),
        backgroundColor: lightMint,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: darkTeal),
            onPressed: _signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Email Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.email_outlined,
                          size: 80,
                          color: Colors.orange,
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Title
                      Text(
                        'Email Verification Required',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Description
                      Text(
                        'To complete your employer registration, please verify your email address.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.8),
                          fontSize: 16,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Email Address Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.email, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              widget.email,
                              style: TextStyle(
                                color: Colors.blue[800],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Instructions Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: mediumSeaGreen),
                                const SizedBox(width: 8),
                                Text(
                                  'How to verify your email:',
                                  style: TextStyle(
                                    color: darkTeal,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildInstructionStep(
                              '1',
                              'Check your email inbox',
                              'Look for an email from Hanapbuhay',
                            ),
                            _buildInstructionStep(
                              '2',
                              'Click the verification link',
                              'This will confirm your email address',
                            ),
                            _buildInstructionStep(
                              '3',
                              'Return to the app',
                              'Your employer application will be processed',
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Action Buttons
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _checkEmailVerificationStatus,
                              icon: _isLoading 
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(Icons.refresh),
                              label: Text(_isLoading ? 'Checking...' : 'Check Verification Status'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mediumSeaGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _resendVerificationEmail,
                              icon: Icon(Icons.email),
                              label: const Text('Resend Verification Email'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: mediumSeaGreen,
                                side: BorderSide(color: mediumSeaGreen),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          TextButton(
                            onPressed: _signOut,
                            child: Text(
                              'Sign Out',
                              style: TextStyle(
                                color: darkTeal.withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: mediumSeaGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
