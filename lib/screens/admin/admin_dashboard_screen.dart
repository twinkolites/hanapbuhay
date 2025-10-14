import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/admin_service.dart';
import '../../utils/safe_snackbar.dart';
import '../login_screen.dart';
import 'employer_approval_screen.dart';
import 'user_management_screen.dart';
import 'system_analytics_screen.dart';
import 'dart:async';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  String? _adminName;
  bool _isLoading = true;
  bool _isRefreshing = false;
  
  // Statistics data
  int _totalUsers = 0;
  int _totalEmployers = 0;
  int _totalApplicants = 0;
  int _pendingApprovals = 0;
  int _totalJobs = 0;
  int _totalApplications = 0;
  int _activeJobs = 0;
  int _pendingApplications = 0;
  
  // Real-time data
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _adminActions = [];
  Map<String, dynamic> _systemStatus = {};
  Timer? _refreshTimer;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _animationController.forward();
    _initializeAdminData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAdminData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _adminName = user.userMetadata?['full_name'] ?? user.email;
      }
      
      // Load all dashboard data
      await Future.wait([
        _loadDashboardStats(),
        _loadRecentActivity(),
        _loadAdminActions(),
        _checkSystemStatus(),
      ]);
      
      // Set up auto-refresh timer (every 30 seconds)
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (mounted && _currentIndex == 0) {
          _refreshData();
        }
      });
      
    } catch (e) {
      debugPrint('Error initializing admin data: $e');
      SafeSnackBar.showError(
        context,
        message: 'Failed to load dashboard data: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await AdminService.getDashboardStats();
      if (mounted) {
        setState(() {
          _totalUsers = stats['total_users'] ?? 0;
          _totalEmployers = stats['total_employers'] ?? 0;
          _totalApplicants = stats['total_applicants'] ?? 0;
          _pendingApprovals = stats['pending_approvals'] ?? 0;
          _totalJobs = stats['total_jobs'] ?? 0;
          _totalApplications = stats['total_applications'] ?? 0;
          _activeJobs = stats['active_jobs'] ?? 0;
          _pendingApplications = stats['pending_applications'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      throw e; // Re-throw to be caught by caller
    }
  }

  Future<void> _loadRecentActivity() async {
    try {
      final analytics = await AdminService.getSystemAnalytics();
      if (mounted && analytics.isNotEmpty) {
        // Get recent user registrations
        final userGrowth = analytics['user_growth'] as List<dynamic>? ?? [];
        final recentUsers = userGrowth.take(3).map((user) => {
          'type': 'user_registration',
          'title': 'New User Registration',
          'subtitle': 'User joined the platform',
          'time': _formatTimeAgo(DateTime.parse(user['created_at'])),
          'icon': Icons.person_add,
          'color': Colors.green,
        }).toList();

        // Get recent job postings
        final jobTrends = analytics['job_trends'] as List<dynamic>? ?? [];
        final recentJobs = jobTrends.take(2).map((job) => {
          'type': 'job_posted',
          'title': 'New Job Posted',
          'subtitle': 'Job status: ${job['status']}',
          'time': _formatTimeAgo(DateTime.parse(job['created_at'])),
          'icon': Icons.work,
          'color': Colors.blue,
        }).toList();

        setState(() {
          _recentActivity = [...recentUsers, ...recentJobs];
        });
      }
    } catch (e) {
      debugPrint('Error loading recent activity: $e');
      // Don't throw - this is not critical
    }
  }

  Future<void> _loadAdminActions() async {
    try {
      final actions = await AdminService.getAdminActionsLog(limit: 5);
      if (mounted) {
        setState(() {
          _adminActions = actions;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin actions: $e');
      // Don't throw - this is not critical
    }
  }

  Future<void> _checkSystemStatus() async {
    try {
      // Test database connection
      final stats = await AdminService.getDashboardStats();
      final isDbOnline = stats.isNotEmpty;
      
      // Test Supabase auth
      final user = Supabase.instance.client.auth.currentUser;
      final isAuthOnline = user != null;
      
      setState(() {
        _systemStatus = {
          'database': isDbOnline ? 'Online' : 'Offline',
          'database_color': isDbOnline ? Colors.green : Colors.red,
          'auth': isAuthOnline ? 'Online' : 'Offline',
          'auth_color': isAuthOnline ? Colors.green : Colors.red,
          'storage': 'Online', // Assume online if we got this far
          'storage_color': Colors.green,
          'api': 'Online', // Assume online if we got this far
          'api_color': Colors.green,
        };
      });
    } catch (e) {
      debugPrint('Error checking system status: $e');
      setState(() {
        _systemStatus = {
          'database': 'Offline',
          'database_color': Colors.red,
          'auth': 'Offline',
          'auth_color': Colors.red,
          'storage': 'Unknown',
          'storage_color': Colors.orange,
          'api': 'Unknown',
          'api_color': Colors.orange,
        };
      });
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      await Future.wait([
        _loadDashboardStats(),
        _loadRecentActivity(),
        _loadAdminActions(),
        _checkSystemStatus(),
      ]);
      
      if (mounted) {
        SafeSnackBar.showSuccess(
          context,
          message: 'Dashboard data refreshed',
        );
      }
    } catch (e) {
      debugPrint('Error refreshing data: $e');
      if (mounted) {
        SafeSnackBar.showError(
          context,
          message: 'Failed to refresh data: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _logout() async {
    try {
      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();
      
      // Add a small delay to ensure auth state is cleared
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Navigate to login screen immediately without showing SnackBar
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      // Only show error if still mounted and before navigation
      if (mounted) {
        SafeSnackBar.showError(
          context,
          message: 'Error logging out: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: lightMint,
        appBar: AppBar(
          backgroundColor: mediumSeaGreen,
          foregroundColor: Colors.white,
          
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: mediumSeaGreen),
              const SizedBox(height: 16),
              Text(
                'Loading Admin Dashboard...',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        backgroundColor: mediumSeaGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentIndex == 0) // Only show refresh on dashboard
            IconButton(
              icon: _isRefreshing 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.refresh),
              onPressed: _isRefreshing ? null : _refreshData,
              tooltip: 'Refresh Data',
            ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _currentIndex == 0
                      ? _buildDashboardContent()
                      : _currentIndex == 1
                          ? const EmployerApprovalScreen()
                          : _currentIndex == 2
                              ? const UserManagementScreen()
                              : const SystemAnalyticsScreen(),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      color: darkTeal,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Welcome back, ${_adminName ?? 'Admin'}',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.admin_panel_settings,
                  color: mediumSeaGreen,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_currentIndex == 0) _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Users',
                value: _totalUsers.toString(),
                subtitle: '${_totalEmployers} employers, ${_totalApplicants} applicants',
                icon: Icons.people,
                color: mediumSeaGreen,
                onTap: () => setState(() => _currentIndex = 2), // Go to user management
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Pending Approvals',
                value: _pendingApprovals.toString(),
                subtitle: _pendingApprovals > 0 ? 'Action required' : 'All caught up',
                icon: Icons.pending_actions,
                color: _pendingApprovals > 0 ? Colors.orange : Colors.green,
                onTap: () => setState(() => _currentIndex = 1), // Go to approvals
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Active Jobs',
                value: _activeJobs.toString(),
                subtitle: '${_totalJobs} total jobs',
                icon: Icons.work,
                color: Colors.blue,
                onTap: () => setState(() => _currentIndex = 3), // Go to analytics
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Applications',
                value: _totalApplications.toString(),
                subtitle: '${_pendingApplications} pending',
                icon: Icons.description,
                color: Colors.purple,
                onTap: () => setState(() => _currentIndex = 3), // Go to analytics
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: onTap != null ? [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: mediumSeaGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recent Activity Section
            Text(
              'Recent Activity',
              style: TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildRecentActivityCard(),
            
            const SizedBox(height: 24),
            
            // Quick Actions Section
            Text(
              'Quick Actions',
              style: TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickActionsGrid(),
            
            const SizedBox(height: 24),
            
            // System Status Section
            Text(
              'System Status',
              style: TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSystemStatusCard(),
            
            const SizedBox(height: 24),
            
            // Admin Actions Section
            if (_adminActions.isNotEmpty) ...[
              Text(
                'Recent Admin Actions',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildAdminActionsCard(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isRefreshing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentActivity.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      color: darkTeal.withValues(alpha: 0.3),
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activity',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_recentActivity.asMap().entries.map((entry) {
              final index = entry.key;
              final activity = entry.value;
              return Column(
                children: [
                  _buildActivityItem(
                    icon: activity['icon'] as IconData,
                    title: activity['title'] as String,
                    subtitle: activity['subtitle'] as String,
                    time: activity['time'] as String,
                    color: activity['color'] as Color,
                  ),
                  if (index < _recentActivity.length - 1)
                    const Divider(height: 24),
                ],
              );
            }).toList()),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildActionCard(
          title: 'Approve Employers',
          icon: Icons.check_circle,
          color: Colors.green,
          onTap: () => setState(() => _currentIndex = 1),
        ),
        _buildActionCard(
          title: 'Manage Users',
          icon: Icons.people,
          color: Colors.blue,
          onTap: () => setState(() => _currentIndex = 2),
        ),
        _buildActionCard(
          title: 'View Analytics',
          icon: Icons.analytics,
          color: Colors.purple,
          onTap: () => setState(() => _currentIndex = 3),
        ),
        _buildActionCard(
          title: 'System Settings',
          icon: Icons.settings,
          color: Colors.grey,
          onTap: () {
            SafeSnackBar.showInfo(
              context,
              message: 'System Settings coming soon!',
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: darkTeal,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatusCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Status',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isRefreshing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusItem(
            label: 'Database',
            status: _systemStatus['database'] ?? 'Unknown',
            color: _systemStatus['database_color'] ?? Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildStatusItem(
            label: 'Authentication',
            status: _systemStatus['auth'] ?? 'Unknown',
            color: _systemStatus['auth_color'] ?? Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildStatusItem(
            label: 'Storage',
            status: _systemStatus['storage'] ?? 'Unknown',
            color: _systemStatus['storage_color'] ?? Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildStatusItem(
            label: 'API',
            status: _systemStatus['api'] ?? 'Unknown',
            color: _systemStatus['api_color'] ?? Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
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

  Widget _buildAdminActionsCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Admin Actions',
            style: TextStyle(
              color: darkTeal,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...(_adminActions.take(3).map((action) {
            final actionType = action['action_type'] as String? ?? 'Unknown';
            final adminName = action['profiles']?['full_name'] ?? 'Unknown Admin';
            final createdAt = action['created_at'] as String? ?? '';
            
            IconData icon;
            Color color;
            
            switch (actionType) {
              case 'employer_approval':
                icon = Icons.check_circle;
                color = Colors.green;
                break;
              case 'employer_rejection':
                icon = Icons.cancel;
                color = Colors.red;
                break;
              case 'user_suspension':
                icon = Icons.block;
                color = Colors.orange;
                break;
              default:
                icon = Icons.admin_panel_settings;
                color = Colors.blue;
            }
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildActivityItem(
                icon: icon,
                title: _formatActionType(actionType),
                subtitle: 'By $adminName',
                time: _formatTimeAgo(DateTime.parse(createdAt)),
                color: color,
              ),
            );
          }).toList()),
        ],
      ),
    );
  }

  String _formatActionType(String actionType) {
    switch (actionType) {
      case 'employer_approval':
        return 'Employer Approved';
      case 'employer_rejection':
        return 'Employer Rejected';
      case 'user_suspension':
        return 'User Suspended';
      case 'user_unsuspension':
        return 'User Unsuspended';
      default:
        return actionType.replaceAll('_', ' ').split(' ').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: mediumSeaGreen,
        unselectedItemColor: darkTeal.withValues(alpha: 0.5),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.approval),
            label: 'Approvals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
