import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import 'enhanced_edit_company_screen.dart';
import 'edit_profile_screen.dart';
import 'edit_job_screen.dart';
import 'applications_screen.dart';

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
    final stopwatch = Stopwatch()..start();
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Check cache validity (30 seconds cache)
      final now = DateTime.now();
      if (_lastDataLoad != null && 
          now.difference(_lastDataLoad!).inSeconds < 30) {
        debugPrint('Profile data loaded from cache (${stopwatch.elapsedMilliseconds}ms)');
        return; // Use cached data
      }

      debugPrint('Loading profile data from database...');
      
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
        final jobsData = profileData['jobs_data'] as Map<String, dynamic>?;
        final jobsList = jobsData?['jobs'] as List<dynamic>?;
        final jobs = jobsList != null 
            ? List<Map<String, dynamic>>.from(jobsList)
            : <Map<String, dynamic>>[];

        // Parse statistics
        final statistics = profileData['statistics'] as Map<String, dynamic>?;
        final jobsStats = statistics?['jobs_stats'] as Map<String, dynamic>?;
        final applicationsStats = statistics?['applications_stats'] as Map<String, dynamic>?;

        if (mounted) {
          setState(() {
            _userProfile = userProfileData;
            _company = companyData;
            _jobs = jobs;
            _isLoading = false;
            _lastDataLoad = now; // Update cache timestamp
            
            // Store statistics for quick access
            if (jobsStats != null) {
              _userProfile?['total_jobs'] = jobsStats['total_jobs'];
              _userProfile?['active_jobs'] = jobsStats['active_jobs'];
            }
            if (applicationsStats != null) {
              _userProfile?['total_applications'] = applicationsStats['total_applications'];
              _userProfile?['unique_applicants'] = applicationsStats['unique_applicants'];
            }
          });
          
          stopwatch.stop();
          debugPrint('Profile data loaded successfully (${stopwatch.elapsedMilliseconds}ms)');
          
          // Load additional data in background for better UX
          _loadAdditionalData();
        }
      } else {
        // Fallback to original method if procedure fails
        debugPrint('Stored procedure returned empty result, using fallback');
        await _loadProfileDataFallback();
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      stopwatch.stop();
      debugPrint('Profile data load failed after ${stopwatch.elapsedMilliseconds}ms');
      
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
        // Only get jobs from jobs table (not archived)
        final jobsResponse = await supabase
            .from('jobs')
            .select('*')
            .eq('company_id', company['id'])
            .order('created_at', ascending: false);
        
        jobs = List<Map<String, dynamic>>.from(jobsResponse);
        
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
    // Get company details if company exists
    Map<String, dynamic>? companyDetails;
    if (_company != null) {
      try {
        final response = await supabase
            .from('company_details')
            .select('*')
            .eq('company_id', _company!['id'])
            .maybeSingle();
        companyDetails = response;
      } catch (e) {
        debugPrint('Error fetching company details: $e');
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedEditCompanyScreen(
          company: _company,
          companyDetails: companyDetails,
        ),
      ),
    );
    
    if (result == true) {
      // Invalidate cache and reload data if company was updated
      await _invalidateCache();
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
        // Invalidate cache and reload data if profile was updated
        await _invalidateCache();
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

  // Force refresh data (bypass cache)
  Future<void> forceRefreshProfileData() async {
    _lastDataLoad = null; // Clear cache
    await _loadProfileData();
  }

  // Load additional data in batches for better performance
  Future<void> _loadAdditionalData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Load recent jobs with application counts
      final recentJobsResponse = await supabase.rpc('get_employer_recent_jobs', params: {
        'user_uuid': user.id,
        'limit_count': 10,
      });

      // Load company statistics
      final statsResponse = await supabase.rpc('get_company_statistics', params: {
        'user_uuid': user.id,
      });

      if (mounted) {
        setState(() {
          // Update jobs with additional data
          if (recentJobsResponse is List) {
            final recentJobs = List<Map<String, dynamic>>.from(recentJobsResponse);
            // Merge with existing jobs data
            for (final recentJob in recentJobs) {
              final existingJobIndex = _jobs.indexWhere((job) => job['id'] == recentJob['id']);
              if (existingJobIndex != -1) {
                _jobs[existingJobIndex].addAll(recentJob);
              }
            }
          }

          // Update statistics
          if (statsResponse is List && statsResponse.isNotEmpty) {
            final stats = statsResponse.first;
            _userProfile?['total_jobs'] = stats['total_jobs'];
            _userProfile?['active_jobs'] = stats['active_jobs'];
            _userProfile?['total_applications'] = stats['total_applications'];
            _userProfile?['unique_applicants'] = stats['unique_applicants'];
            _userProfile?['avg_applications_per_job'] = stats['avg_applications_per_job'];
            _userProfile?['recent_applications'] = stats['recent_applications'];
            _userProfile?['job_types_distribution'] = stats['job_types_distribution'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading additional data: $e');
    }
  }

  // Invalidate cache when data changes
  Future<void> _invalidateCache() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.rpc('invalidate_employer_cache', params: {
          'user_uuid': user.id,
        });
        _lastDataLoad = null; // Clear local cache
      }
    } catch (e) {
      debugPrint('Error invalidating cache: $e');
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
    return RefreshIndicator(
      onRefresh: forceRefreshProfileData,
      color: mediumSeaGreen,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
            child: TextButton.icon(
              onPressed: _showAllJobsModal,
              icon: const Icon(Icons.list_alt, size: 16),
              label: Text(
                'View All Jobs (${_jobs.length})',
                style: TextStyle(
                  color: mediumSeaGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: mediumSeaGreen,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final applicationsCount = job['applications_count'] as int? ?? 0;
    final isActive = job['status'] == 'open';
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showJobDetailsModal(job),
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: darkTeal.withValues(alpha: 0.6),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                job['location'] ?? 'Location not specified',
                                style: TextStyle(
                                  color: darkTeal.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive 
                        ? mediumSeaGreen.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Closed',
                      style: TextStyle(
                        color: isActive ? mediumSeaGreen : Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
              
              // Salary and applications row
              Row(
                children: [
                  if (job['salary_min'] != null || job['salary_max'] != null) ...[
                    Icon(
                      Icons.payments_outlined,
                      color: mediumSeaGreen,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatSalary(job['salary_min'], job['salary_max']),
                      style: TextStyle(
                        color: mediumSeaGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(
                    Icons.people_outline,
                    color: darkTeal.withValues(alpha: 0.6),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$applicationsCount application${applicationsCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: darkTeal.withValues(alpha: 0.4),
                    size: 12,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSalary(int? min, int? max) {
    if (min != null && max != null) {
      return '₱${_formatNumber(min)}-${_formatNumber(max)}';
    } else if (min != null) {
      return '₱${_formatNumber(min)}+';
    } else if (max != null) {
      return 'Up to ₱${_formatNumber(max)}';
    }
    return 'Negotiable';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toString();
  }

  void _showJobDetailsModal(Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: darkTeal.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['title'] ?? 'Untitled Job',
                          style: const TextStyle(
                            color: darkTeal,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: mediumSeaGreen,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              job['location'] ?? 'Location not specified',
                              style: TextStyle(
                                color: darkTeal.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: darkTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: darkTeal,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Job details content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status and stats
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: job['status'] == 'open' 
                              ? mediumSeaGreen.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                job['status'] == 'open' ? Icons.circle : Icons.circle_outlined,
                                color: job['status'] == 'open' ? mediumSeaGreen : Colors.grey,
                                size: 8,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                job['status'] == 'open' ? 'Active' : 'Closed',
                                style: TextStyle(
                                  color: job['status'] == 'open' ? mediumSeaGreen : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: paleGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: mediumSeaGreen,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${job['applications_count'] ?? 0} applications',
                                style: TextStyle(
                                  color: mediumSeaGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Salary
                    if (job['salary_min'] != null || job['salary_max'] != null) ...[
                      _buildDetailRow(
                        'Salary Range',
                        _formatSalary(job['salary_min'], job['salary_max']),
                        Icons.payments_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Experience level
                    if (job['experience_level'] != null && job['experience_level'].toString().isNotEmpty) ...[
                      _buildDetailRow(
                        'Experience Level',
                        job['experience_level'],
                        Icons.school_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Job type
                    _buildDetailRow(
                      'Job Type',
                      _formatJobType(job['type']),
                      Icons.work_outline,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Description
                    const Text(
                      'Job Description',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightMint.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: paleGreen.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        job['description'] ?? 'No description available',
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.8),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _navigateToEditJob(job);
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text(
                              'Edit Job',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: mediumSeaGreen,
                              side: BorderSide(color: mediumSeaGreen),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _navigateToApplications(job);
                            },
                            icon: const Icon(Icons.people_outline, size: 16),
                            label: const Text(
                              'Applications',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mediumSeaGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
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
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: mediumSeaGreen,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: darkTeal,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatJobType(String? type) {
    if (type == null) return 'Full Time';
    
    switch (type) {
      case 'full_time':
        return 'Full Time';
      case 'part_time':
        return 'Part Time';
      case 'contract':
        return 'Contract';
      case 'temporary':
        return 'Temporary';
      case 'internship':
        return 'Internship';
      case 'remote':
        return 'Remote';
      default:
        return type.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  void _navigateToEditJob(Map<String, dynamic> job) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditJobScreen(job: job),
      ),
    );
    
    if (result == true) {
      // Reload profile data after editing
      await forceRefreshProfileData();
    }
  }

  void _navigateToApplications(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplicationsScreen(job: job),
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

  void _showAllJobsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: darkTeal.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: mediumSeaGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.work_outline,
                      color: mediumSeaGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'All Job Postings',
                          style: TextStyle(
                            color: darkTeal,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_jobs.length} total jobs',
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: darkTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: darkTeal,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Jobs list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _jobs.length,
                itemBuilder: (context, index) {
                  final job = _jobs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildJobCard(job),
                  );
                },
              ),
            ),
          ],
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
