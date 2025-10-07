import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/safe_snackbar.dart';
import '../login_screen.dart';
import 'home_screen.dart';

class EmployerApplicationStatusScreen extends StatefulWidget {
  const EmployerApplicationStatusScreen({super.key});

  @override
  State<EmployerApplicationStatusScreen> createState() => _EmployerApplicationStatusScreenState();
}

class _EmployerApplicationStatusScreenState extends State<EmployerApplicationStatusScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _verificationStatus;
  Map<String, dynamic>? _companyInfo;
  String? _error;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadApplicationStatus();
  }

  Future<void> _loadApplicationStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'No authenticated user found';
          _isLoading = false;
        });
        return;
      }

      // Load verification status
      final verificationResponse = await Supabase.instance.client
          .from('employer_verification')
          .select('*')
          .eq('employer_id', user.id)
          .maybeSingle();

      // Load company info
      final companyResponse = await Supabase.instance.client
          .from('companies')
          .select('name, about, created_at')
          .eq('owner_id', user.id)
          .maybeSingle();

      setState(() {
        _verificationStatus = verificationResponse;
        _companyInfo = companyResponse;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load application status: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      SafeSnackBar.showError(
        context,
        message: 'Failed to sign out: $e',
      );
    }
  }

  Widget _buildStatusCard() {
    if (_verificationStatus == null) {
      return _buildNoStatusCard();
    }

    final status = _verificationStatus!['verification_status'] as String?;
    final submittedAt = _verificationStatus!['created_at'] as String?;
    final adminNotes = _verificationStatus!['admin_notes'] as String?;
    final rejectionReason = _verificationStatus!['rejection_reason'] as String?;

    switch (status) {
      case 'pending':
        return _buildPendingCard(submittedAt, adminNotes);
      case 'approved':
        return _buildApprovedCard();
      case 'rejected':
        return _buildRejectedCard(rejectionReason);
      default:
        return _buildNoStatusCard();
    }
  }

  Widget _buildNoStatusCard() {
    return Container(
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
        children: [
          Icon(
            Icons.hourglass_empty,
            color: Colors.orange,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Application Not Found',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your employer application could not be found. Please contact support.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(String? submittedAt, String? adminNotes) {
    final submittedDate = submittedAt != null 
        ? DateTime.parse(submittedAt).toLocal()
        : null;

    return Container(
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
        children: [
          Icon(
            Icons.hourglass_empty,
            color: Colors.orange,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Application Under Review',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your employer application is currently being reviewed by our admin team.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          if (submittedDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightMint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: paleGreen.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: mediumSeaGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Submitted: ${_formatDate(submittedDate)}',
                    style: TextStyle(
                      color: darkTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (adminNotes != null && adminNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Admin Notes:',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    adminNotes,
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBDEFB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'What happens next?',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Our admin team will review your application within 1-3 business days\n• You will receive an email notification when your application is processed\n• Once approved, you can access your employer dashboard',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedCard() {
    return Container(
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
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Application Approved!',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Congratulations! Your employer account has been approved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to employer dashboard
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmployerHomeScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Go to Dashboard',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedCard(String? rejectionReason) {
    return Container(
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
        children: [
          Icon(
            Icons.cancel,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Application Rejected',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unfortunately, your employer application has been rejected.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Reason for rejection:',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rejectionReason,
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCC80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.support_agent, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Need help?',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'If you believe this was an error or would like to reapply, please contact our support team.',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatusContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: mediumSeaGreen),
            const SizedBox(height: 16),
            Text(
              'Loading application status...',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadApplicationStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return _buildStatusCard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Application Status',
          style: TextStyle(
            color: darkTeal,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: Icon(Icons.logout, color: darkTeal),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Employer Application',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track your application status and next steps',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // Company info if available
              if (_companyInfo != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: mediumSeaGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.business,
                          color: mediumSeaGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _companyInfo!['name'] ?? 'Company Name',
                              style: TextStyle(
                                color: darkTeal,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_companyInfo!['about'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _companyInfo!['about'],
                                style: TextStyle(
                                  color: darkTeal.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Status card
              Expanded(
                child: _buildStatusContent(),
              ),

              // Refresh button
              if (!_isLoading && _error == null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loadApplicationStatus,
                    icon: Icon(Icons.refresh, color: mediumSeaGreen),
                    label: Text(
                      'Refresh Status',
                      style: TextStyle(color: mediumSeaGreen),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: mediumSeaGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
  