import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import 'edit_company_screen.dart';
import 'edit_profile_screen.dart';

final supabase = Supabase.instance.client;

class EmployerProfileScreen extends StatefulWidget {
  const EmployerProfileScreen({super.key});

  @override
  State<EmployerProfileScreen> createState() => _EmployerProfileScreenState();
}

class _EmployerProfileScreenState extends State<EmployerProfileScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _company;
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  
  // Cache timestamp to prevent unnecessary reloads
  DateTime? _lastDataLoad;
  
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
    
    _loadProfileData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Use optimized stored procedure to get all employer data in one query
      final response = await supabase.rpc('get_employer_profile_data', params: {
        'user_uuid': user.id,
      });

      if (response is List && response.isNotEmpty) {
        final profileData = response.first;
        
        // Parse user profile
        final userProfileData = profileData['user_profile'] as Map<String, dynamic>?;
        
        // Parse company data
        final companyData = profileData['company_data'] as Map<String, dynamic>?;
        
        // Parse jobs data
        final jobsData = profileData['jobs_data'] as List<dynamic>?;
        final jobs = jobsData != null 
            ? List<Map<String, dynamic>>.from(jobsData)
            : <Map<String, dynamic>>[];

        setState(() {
          _userProfile = userProfileData;
          _company = companyData;
          _jobs = jobs;
          _isLoading = false;
          _lastDataLoad = DateTime.now(); // Cache timestamp
        });
      } else {
        // Fallback to original method if procedure fails
        await _loadProfileDataFallback();
      }
    } catch (e) {
      // Fallback to original method if procedure fails
      await _loadProfileDataFallback();
    }
  }

  Future<void> _loadProfileDataFallback() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Load user profile
      final profileResponse = await supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .single();
      
      // Load company data
      final company = await JobService.getUserCompany(user.id);
      
      // Load jobs if company exists
      List<Map<String, dynamic>> jobs = [];
      if (company != null) {
        jobs = await JobService.getJobsByCompany(company['id']);
        
        // Fetch application counts for each job
        for (int i = 0; i < jobs.length; i++) {
          final applications = await JobService.getJobApplications(jobs[i]['id']);
          jobs[i]['applications_count'] = applications.length;
        }
      }

      setState(() {
        _userProfile = profileResponse;
        _company = company;
        _jobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _navigateToEditCompany() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCompanyScreen(company: _company),
      ),
    );
    
    if (result == true) {
      // Reload data if company was updated
      await _loadProfileData();
    }
  }

  void _navigateToEditProfile() async {
    if (_userProfile != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfileScreen(profile: _userProfile!),
        ),
      );
      
      if (result == true) {
        // Reload data if profile was updated
        await _loadProfileData();
      }
    }
  }

  // Method to refresh data when needed (e.g., when returning from other screens)
  Future<void> refreshProfileData() async {
    final now = DateTime.now();
    if (_lastDataLoad == null || now.difference(_lastDataLoad!).inSeconds > 30) {
      await _loadProfileData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _navigateToEditProfile,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: darkTeal.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit,
                color: darkTeal,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: mediumSeaGreen,
                    ),
                  )
                : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          _buildProfileHeader(),
          
          const SizedBox(height: 32),
          
          // Statistics Cards
          _buildStatisticsCards(),
          
          const SizedBox(height: 32),
          
          // Company Section
          _buildCompanySection(),
          
          const SizedBox(height: 32),
          
          // Recent Jobs
          _buildRecentJobs(),
          
          const SizedBox(height: 32),
          
          // Settings Section
          _buildSettingsSection(),
          
          const SizedBox(height: 16),
          
          // Logout Section
          _buildLogoutSection(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          // Profile Picture
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mediumSeaGreen.withValues(alpha: 0.1),
                  paleGreen.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: mediumSeaGreen,
                width: 3,
              ),
            ),
            child: _userProfile?['avatar_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(47),
                    child: Image.network(
                      _userProfile!['avatar_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildProfilePlaceholder();
                      },
                    ),
                  )
                : _buildProfilePlaceholder(),
          ),
          
          const SizedBox(height: 16),
          
          // Name and Email
          Text(
            _userProfile?['full_name'] ?? 'Employer',
            style: const TextStyle(
              color: darkTeal,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            _userProfile?['email'] ?? '',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: mediumSeaGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: mediumSeaGreen,
                width: 1,
              ),
            ),
            child: Text(
              'Employer',
              style: TextStyle(
                color: mediumSeaGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildProfilePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.person,
          size: 40,
          color: darkTeal.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          'Profile',
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    final totalJobs = _jobs.length;
    final activeJobs = _jobs.where((job) => job['status'] == 'open').length;
    final totalApplications = _jobs.fold<int>(0, (sum, job) => sum + ((job['applications_count'] as int?) ?? 0));
    final avgApplicationsPerJob = totalJobs > 0 ? (totalApplications / totalJobs).toStringAsFixed(1) : '0.0';

    return Column(
      children: [
        // First row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Jobs',
                totalJobs.toString(),
                Icons.work,
                mediumSeaGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active Jobs',
                activeJobs.toString(),
                Icons.check_circle,
                paleGreen,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Second row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Applications',
                totalApplications.toString(),
                Icons.people,
                darkTeal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Avg per Job',
                avgApplicationsPerJob,
                Icons.trending_up,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompanySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Company',
              style: TextStyle(
                color: darkTeal,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _navigateToEditCompany,
              icon: const Icon(
                Icons.edit,
                color: mediumSeaGreen,
                size: 18,
              ),
              label: Text(
                _company != null ? 'Edit' : 'Create',
                style: const TextStyle(
                  color: mediumSeaGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        if (_company != null)
          _buildCompanyCard()
        else
          _buildNoCompanyCard(),
      ],
    );
  }

  Widget _buildCompanyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: lightMint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paleGreen,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Company Logo
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mediumSeaGreen.withValues(alpha: 0.1),
                  paleGreen.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _company!['logo_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _company!['logo_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            (_company!['name'] ?? 'C').substring(0, 1),
                            style: TextStyle(
                              color: mediumSeaGreen,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Text(
                      (_company!['name'] ?? 'C').substring(0, 1),
                      style: TextStyle(
                        color: mediumSeaGreen,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          
          const SizedBox(width: 16),
          
          // Company Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _company!['name'] ?? 'Company Name',
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _company!['about'] ?? 'No description available',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _company!['is_public'] == true ? Icons.visibility : Icons.visibility_off,
                      color: mediumSeaGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _company!['is_public'] == true ? 'Public' : 'Private',
                      style: TextStyle(
                        color: mediumSeaGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCompanyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: lightMint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paleGreen,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.business,
            size: 48,
            color: darkTeal.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Company Profile',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a company profile to start posting jobs',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _navigateToEditCompany,
            style: ElevatedButton.styleFrom(
              backgroundColor: mediumSeaGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Create Company',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentJobs() {
    if (_jobs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Posted Jobs',
          style: TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        ..._jobs.take(3).map((job) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildJobCard(job),
        )),
        
        if (_jobs.length > 3)
          Center(
            child: TextButton(
              onPressed: () {
                // TODO: Navigate to jobs list
              },
              child: Text(
                'View All Jobs (${_jobs.length})',
                style: TextStyle(
                  color: mediumSeaGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final applicationsCount = job['applications_count'] as int? ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['title'] ?? 'Untitled Job',
                      style: const TextStyle(
                        color: darkTeal,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job['location'] ?? 'Location not specified',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: job['status'] == 'open' 
                    ? mediumSeaGreen.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  job['status'] == 'open' ? 'Active' : 'Closed',
                  style: TextStyle(
                    color: job['status'] == 'open' ? mediumSeaGreen : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Application count
          Row(
            children: [
              Icon(
                Icons.people_outline,
                color: mediumSeaGreen,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '$applicationsCount application${applicationsCount == 1 ? '' : 's'}',
                style: TextStyle(
                  color: mediumSeaGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        _buildSettingItem(
          icon: Icons.notifications,
          title: 'Notifications',
          subtitle: 'Manage your notification preferences',
          onTap: () {
            // TODO: Navigate to notifications settings
          },
        ),
        
        _buildSettingItem(
          icon: Icons.security,
          title: 'Privacy & Security',
          subtitle: 'Manage your account security',
          onTap: () {
            // TODO: Navigate to privacy settings
          },
        ),
        
        _buildSettingItem(
          icon: Icons.help,
          title: 'Help & Support',
          subtitle: 'Get help and contact support',
          onTap: () {
            // TODO: Navigate to help screen
          },
        ),
        
        _buildSettingItem(
          icon: Icons.info,
          title: 'About',
          subtitle: 'App version and information',
          onTap: () {
            // TODO: Navigate to about screen
          },
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lightMint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: mediumSeaGreen,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: darkTeal,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: darkTeal.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showLogoutConfirmation,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.red.shade600,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sign out of your account',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.red.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: darkTeal, fontSize: 11),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: darkTeal.withValues(alpha: 0.7), fontSize: 11),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
