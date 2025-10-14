import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class SystemAnalyticsScreen extends StatefulWidget {
  const SystemAnalyticsScreen({super.key});

  @override
  State<SystemAnalyticsScreen> createState() => _SystemAnalyticsScreenState();
}

class _SystemAnalyticsScreenState extends State<SystemAnalyticsScreen> {
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;

  // Color palette
  // Note: keep palette aligned across screens. Unused constants removed to satisfy lints.
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final analytics = await AdminService.getSystemAnalytics();
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: mediumSeaGreen),
      );
    }

    // Derived metrics from available schema data
    final loginAttempts = _analytics['login_attempts'] as List? ?? [];

    final totalLogins = loginAttempts.length;
    final successLogins = loginAttempts.where((a) => a['success'] == true).length;
    final successRate = totalLogins == 0 ? 0.0 : successLogins / totalLogins;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Cards
          Text(
            'System Overview',
            style: TextStyle(
              color: darkTeal,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Total Users',
                  value: '${_analytics['total_users'] ?? 0}',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Total Jobs',
                  value: '${_analytics['total_jobs'] ?? 0}',
                  icon: Icons.work,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Total Applications',
                  value: '${_analytics['total_applications'] ?? 0}',
                  icon: Icons.description,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Failed Logins',
                  value: '${_analytics['failed_logins'] ?? 0}',
                  icon: Icons.security,
                  color: Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // Login Success Rate
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Login Success Rate',
                  value: '${(successRate * 100).toStringAsFixed(0)}%',
                  icon: Icons.check_circle_outline,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Recent Activity
          Text(
            'Recent Activity',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildRecentActivityList(),
          
          const SizedBox(height: 32),
          
          // System Health
          Text(
            'System Health',
            style: TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSystemHealthCard(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  Widget _buildRecentActivityList() {
    final loginAttempts = _analytics['login_attempts'] as List? ?? [];
    
    if (loginAttempts.isEmpty) {
      return Container(
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
        child: Center(
          child: Text(
            'No recent activity',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
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
        children: loginAttempts.take(5).map((attempt) {
          final isSuccess = attempt['success'] == true;
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSuccess 
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red,
                size: 16,
              ),
            ),
            title: Text(
              isSuccess ? 'Successful Login' : 'Failed Login',
              style: TextStyle(
                color: darkTeal,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _formatDate(attempt['created_at']),
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSystemHealthCard() {
    return Container(
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
        children: [
          _buildHealthItem(
            label: 'Database',
            status: 'Healthy',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildHealthItem(
            label: 'Authentication',
            status: 'Healthy',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildHealthItem(
            label: 'AI Services',
            status: 'Healthy',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildHealthItem(
            label: 'Storage',
            status: 'Healthy',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthItem({
    required String label,
    required String status,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
