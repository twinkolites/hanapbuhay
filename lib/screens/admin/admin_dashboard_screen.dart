import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/admin_service.dart';
import '../../utils/safe_snackbar.dart';
import '../login_screen.dart';
import 'employer_approval_screen.dart';
import 'user_management_screen.dart';
import 'system_analytics_screen.dart';

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
  
  // Statistics data
  int _totalUsers = 0;
  int _totalEmployers = 0;
  int _totalApplicants = 0;
  int _pendingApprovals = 0;
  int _totalJobs = 0;
  int _totalApplications = 0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
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
    super.dispose();
  }

  Future<void> _initializeAdminData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _adminName = user.userMetadata?['full_name'] ?? user.email;
      }
      
      // Load dashboard statistics
      await _loadDashboardStats();
      
    } catch (e) {
      debugPrint('Error initializing admin data: $e');
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
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
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
        
        actions: [
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
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Users',
            value: _totalUsers.toString(),
            icon: Icons.people,
            color: mediumSeaGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Pending Approvals',
            value: _pendingApprovals.toString(),
            icon: Icons.pending_actions,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Total Jobs',
            value: _totalJobs.toString(),
            icon: Icons.work,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
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
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
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
        ],
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
        children: [
          _buildActivityItem(
            icon: Icons.person_add,
            title: 'New Employer Registration',
            subtitle: 'Company ABC registered',
            time: '2 hours ago',
            color: Colors.green,
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.work,
            title: 'New Job Posted',
            subtitle: 'Software Engineer at XYZ Corp',
            time: '4 hours ago',
            color: Colors.blue,
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.pending_actions,
            title: 'Pending Approval',
            subtitle: 'DEF Company verification',
            time: '6 hours ago',
            color: Colors.orange,
          ),
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
        children: [
          _buildStatusItem(
            label: 'Database',
            status: 'Online',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildStatusItem(
            label: 'AI Services',
            status: 'Online',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildStatusItem(
            label: 'Email Service',
            status: 'Online',
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildStatusItem(
            label: 'Storage',
            status: 'Online',
            color: Colors.green,
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
