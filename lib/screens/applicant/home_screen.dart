import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';
import 'profile_screen.dart';
import 'jobs_screen.dart';
import 'chat_screen.dart';
import 'apply_job_screen.dart';
import 'applications_screen.dart';
import 'saved_jobs_screen.dart';
import 'job_details_screen.dart';

// Using Supabase.instance.client directly instead of global variable

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  String? _displayName;
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  bool _isStatsLoading = true;
  Map<String, bool> _appliedJobs = {};
  Map<String, bool> _savedJobs = {};
  
  // Statistics data
  int _appliedCount = 0;
  int _savedCount = 0;
  int _interviewsCount = 0;
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
    
    _initializeApplicantData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh statistics when screen becomes active
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _initializeApplicantData() async {
    // Initialize user data
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.userMetadata != null) {
      _displayName = (user.userMetadata?['fullName'] as String?)?.trim();
      _displayName ??= user.email;
    }

    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      final u = event.session?.user;
      if (u != null) {
        final name =
            (u.userMetadata?['full_name'] as String?)?.trim() ?? u.email;
        if (name != _displayName) {
          setState(() => _displayName = name);
        }
      }
    });

    // Load available jobs and statistics
    await Future.wait([
      _loadJobs(),
      _loadStatistics(),
    ]);
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await JobService.getAllJobs();
      await _checkAppliedJobs(jobs);
      setState(() {
        _jobs = jobs;
      });
      
      // Update statistics after checking applied jobs to ensure consistency
      await _loadStatistics();
    } catch (e) {
      // Handle error silently for now
      setState(() {
        _jobs = [];
      });
    }
  }

  Future<void> _checkAppliedJobs(List<Map<String, dynamic>> jobs) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return;
      }

      final appliedJobs = <String, bool>{};
      final savedJobs = <String, bool>{};
      
      for (final job in jobs) {
        final jobId = job['id'];
        final hasApplied = await JobService.hasUserApplied(jobId, user.id);
        final isSaved = await JobService.isJobSaved(jobId, user.id);
        appliedJobs[jobId] = hasApplied;
        savedJobs[jobId] = isSaved;
      }

      setState(() {
        _appliedJobs = appliedJobs;
        _savedJobs = savedJobs;
      });
    } catch (e) {
      print('❌ Error checking applied jobs: $e');
    }
  }

  Future<void> _loadStatistics() async {
    int appliedCount = 0;
    int savedCount = 0;
    int interviewsCount = 0;
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return;
      }

      // Load applications count - simple count query for better performance
      try {
        final applicationsResponse = await Supabase.instance.client
            .from('job_applications')
            .select('id, status, created_at')
            .eq('applicant_id', user.id);
        
        appliedCount = applicationsResponse.length;
      } catch (e) {
        print('❌ Error loading applications: $e');
        appliedCount = 0;
      }

      // Load saved jobs count
      try {
        final savedJobsResponse = await Supabase.instance.client
            .from('saved_jobs')
            .select('seeker_id, job_id')
            .eq('seeker_id', user.id);
        
        savedCount = savedJobsResponse.length;
      } catch (e) {
        print('❌ Error loading saved jobs: $e');
        savedCount = 0;
      }

      // Load interviews count (applications with status 'interviewed')
      try {
        final interviewsResponse = await Supabase.instance.client
            .from('job_applications')
            .select('id, status')
            .eq('applicant_id', user.id)
            .eq('status', 'interviewed');
        
        interviewsCount = interviewsResponse.length;
      } catch (e) {
        print('❌ Error loading interviews: $e');
        interviewsCount = 0;
      }

      setState(() {
        _appliedCount = appliedCount;
        _savedCount = savedCount;
        _interviewsCount = interviewsCount;
        _isStatsLoading = false;
      });


    } catch (e) {
      print('❌ Error loading statistics: $e');
      print('❌ Error details: ${e.toString()}');
      setState(() {
        _appliedCount = appliedCount;
        _savedCount = savedCount;
        _interviewsCount = interviewsCount;
        _isStatsLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadJobs(),
      _loadStatistics(),
    ]);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      body: SafeArea(
        child: Column(
          children: [
            _buildPremiumHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _buildMainContent(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildPremiumBottomNav(),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Top row with greeting and actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Greeting section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good morning',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayName ?? 'User',
                      style: const TextStyle(
                        color: darkTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Action buttons
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.notifications_outlined,
                    onTap: () {
                      // TODO: Implement notifications
                    },
                    badge: true,
                  ),
                  const SizedBox(width: 12),
                  _buildProfileAvatar(),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Consolidated stats card
          _buildConsolidatedStatCard(),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
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
        child: Stack(
          children: [
            Center(
              child: Icon(
                icon,
                color: darkTeal,
                size: 20,
              ),
            ),
            if (badge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showApplicationsScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ApplicantApplicationsScreen(),
      ),
    );
  }





  Widget _buildConsolidatedStatCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            mediumSeaGreen.withValues(alpha: 0.1),
            paleGreen.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mediumSeaGreen.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: mediumSeaGreen.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main applications card
          GestureDetector(
            onTap: () => _showApplicationsScreen(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.work_outline,
                    color: mediumSeaGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Applications',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track your job applications',
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _isStatsLoading ? '...' : '$_appliedCount',
                      style: TextStyle(
                        color: mediumSeaGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Applied',
                      style: TextStyle(
                        color: mediumSeaGreen.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Saved jobs row
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedJobsScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: paleGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bookmark,
                    color: mediumSeaGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Saved Jobs',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$_savedCount',
                    style: TextStyle(
                      color: mediumSeaGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: darkTeal.withValues(alpha: 0.5),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileScreen(),
          ),
        );
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [mediumSeaGreen, darkTeal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: mediumSeaGreen.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }



  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recommended Jobs',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JobsScreen(),
                    ),
                  );
                },
                child: Text(
                  'See All',
                  style: TextStyle(
                    color: mediumSeaGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Search bar
          _buildSearchBar(),
          
          const SizedBox(height: 20),
          
          // Job cards
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: mediumSeaGreen,
                    ),
                  )
                : _jobs.isEmpty
                    ? _buildEmptyState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: RefreshIndicator(
                            onRefresh: _refreshData,
                            color: mediumSeaGreen,
                            child: ListView.builder(
                              itemCount: _jobs.length,
                              itemBuilder: (context, index) {
                                final job = _jobs[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildPremiumJobCard(job),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          Icon(
            Icons.search,
            color: darkTeal.withValues(alpha: 0.6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search jobs, companies...',
                hintStyle: TextStyle(
                  color: darkTeal.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: mediumSeaGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.tune,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.work_outline,
            size: 80,
            color: darkTeal.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Jobs Available',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new opportunities',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumJobCard(Map<String, dynamic> job) {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: paleGreen.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: darkTeal.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Company logo
              Container(
                width: 50,
                height: 50,
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
                child: Center(
                  child: Text(
                    (job['companies']?['name'] ?? 'Company').substring(0, 1),
                    style: TextStyle(
                      color: mediumSeaGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Job info
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job['companies']?['name'] ?? 'Company',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bookmark button
              GestureDetector(
                onTap: () => _toggleSaveJob(job['id']),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lightMint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _savedJobs[job['id']] == true 
                        ? Icons.bookmark 
                        : Icons.bookmark_border,
                    color: mediumSeaGreen,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Location and salary
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: darkTeal.withValues(alpha: 0.6),
                size: 16,
              ),
              const SizedBox(width: 4),
                                      Text(
                          job['location'] ?? 'Location not specified',
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
              const Spacer(),
                              Text(
                  _formatSalaryRange(job['salary_min'], job['salary_max']),
                  style: const TextStyle(
                    color: mediumSeaGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Tags
          Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: mediumSeaGreen.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  _formatJobTypeDisplay(job['type'] ?? 'full_time'),
                  style: TextStyle(
                    color: mediumSeaGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          _appliedJobs[job['id']] == true
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: mediumSeaGreen,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: mediumSeaGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Applied',
                        style: TextStyle(
                          color: mediumSeaGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    // View Details button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _navigateToJobDetails(job);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: darkTeal,
                          side: BorderSide(
                            color: mediumSeaGreen.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Apply Now button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _navigateToApplyJob(job);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mediumSeaGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply Now',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildPremiumBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0),
              _buildNavItem(Icons.work_rounded, 'Jobs', 1),
              _buildNavItem(Icons.chat_rounded, 'Chat', 2),
              _buildNavItem(Icons.work_outline, 'Applications', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        if (index == 1) {
          // Navigate to jobs screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const JobsScreen(),
            ),
          );
        } else if (index == 2) {
          // Navigate to chat screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChatScreen(),
            ),
          );
        } else if (index == 3) {
          // Navigate to applications screen
          _showApplicationsScreen();
        } else {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? mediumSeaGreen.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? mediumSeaGreen : darkTeal.withValues(alpha: 0.6),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? mediumSeaGreen : darkTeal.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSalaryRange(int? min, int? max) {
    if (min != null && max != null) {
      return '₱${_formatNumber(min)} - ₱${_formatNumber(max)}';
    } else if (min != null) {
      return '₱${_formatNumber(min)}+';
    } else if (max != null) {
      return 'Up to ₱${_formatNumber(max)}';
    }
    return 'Salary negotiable';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toString();
  }

  String _formatJobTypeDisplay(String type) {
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

  Future<void> _toggleSaveJob(String jobId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final isSaved = await JobService.toggleSaveJob(jobId, user.id);
      
      setState(() {
        _savedJobs[jobId] = isSaved;
      });

      // Update saved count in statistics
      await _loadStatistics();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSaved ? 'Job saved!' : 'Job removed from saved'),
          backgroundColor: mediumSeaGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update saved job'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToApplyJob(Map<String, dynamic> job) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyJobScreen(job: job),
      ),
    );
    
    if (result == true) {
      // Force refresh statistics first to ensure immediate update
      await _loadStatistics();
      
      // Then reload jobs and check applied status
      await _loadJobs();
    }
  }

  void _navigateToJobDetails(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailsScreen(job: job),
      ),
    );
  }
}
