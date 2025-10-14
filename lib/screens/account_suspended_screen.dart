import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class AccountSuspendedScreen extends StatelessWidget {
  final String? reason;
  
  const AccountSuspendedScreen({
    super.key,
    this.reason,
  });

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: lightMint,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Suspension Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.block,
                      size: 60,
                      color: Colors.red,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    'Account Suspended',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: darkTeal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Message
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: darkTeal.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Your access has been restricted',
                              style: TextStyle(
                                fontSize: 13, // Title size
                                fontWeight: FontWeight.w600,
                                color: darkTeal,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          'Your account has been suspended and you cannot access the application at this time.',
                          style: TextStyle(
                            fontSize: 11, // Body size
                            color: darkTeal.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                        ),
                        
                        if (reason != null && reason!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          
                          Divider(color: darkTeal.withValues(alpha: 0.1)),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            'Reason for Suspension:',
                            style: TextStyle(
                              fontSize: 13, // Title size
                              fontWeight: FontWeight.w600,
                              color: darkTeal,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              reason!,
                              style: TextStyle(
                                fontSize: 11, // Body size
                                color: darkTeal.withValues(alpha: 0.9),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // What to do section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: darkTeal.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What you can do:',
                          style: TextStyle(
                            fontSize: 13, // Title size
                            fontWeight: FontWeight.w600,
                            color: darkTeal,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        _buildActionItem(
                          icon: Icons.email_outlined,
                          text: 'Contact our support team for assistance',
                        ),
                        
                        _buildActionItem(
                          icon: Icons.policy_outlined,
                          text: 'Review our terms of service and community guidelines',
                        ),
                        
                        _buildActionItem(
                          icon: Icons.schedule_outlined,
                          text: 'Wait for administrator review of your account',
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Contact support button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showContactSupportDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mediumSeaGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: Icon(Icons.support_agent, size: 20),
                      label: Text(
                        'Contact Support',
                        style: TextStyle(
                          fontSize: 13, // Title size
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Sign out button
                  TextButton(
                    onPressed: () async {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      await authProvider.signOut();
                      
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 11, // Body size
                        color: darkTeal.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Help text
                  Text(
                    'If you believe this is a mistake, please contact our support team immediately.',
                    style: TextStyle(
                      fontSize: 10,
                      color: darkTeal.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: mediumSeaGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: mediumSeaGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11, // Body size
                color: darkTeal.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.support_agent,
              color: mediumSeaGreen,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 16, // Max size
                fontWeight: FontWeight.bold,
                color: darkTeal,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Our support team is here to help you.',
              style: TextStyle(
                fontSize: 11, // Body size
                color: darkTeal.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            _buildContactOption(
              icon: Icons.email,
              label: 'Email',
              value: 'support@hanapbuhay.com',
            ),
            const SizedBox(height: 12),
            _buildContactOption(
              icon: Icons.access_time,
              label: 'Response Time',
              value: 'Within 24-48 hours',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Close',
              style: TextStyle(
                fontSize: 13, // Title size
                color: darkTeal.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: mediumSeaGreen),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: darkTeal.withValues(alpha: 0.6),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11, // Body size
                fontWeight: FontWeight.w600,
                color: darkTeal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

