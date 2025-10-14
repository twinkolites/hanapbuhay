import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';
import '../../services/onesignal_notification_service.dart';
import 'post_job_screen.dart';
import 'edit_job_screen.dart';
import 'edit_company_screen.dart';
import 'profile_screen.dart';
import 'applications_screen.dart';
import 'applications_overview_screen.dart';
import 'chat_list_screen.dart';
import 'calendar_screen.dart';
import '../notifications_screen.dart';

class EmployerHomeScreen extends StatefulWidget {
  const EmployerHomeScreen({super.key});

  @override
  State<EmployerHomeScreen> createState() => _EmployerHomeScreenState();
}

class _EmployerHomeScreenState extends State<EmployerHomeScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _jobs = [];
  Map<String, dynamic>? _company;
  bool _isLoading = true;
  String? _displayName;
  int _currentIndex = 0;
  int _totalApplications = 0;
  Map<String, dynamic>? _deletedJob;
  Timer? _undoTimer;
  int _unreadNotificationCount = 0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Safe references to inherited widgets
  ScaffoldMessengerState? _scaffoldMessenger;
  NavigatorState? _navigator;

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
    
    _initializeEmployerData();
    
    // Show login success toast
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLoginSuccessToast();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely capture references to inherited widgets
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    _navigator = Navigator.maybeOf(context);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _undoTimer?.cancel();
    
    // Clear references to inherited widgets
    _scaffoldMessenger = null;
    _navigator = null;
    
    super.dispose();
  }

  // Show login success toast
  void _showLoginSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Login successful! Welcome back, ${_displayName ?? 'Employer'}!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: mediumSeaGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _initializeEmployerData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _displayName = user.userMetadata?['full_name'] ?? user.email;
      
      // Prefer RPC used in profile (RLS-safe) to fetch company, then fallback
      try {
        final rpc = await Supabase.instance.client
            .rpc('get_employer_profile_data', params: {
          'user_uuid': user.id,
        });

        if (rpc is List && rpc.isNotEmpty) {
          final data = rpc.first as Map<String, dynamic>;
          final companyData = data['company_data'] as Map<String, dynamic>?;
          if (companyData != null) {
            _company = companyData;
          }
        }
      } catch (e) {
        debugPrint('Error fetching company via RPC: $e');
      }

      // Fallbacks
      _company ??= await JobService.getUserCompany(user.id);
      _company ??= await JobService.createCompany(
        ownerId: user.id,
        name: '$_displayName\'s Company',
        about: 'Professional services company',
      );
      
      // Load jobs, applications, and notifications
      if (_company != null) {
        await Future.wait([
          _loadJobs(),
          _loadApplicationsCount(),
          _loadNotificationCount(),
        ]);
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadJobs() async {
    if (_company != null) {
      final jobs = await JobService.getJobsByCompany(_company!['id']);
      if (mounted) {
        setState(() {
          _jobs = jobs;
        });
      }
    }
  }

  Future<void> _loadApplicationsCount() async {
    if (_company != null) {
      int totalApplications = 0;
      // Get jobs first to ensure we have the job list
      final jobs = await JobService.getJobsByCompany(_company!['id']);
      for (final job in jobs) {
        final applications = await JobService.getJobApplications(job['id']);
        totalApplications += applications.length;
      }
      if (mounted) {
        setState(() {
          _totalApplications = totalApplications;
        });
      }
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final count = await OneSignalNotificationService.getUnreadCount(user.id);
        if (mounted) {
          setState(() {
            _unreadNotificationCount = count;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading notification count: $e');
    }
  }


  void _navigateToPostJob() async {
    if (_company != null && _navigator != null) {
      final result = await _navigator!.push(
        MaterialPageRoute(
          builder: (context) => PostJobScreen(company: _company!),
        ),
      );
      
      // Always reset to home tab after returning
      if (mounted) {
        setState(() {
          _currentIndex = 0;
        });
      }
      
      if (result == true) {
        // Reload jobs and applications count after posting
        await _loadJobs();
        await _loadApplicationsCount();
      }
    }
  }

  void _navigateToAllJobsAnalytics() async {
    if (_navigator != null) {
      await _navigator!.push(
        MaterialPageRoute(
          builder: (context) => const ApplicationsOverviewScreen(),
        ),
      );
      
      // Reset to home tab after returning
      if (mounted) {
        setState(() {
          _currentIndex = 0;
        });
      }
    }
  }

  void _navigateToActiveJobs() async {
    if (_navigator != null) {
      // Show a filtered view of only active jobs
      final activeJobs = _jobs.where((job) => job['status'] == 'open').toList();
      
      if (activeJobs.isEmpty) {
        // Show message if no active jobs
        if (mounted && _scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: const Text('No active jobs found. Post a new job to get started!'),
              backgroundColor: mediumSeaGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              action: SnackBarAction(
                label: 'POST JOB',
                textColor: Colors.white,
                onPressed: _navigateToPostJob,
              ),
            ),
          );
        }
        return;
      }
      
      await _navigator!.push(
        MaterialPageRoute(
          builder: (context) => const ApplicationsOverviewScreen(),
        ),
      );
      
      // Reset to home tab after returning
      if (mounted) {
        setState(() {
          _currentIndex = 0;
        });
      }
    }
  }

  void _navigateToApplicationsOverview() async {
    if (_navigator != null) {
      if (_totalApplications == 0) {
        // Show helpful message if no applications
        if (mounted && _scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: const Text('No applications yet. Share your job postings to attract candidates!'),
              backgroundColor: paleGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      await _navigator!.push(
        MaterialPageRoute(
          builder: (context) => const ApplicationsOverviewScreen(),
        ),
      );
      
      // Reset to home tab after returning
      if (mounted) {
        setState(() {
          _currentIndex = 0;
        });
      }
    }
  }

  void _navigateToCompanyProfile() async {
    if (_navigator != null && _company != null) {
      await _navigator!.push(
        MaterialPageRoute(
          builder: (context) => EditCompanyScreen(company: _company!),
        ),
      );
      
      // Reset to home tab after returning
      if (mounted) {
        setState(() {
          _currentIndex = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: lightMint,
        body: const Center(
          child: CircularProgressIndicator(
            color: mediumSeaGreen,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightMint,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
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
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeader() {
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
                      _displayName ?? 'Employer',
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      ).then((_) {
                        // Refresh notification count when returning
                        _loadNotificationCount();
                      });
                    },
                    badge: _unreadNotificationCount > 0,
                    badgeCount: _unreadNotificationCount,
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.person,
                    onTap: () async {
                      if (_navigator != null) {
                        await _navigator!.push(
                          MaterialPageRoute(
                            builder: (context) => const EmployerProfileScreen(),
                          ),
                        );
                        
                        // Reset to home tab after returning
                        if (mounted) {
                          setState(() {
                            _currentIndex = 0;
                          });
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Company info and stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Active Jobs',
                  '${_jobs.where((job) => job['status'] == 'open').length}',
                  Icons.work_outline,
                  mediumSeaGreen,
                  onTap: _navigateToActiveJobs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Applications',
                  '$_totalApplications',
                  Icons.people_outline,
                  paleGreen,
                  onTap: _navigateToApplicationsOverview,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Company',
                  _company?['name']?.split(' ').first ?? 'N/A',
                  Icons.business_outlined,
                  darkTeal,
                  onTap: _navigateToCompanyProfile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool badge = false,
    int badgeCount = 0,
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
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: onTap != null ? [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
                'Your Job Postings',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _navigateToAllJobsAnalytics,
                icon: const Icon(Icons.analytics_outlined, size: 16),
                label: const Text('Analytics'),
                style: TextButton.styleFrom(
                  foregroundColor: mediumSeaGreen,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Jobs list
          Expanded(
            child: _jobs.isEmpty ? _buildEmptyState() : _buildJobsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
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
              'No Job Postings Yet',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first job posting to start\nfinding the perfect candidates',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToPostJob,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Post Your First Job'),
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ListView.builder(
          itemCount: _jobs.length,
          itemBuilder: (context, index) {
            final job = _jobs[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildJobCard(job),
            );
          },
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status'] as String;
    final isActive = status == 'open';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive 
              ? mediumSeaGreen.withValues(alpha: 0.3)
              : darkTeal.withValues(alpha: 0.2),
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
              // Job info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            job['title'] ?? 'Untitled Job',
                            style: const TextStyle(
                              color: darkTeal,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isActive 
                                ? mediumSeaGreen.withValues(alpha: 0.1)
                                : darkTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isActive ? 'Active' : status.toUpperCase(),
                            style: TextStyle(
                              color: isActive ? mediumSeaGreen : darkTeal,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: darkTeal.withValues(alpha: 0.6),
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
                        const SizedBox(width: 16),
                        Icon(
                          Icons.work_outline,
                          color: darkTeal.withValues(alpha: 0.6),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatJobTypes(job),
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
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Salary range
          if (job['salary_min'] != null || job['salary_max'] != null)
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: mediumSeaGreen,
                  size: 16,
                ),
                const SizedBox(width: 4),
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
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (_navigator != null) {
                      await _navigator!.push(
                        MaterialPageRoute(
                          builder: (context) => ApplicationsScreen(job: job),
                        ),
                      );
                      
                      // Reset to home tab after returning
                      if (mounted) {
                        setState(() {
                          _currentIndex = 0;
                        });
                      }
                    }
                  },
                  icon: const Icon(Icons.people_outline, size: 14),
                  label: const Text('View Applications', 
                  style: TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mediumSeaGreen,
                    side: BorderSide(color: mediumSeaGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  _navigateToEditJob(job);
                },
                icon: const Icon(Icons.edit_outlined),
                color: darkTeal.withValues(alpha: 0.7),
                style: IconButton.styleFrom(
                  backgroundColor: lightMint,
                ),
              ),
              IconButton(
                onPressed: () {
                  _showDeleteConfirmation(job);
                },
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade400,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                ),
              ),
            ],
          ),
        ],
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

  String _formatJobTypes(Map<String, dynamic> job) {
    final jobTypes = (job['job_types'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final primaryJobType = job['primary_job_type'] as Map<String, dynamic>?;
    
    // If no job types from new system, fall back to old single type
    if (jobTypes.isEmpty && job['type'] != null) {
      return _formatJobTypeDisplay(job['type']);
    }
    
    // Display primary job type or first type, plus count if multiple
    if (jobTypes.isEmpty) {
      return 'Full-time';
    }
    
    final displayType = primaryJobType?['display_name'] ?? 
                       jobTypes.first['display_name'] ?? 
                       jobTypes.first['name'] ?? 
                       'Full-time';
    
    if (jobTypes.length > 1) {
      return '$displayType +${jobTypes.length - 1}';
    }
    
    return displayType;
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

  void _navigateToEditJob(Map<String, dynamic> job) async {
    if (_navigator != null) {
      final result = await _navigator!.push(
        MaterialPageRoute(
          builder: (context) => EditJobScreen(job: job),
        ),
      );
      
      // Reset to home tab after returning
      if (mounted) {
        setState(() {
          _currentIndex = 0;
        });
      }
      
      if (result == true) {
        await _loadJobs();
        await _loadApplicationsCount();
      }
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
                    'Delete Job Posting',
                    style: TextStyle(
                      color: darkTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
        ),
        content: Text(
          'Are you sure you want to delete "${job['title']}"? You can undo this action within 5 seconds.',
          style: const TextStyle(color: darkTeal, fontSize: 11),
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
              await _deleteJobWithUndo(job);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteJobWithUndo(Map<String, dynamic> job) async {
    // Store the deleted job for potential undo
    _deletedJob = Map<String, dynamic>.from(job);
    
    // Remove job from UI immediately for better UX
    if (mounted) {
      setState(() {
        _jobs.removeWhere((j) => j['id'] == job['id']);
      });
    }
    
    // Show undo snackbar
    if (mounted && _scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Job "${job['title']}" deleted',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () {
              _undoDeleteJob();
            },
          ),
        ),
      );
    }
    
    // Set timer to permanently delete after 5 seconds
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 5), () async {
      if (_deletedJob != null) {
        // Actually delete from database after timeout
        await _permanentlyDeleteJob(_deletedJob!['id']);
        _deletedJob = null;
      }
    });
  }

  void _undoDeleteJob() {
    if (_deletedJob != null) {
      // Store job title before clearing reference
      final jobTitle = _deletedJob!['title'] as String;
      
      // Cancel the timer
      _undoTimer?.cancel();
      
      // Restore the job to the list
      if (mounted) {
        setState(() {
          _jobs.add(_deletedJob!);
          // Sort by creation date to maintain order
          _jobs.sort((a, b) => 
            DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at']))
          );
        });
      }
      
      // Update applications count
      _loadApplicationsCount();
      
      // Clear the deleted job reference
      _deletedJob = null;
      
      // Show success message
      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.undo,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Job "$jobTitle" restored',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: mediumSeaGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _permanentlyDeleteJob(String jobId) async {
    try {
      final success = await JobService.archiveJob(jobId);
      if (success) {
        await _loadApplicationsCount();
        if (mounted && _scaffoldMessenger != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: const Text('Job permanently deleted', style: TextStyle(fontSize: 11)),
              backgroundColor: Colors.grey.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // If permanent deletion fails, we should restore the job
      if (_deletedJob != null && mounted && _scaffoldMessenger != null) {
        _undoDeleteJob();
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: const Text('Failed to delete job. Job has been restored.', style: TextStyle(fontSize: 11)),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Widget _buildBottomNavigationBar() {
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0),
              _buildNavItem(Icons.add_circle_outline, 'Post', 1),
              _buildNavItem(Icons.calendar_today_rounded, 'Calendar', 2),
              _buildNavItem(Icons.message_rounded, 'Chat', 3),
              _buildNavItem(Icons.people_rounded, 'Apps', 4),
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
        // Handle navigation based on index
        if (index == 0) {
          // Home - just set the index
          if (mounted) {
            setState(() {
              _currentIndex = 0;
            });
          }
        } else if (index == 1 && _navigator != null) {
          // Post Job - navigate and index will be reset in callback
          if (mounted) {
            setState(() {
              _currentIndex = index;
            });
          }
          _navigateToPostJob();
        } else if (index == 2 && _navigator != null) {
          // Calendar - navigate with temporary index change
          if (mounted) {
            setState(() {
              _currentIndex = index;
            });
          }
          _navigator!.push(
            MaterialPageRoute(
              builder: (context) => const EmployerCalendarScreen(),
            ),
          ).then((_) {
            // Reset to home tab after returning from calendar
            if (mounted) {
              setState(() {
                _currentIndex = 0;
              });
            }
          });
        } else if (index == 3 && _navigator != null) {
          // Messages - navigate with temporary index change
          if (mounted) {
            setState(() {
              _currentIndex = index;
            });
          }
          _navigator!.push(
            MaterialPageRoute(
              builder: (context) => const EmployerChatListScreen(),
            ),
          ).then((_) {
            // Reset to home tab after returning from messages
            if (mounted) {
              setState(() {
                _currentIndex = 0;
              });
            }
          });
        } else if (index == 4 && _navigator != null) {
          // Applications - navigate with temporary index change
          if (mounted) {
            setState(() {
              _currentIndex = index;
            });
          }
          _navigator!.push(
            MaterialPageRoute(
              builder: (context) => const ApplicationsOverviewScreen(),
            ),
          ).then((_) {
            // Reset to home tab after returning from applications
            if (mounted) {
              setState(() {
                _currentIndex = 0;
              });
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? mediumSeaGreen.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? mediumSeaGreen : darkTeal.withValues(alpha: 0.6),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? mediumSeaGreen : darkTeal.withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }


}
