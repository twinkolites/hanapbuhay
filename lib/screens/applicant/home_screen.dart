import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../services/job_service.dart';
import '../../services/job_recommendation_service.dart';
import '../../services/onesignal_notification_service.dart';
import 'profile_screen.dart';
import 'jobs_screen.dart';
import 'chat_list_screen.dart';
import 'apply_job_screen.dart';
import 'applications_screen.dart';
import 'saved_jobs_screen.dart';
import 'job_details_screen.dart';
import 'calendar_screen.dart';
import '../notifications_screen.dart';

// Using Supabase.instance.client directly instead of global variable

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  String? _displayName;
  List<Map<String, dynamic>> _recommendedJobs = [];
  bool _isLoading = true;
  bool _isStatsLoading = true;
  bool _isRecommendationsLoading = false;
  Map<String, bool> _appliedJobs = {};
  Map<String, bool> _savedJobs = {};
  final bool _useAIRecommendations = true;
  // Multiple job types support for recommendations
  Map<String, List<Map<String, dynamic>>> _jobTypesByJobId = {};
  Map<String, String> _jobTypeNames = {};
  
  // Statistics data
  int _appliedCount = 0;
  int _savedCount = 0;
  int _unreadNotificationCount = 0;
  
  // Debouncing for save job toggle
  Timer? _debounceTimer;
  final Set<String> _pendingSaveOperations = {};
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
    
    // Show login success toast
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLoginSuccessToast();
    });
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
      if (u != null && mounted) {
        final name =
            (u.userMetadata?['full_name'] as String?)?.trim() ?? u.email;
        if (name != _displayName) {
          setState(() => _displayName = name);
        }
      }
    });

    // Initialize AI recommendation service
    await JobRecommendationService.initialize();
    
    // Load recommendations, statistics, and notifications
    await Future.wait([
      _loadRecommendations(),
      _loadStatistics(),
      _loadNotificationCount(),
    ]);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _loadRecommendations() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      setState(() => _isRecommendationsLoading = true);

      final recommendations = await JobRecommendationService.getPersonalizedRecommendations(
        userId: user.id,
        limit: 10,
        useAI: _useAIRecommendations,
      );

      await _checkAppliedJobs(recommendations);
      await _loadJobTypeCatalog();
      await _prefetchJobTypes(recommendations);

      if (mounted) {
        setState(() {
          _recommendedJobs = recommendations;
          _isRecommendationsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recommendations: $e');
      if (mounted) {
        setState(() {
          _recommendedJobs = [];
          _isRecommendationsLoading = false;
        });
      }
    }
  }

  Future<void> _loadJobTypeCatalog() async {
    try {
      final types = await JobService.getJobTypes();
      final Map<String, String> names = {};
      for (final t in types) {
        final id = t['id']?.toString();
        if (id != null) {
          names[id] = (t['display_name'] ?? t['name'] ?? 'Unknown').toString();
        }
      }
      if (mounted) {
        setState(() {
          _jobTypeNames = names;
        });
      }
    } catch (_) {}
  }

  Future<void> _prefetchJobTypes(List<Map<String, dynamic>> jobs) async {
    try {
      final Map<String, List<Map<String, dynamic>>> temp = {};
      for (final job in jobs) {
        final jobId = job['id']?.toString();
        if (jobId == null) continue;
        final types = await JobService.getJobTypesForJob(jobId);
        temp[jobId] = types;
      }
      if (mounted) {
        setState(() {
          _jobTypesByJobId = temp;
        });
      }
    } catch (_) {}
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

      if (mounted) {
        setState(() {
          _appliedJobs = appliedJobs;
          _savedJobs = savedJobs;
        });
      }
    } catch (e) {
      print('❌ Error checking applied jobs: $e');
    }
  }

  Future<void> _loadStatistics() async {
    int appliedCount = 0;
    int savedCount = 0;
    
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

      if (mounted) {
        setState(() {
          _appliedCount = appliedCount;
          _savedCount = savedCount;
          _isStatsLoading = false;
        });
      }

    } catch (e) {
      print('❌ Error loading statistics: $e');
      print('❌ Error details: ${e.toString()}');
      if (mounted) {
        setState(() {
          _appliedCount = appliedCount;
          _savedCount = savedCount;
          _isStatsLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadRecommendations(),
      _loadStatistics(),
      _loadNotificationCount(),
    ]);
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

  @override
  void dispose() {
    _animationController.dispose();
    _debounceTimer?.cancel();
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
                'Login successful! Welcome back, ${_displayName ?? 'User'}!',
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
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayName ?? 'User',
                      style: const TextStyle(
                        color: darkTeal,
                        fontSize: 14,
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
                  _buildProfileAvatar(),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
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
      padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.work_outline,
                    color: mediumSeaGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Applications',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Track your job applications',
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.7),
                          fontSize: 9,
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
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Applied',
                      style: TextStyle(
                        color: mediumSeaGreen.withValues(alpha: 0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: paleGreen.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bookmark,
                    color: mediumSeaGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saved Jobs',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$_savedCount',
                    style: TextStyle(
                      color: mediumSeaGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: darkTeal.withValues(alpha: 0.5),
                    size: 14,
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
          // Section header with AI toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Recommended Jobs',
                    style: TextStyle(
                      color: darkTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _useAIRecommendations ? mediumSeaGreen : paleGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: _useAIRecommendations ? Colors.white : darkTeal,
                          size: 10,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'AI',
                          style: TextStyle(
                            color: _useAIRecommendations ? Colors.white : darkTeal,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Job cards - Show only AI recommendations
          Expanded(
            child: _isLoading || _isRecommendationsLoading
                ? _buildLoadingState()
                : _recommendedJobs.isEmpty
                    ? _buildEmptyState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: RefreshIndicator(
                            onRefresh: _refreshData,
                            color: mediumSeaGreen,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: _recommendedJobs.length,
                              itemBuilder: (context, index) {
                                final job = _recommendedJobs[index];
                                final isTopRecommendation = index == 0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildPremiumJobCard(
                                    job, 
                                    isRecommended: true,
                                    isTopRecommendation: isTopRecommendation,
                                    index: index,
                                  ),
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
            'No AI Recommendations Yet',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set up your job preferences to get personalized recommendations',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // AI Icon with animation
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mediumSeaGreen.withValues(alpha: 0.1),
                  paleGreen.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: mediumSeaGreen.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 40,
                color: mediumSeaGreen,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Loading text
          Text(
            'Generating Recommended Jobs',
            style: TextStyle(
              color: darkTeal,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Our AI is analyzing your profile and preferences',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Animated progress indicator
          Container(
            width: 200,
            height: 4,
            decoration: BoxDecoration(
              color: lightMint,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Container(
                      width: 200 * _animationController.value,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            mediumSeaGreen,
                            paleGreen,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Loading dots animation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final delay = index * 0.2;
                  final animationValue = (_animationController.value - delay).clamp(0.0, 1.0);
                  final scale = 0.5 + (0.5 * (1 - (animationValue - 0.5).abs() * 2).clamp(0.0, 1.0));
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: mediumSeaGreen.withValues(alpha: 0.3 + (0.7 * scale)),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumJobCard(
    Map<String, dynamic> job, {
    bool isRecommended = false,
    bool isTopRecommendation = false,
    int index = 0,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: isTopRecommendation 
              ? mediumSeaGreen.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
            blurRadius: isTopRecommendation ? 12 : 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: isTopRecommendation
              ? mediumSeaGreen.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI recommendation banner
          if (isRecommended)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    mediumSeaGreen.withValues(alpha: isTopRecommendation ? 0.08 : 0.06),
                    paleGreen.withValues(alpha: isTopRecommendation ? 0.08 : 0.06),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: mediumSeaGreen,
                    size: isTopRecommendation ? 18 : 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTopRecommendation ? 'TOP AI RECOMMENDATION' : 'AI RECOMMENDATION',
                    style: TextStyle(
                      color: mediumSeaGreen,
                      fontSize: isTopRecommendation ? 12 : 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: isTopRecommendation ? 0.8 : 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.star_rounded,
                    color: mediumSeaGreen,
                    size: isTopRecommendation ? 18 : 16,
                  ),
                ],
              ),
            ),
          
          // Main content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company logo
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            mediumSeaGreen.withValues(alpha: 0.1),
                            paleGreen.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: mediumSeaGreen.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (job['companies']?['name'] ?? 'Company').substring(0, 1),
                          style: TextStyle(
                            color: mediumSeaGreen,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            job['title'] ?? 'Untitled Job',
                            style: TextStyle(
                              color: darkTeal,
                              fontSize: isTopRecommendation ? 16 : 15,
                              fontWeight: isTopRecommendation ? FontWeight.w800 : FontWeight.w700,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      job['companies']?['name'] ?? 'Company',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Optimized bookmark button with const constructors
              GestureDetector(
                onTap: () => _toggleSaveJob(job['id']),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: lightMint,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: _SavedJobIcon(
                    isSaved: _savedJobs[job['id']] == true,
                    isPending: _pendingSaveOperations.contains(job['id']),
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
                            fontSize: 10,
                          ),
                        ),
              const Spacer(),
                              Text(
                  _formatSalaryRange(job['salary_min'], job['salary_max']),
                  style: const TextStyle(
                    color: mediumSeaGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Tags - Display multiple job types
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildMultiTypeChips(job),
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          _appliedJobs[job['id']] == true
              ? GestureDetector(
                  onTap: () => _handleAppliedJobTap(job),
                  child: Container(
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
                          'Applied - Tap to View',
                          style: TextStyle(
                            color: mediumSeaGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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
                            fontSize: 10,
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
                          backgroundColor: isTopRecommendation ? darkTeal : mediumSeaGreen,
                          foregroundColor: Colors.white,
                          elevation: isTopRecommendation ? 4 : 0,
                          padding: EdgeInsets.symmetric(
                            vertical: isTopRecommendation ? 14 : 12
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          shadowColor: isTopRecommendation 
                            ? darkTeal.withValues(alpha: 0.3) 
                            : null,
                        ),
                        child: Text(
                          isTopRecommendation ? 'APPLY NOW' : 'Apply Now',
                          style: TextStyle(
                            fontSize: isTopRecommendation ? 11 : 10,
                            fontWeight: isTopRecommendation ? FontWeight.w700 : FontWeight.w600,
                            letterSpacing: isTopRecommendation ? 0.5 : 0,
                          ),
                        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0),
              _buildNavItem(Icons.work_rounded, 'Jobs', 1),
              _buildNavItem(Icons.calendar_today_rounded, 'Calendar', 2),
              _buildNavItem(Icons.chat_rounded, 'Chat', 3),
              _buildNavItem(Icons.work_outline, 'Apps', 4),
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
          // Navigate to calendar screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ApplicantCalendarScreen(),
            ),
          );
        } else if (index == 3) {
          // Navigate to chat list screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ApplicantChatListScreen(),
            ),
          );
        } else if (index == 4) {
          // Navigate to applications screen
          _showApplicationsScreen();
        } else {
          if (mounted) {
            setState(() {
              _currentIndex = index;
            });
          }
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

  // Build chips for multiple job types for recommended job cards
  List<Widget> _buildMultiTypeChips(Map<String, dynamic> job) {
    final String? jobId = job['id']?.toString();
    final mapTypes = jobId != null ? _jobTypesByJobId[jobId] : null;

    // Prefer prefetched mapping via job_job_types
    if (mapTypes != null && mapTypes.isNotEmpty) {
      String? primaryId;
      for (final t in mapTypes) {
        if (t['is_primary'] == true) {
          primaryId = t['job_type_id']?.toString();
          break;
        }
      }
      primaryId ??= mapTypes.first['job_type_id']?.toString();

      return mapTypes.map((t) {
        final id = t['job_type_id']?.toString() ?? '';
        final isPrimary = id == primaryId;
        final label = _jobTypeNames[id] ?? 'Unknown';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPrimary ? mediumSeaGreen.withValues(alpha: 0.15) : mediumSeaGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPrimary ? mediumSeaGreen.withValues(alpha: 0.3) : mediumSeaGreen.withValues(alpha: 0.15),
              width: isPrimary ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPrimary) ...[
                Icon(Icons.star, color: mediumSeaGreen, size: 10),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: mediumSeaGreen,
                  fontSize: 10,
                  fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList();
    }

    // Fallback: if recommendations include embedded job_types (from optimized RPC)
    final List<Map<String, dynamic>> jobTypes = (job['job_types'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final Map<String, dynamic>? primary = job['primary_job_type'] as Map<String, dynamic>?;
    if (jobTypes.isNotEmpty) {
      return jobTypes.take(3).map((jt) {
        final isPrimary = primary != null && jt['id'] == primary['id'];
        final label = jt['display_name'] ?? jt['name'] ?? '';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPrimary ? mediumSeaGreen.withValues(alpha: 0.15) : mediumSeaGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPrimary ? mediumSeaGreen.withValues(alpha: 0.3) : mediumSeaGreen.withValues(alpha: 0.15),
              width: isPrimary ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPrimary) ...[
                Icon(Icons.star, color: mediumSeaGreen, size: 10),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: mediumSeaGreen,
                  fontSize: 10,
                  fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList();
    }

    // Final fallback: legacy single type enum
    final String type = job['type'] ?? 'full_time';
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: mediumSeaGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: mediumSeaGreen.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          _formatJobTypeDisplay(type),
          style: TextStyle(
            color: mediumSeaGreen,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ];
  }
  // removed obsolete _buildJobTypeTags

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


  void _toggleSaveJob(String jobId) {
    // Debounce rapid taps
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    // Prevent multiple operations on same job
    if (_pendingSaveOperations.contains(jobId)) return;
    
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performToggleSaveJob(jobId);
    });
  }

  Future<void> _performToggleSaveJob(String jobId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Mark operation as pending
      _pendingSaveOperations.add(jobId);
      
      // Optimistic UI update for immediate feedback
      final currentState = _savedJobs[jobId] ?? false;
      final newState = !currentState;
      
      if (mounted) {
        setState(() {
          _savedJobs[jobId] = newState;
        });
      }

      // Perform the actual toggle operation
      final isSaved = await JobService.toggleSaveJob(jobId, user.id);
      
      // Track recommendation feedback if this is a recommended job (non-blocking)
      if (_recommendedJobs.any((r) => r['id'] == jobId)) {
        JobRecommendationService.recordRecommendationFeedback(
          userId: user.id,
          jobId: jobId,
          feedbackType: isSaved ? 'liked' : 'disliked',
        ).catchError((e) {
          debugPrint('Error recording feedback: $e');
          return false;
        });
      }
      
      // Update UI with actual result
      if (mounted) {
        setState(() {
          _savedJobs[jobId] = isSaved;
        });
      }

      // Update saved count in statistics (non-blocking)
      _updateSavedCount();

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSaved ? 'Job saved!' : 'Job removed from saved'),
            backgroundColor: mediumSeaGreen,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Revert optimistic update on error
      final originalState = _savedJobs[jobId] ?? false;
      if (mounted) {
        setState(() {
          _savedJobs[jobId] = originalState;
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update saved job'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // Remove from pending operations
      _pendingSaveOperations.remove(jobId);
    }
  }

  // Optimized statistics update without full reload
  Future<void> _updateSavedCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final savedJobsResponse = await Supabase.instance.client
          .from('saved_jobs')
          .select('seeker_id, job_id')
          .eq('seeker_id', user.id);
      
      if (mounted) {
        setState(() {
          _savedCount = savedJobsResponse.length;
        });
      }
    } catch (e) {
      debugPrint('Error updating saved count: $e');
    }
  }

  void _navigateToApplyJob(Map<String, dynamic> job) async {
    // Track recommendation feedback if this is a recommended job
    if (_recommendedJobs.any((r) => r['id'] == job['id'])) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await JobRecommendationService.recordRecommendationFeedback(
          userId: user.id,
          jobId: job['id'],
          feedbackType: 'applied',
        );
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyJobScreen(job: job),
      ),
    );
    
    if (result == true) {
      // Force refresh statistics first to ensure immediate update
      await _loadStatistics();
      
      // Then reload recommendations and check applied status
      await _loadRecommendations();
    }
  }

  void _navigateToJobDetails(Map<String, dynamic> job) {
    // Track recommendation feedback if this is a recommended job
    if (_recommendedJobs.any((r) => r['id'] == job['id'])) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        JobRecommendationService.recordRecommendationFeedback(
          userId: user.id,
          jobId: job['id'],
          feedbackType: 'viewed',
        );
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailsScreen(job: job),
      ),
    );
  }

  void _handleAppliedJobTap(Map<String, dynamic> job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    mediumSeaGreen.withValues(alpha: 0.2),
                    paleGreen.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: mediumSeaGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.check_circle,
                color: mediumSeaGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Already Applied',
                style: TextStyle(
                  color: darkTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have already applied for "${job['title']}" at ${job['companies']?['name'] ?? 'this company'}.',
              style: const TextStyle(color: darkTeal),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightMint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: paleGreen.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: mediumSeaGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Track your application status and view details in the Applications section.',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: darkTeal.withValues(alpha: 0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showApplicationsScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: mediumSeaGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'View Applications',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// Optimized const widget for save job icon to reduce rebuilds
class _SavedJobIcon extends StatelessWidget {
  final bool isSaved;
  final bool isPending;
  
  const _SavedJobIcon({
    required this.isSaved,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context) {
    if (isPending) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CA771)),
        ),
      );
    }
    
    return Icon(
      isSaved ? Icons.bookmark : Icons.bookmark_border,
      color: const Color(0xFF4CA771),
      size: 18,
    );
  }
}
