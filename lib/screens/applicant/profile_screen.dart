import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'applications_screen.dart';
import 'saved_jobs_screen.dart';
import '../login_screen.dart';
import 'application_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);
  
  User? _currentUser;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  
  // Real statistics data
  int _appliedCount = 0;
  int _savedCount = 0;
  int _interviewsCount = 0;
  bool _isStatsLoading = true;
  
  // Application profile data
  Map<String, dynamic>? _applicationProfile;
  int _profileCompleteness = 0;
  bool _isProfileLoading = true;
  
  // Cache timestamp to prevent unnecessary reloads
  DateTime? _lastDataLoad;

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
    
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        setState(() {
          _currentUser = user;
        });
        
        // Use optimized procedure to get ALL data in one call
        await _loadAllProfileData();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isStatsLoading = false;
        _isProfileLoading = false;
      });
    }
    
    _animationController.forward();
  }

  Future<void> _loadAllProfileData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Use optimized stored procedure to get all profile data in one query
      final response = await Supabase.instance.client.rpc('get_applicant_profile_stats', params: {
        'user_uuid': user.id,
      });

      if (response is List && response.isNotEmpty) {
        final statsData = response.first;
        
        // Parse user profile
        final userProfileData = statsData['user_profile'] as Map<String, dynamic>?;
        
        // Parse application profile
        final applicationProfileData = statsData['application_profile'] as Map<String, dynamic>?;
        
        setState(() {
          _userProfile = userProfileData;
          _applicationProfile = applicationProfileData;
          _appliedCount = (statsData['applied_count'] as num).toInt();
          _savedCount = (statsData['saved_count'] as num).toInt();
          _interviewsCount = (statsData['interviews_count'] as num).toInt();
          _profileCompleteness = statsData['profile_completeness'] as int? ?? 0;
          _isLoading = false;
          _isStatsLoading = false;
          _isProfileLoading = false;
          _lastDataLoad = DateTime.now(); // Cache timestamp
        });
      } else {
        // Profile doesn't exist, create a basic one and retry
        await _createBasicProfile();
      }
    } catch (e) {
      // Fallback to separate queries if procedure fails
      await _loadProfileDataFallback();
    }
  }

  Future<void> _createBasicProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final newProfile = {
        'id': user.id,
        'email': user.email,
        'full_name': user.userMetadata?['full_name'] ?? '',
        'display_name': user.userMetadata?['display_name'] ?? user.userMetadata?['full_name'] ?? '',
        'username': user.userMetadata?['username'] ?? '',
        'avatar_url': user.userMetadata?['avatar_url'] ?? '',
        'phone_number': user.userMetadata?['phone_number'] ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert the new profile
      await Supabase.instance.client
          .from('profiles')
          .insert(newProfile);

      // Retry loading with the new profile
      await _loadAllProfileData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isStatsLoading = false;
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _loadProfileDataFallback() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Load profile data from Supabase, use maybeSingle() to handle missing profiles
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
          
      if (response != null) {
        setState(() {
          _userProfile = response;
          _isLoading = false;
        });
      } else {
        // Profile doesn't exist, create a basic one
        final newProfile = {
          'id': user.id,
          'email': user.email,
          'full_name': user.userMetadata?['full_name'] ?? '',
          'display_name': user.userMetadata?['display_name'] ?? user.userMetadata?['full_name'] ?? '',
          'username': user.userMetadata?['username'] ?? '',
          'avatar_url': user.userMetadata?['avatar_url'] ?? '',
          'phone_number': user.userMetadata?['phone_number'] ?? '',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Insert the new profile
        await Supabase.instance.client
            .from('profiles')
            .insert(newProfile);

        setState(() {
          _userProfile = newProfile;
          _isLoading = false;
        });
      }
      
      // Load statistics and application profile separately
      await _loadStatistics();
      await _loadApplicationProfile();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isStatsLoading = false;
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Use optimized stored procedure to get all statistics in one query
      final response = await Supabase.instance.client.rpc('get_applicant_profile_stats', params: {
        'user_uuid': user.id,
      });

      if (response is List && response.isNotEmpty) {
        final statsData = response.first;
        
        setState(() {
          _appliedCount = (statsData['applied_count'] as num).toInt();
          _savedCount = (statsData['saved_count'] as num).toInt();
          _interviewsCount = (statsData['interviews_count'] as num).toInt();
          _isStatsLoading = false;
        });
      } else {
        setState(() {
          _appliedCount = 0;
          _savedCount = 0;
          _interviewsCount = 0;
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _appliedCount = 0;
        _savedCount = 0;
        _interviewsCount = 0;
        _isStatsLoading = false;
      });
    }
  }

  Future<void> _loadApplicationProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Use optimized stored procedure to get application profile data
      final response = await Supabase.instance.client.rpc('get_applicant_profile_stats', params: {
        'user_uuid': user.id,
      });

      if (response is List && response.isNotEmpty) {
        final statsData = response.first;
        final applicationProfileData = statsData['application_profile'] as Map<String, dynamic>?;
        
        setState(() {
          _applicationProfile = applicationProfileData;
          _profileCompleteness = statsData['profile_completeness'] as int? ?? 0;
          _isProfileLoading = false;
        });
      } else {
        // No profile exists yet
        setState(() {
          _applicationProfile = null;
          _profileCompleteness = 0;
          _isProfileLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProfileLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      body: SafeArea(
        child: _isLoading 
          ? _buildLoadingState()
          : _buildProfileContent(),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh if data is missing or cache is old (older than 30 seconds)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLoading && !_isStatsLoading && !_isProfileLoading && _currentUser != null) {
        final now = DateTime.now();
        final shouldRefresh = _userProfile == null || 
            _appliedCount == 0 && _savedCount == 0 && _interviewsCount == 0 ||
            _lastDataLoad == null || 
            now.difference(_lastDataLoad!).inSeconds > 30;
            
        if (shouldRefresh) {
          _loadAllProfileData();
        }
      }
    });
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: mediumSeaGreen,
      ),
    );
  }

  Widget _buildProfileContent() {
    return Column(
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
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildProfileSections(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
              child: const Icon(
                Icons.arrow_back,
                color: darkTeal,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Profile',
            style: TextStyle(
              color: darkTeal,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(
                    userProfile: _userProfile,
                    currentUser: _currentUser,
                    onProfileUpdated: () {
                      _loadUserData(); // Refresh profile data
                    },
                  ),
                ),
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: mediumSeaGreen,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: mediumSeaGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSections() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildProfileCard(),
          const SizedBox(height: 24),
          _buildApplicationProfileCard(),
          const SizedBox(height: 24),
          _buildStatsSection(),
          const SizedBox(height: 24),
          _buildMenuSection(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final displayName = _userProfile?['display_name'] ?? _userProfile?['full_name'] ?? _currentUser?.email ?? 'User';
    final username = _userProfile?['username'] ?? '';
    final email = _currentUser?.email ?? '';
    final avatarUrl = _userProfile?['avatar_url'];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [mediumSeaGreen, darkTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: mediumSeaGreen.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 40,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 40,
                  ),
          ),
          
          const SizedBox(height: 16),
          
          // Name
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Username
          if (username.isNotEmpty)
            Text(
              '@$username',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          
          const SizedBox(height: 4),
          
          // Email
          Text(
            email,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          // Member since
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Member since ${_formatDate(_currentUser?.createdAt != null ? DateTime.parse(_currentUser!.createdAt) : null)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationProfileCard() {
    if (_isProfileLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: darkTeal.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: mediumSeaGreen,
          ),
        ),
      );
    }

    final hasProfile = _applicationProfile != null;
    final completeness = _profileCompleteness;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasProfile ? Icons.badge_outlined : Icons.person_add_outlined,
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
                      hasProfile ? 'Application Profile' : 'Create Application Profile',
                      style: const TextStyle(
                        color: darkTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      hasProfile 
                        ? 'Complete your professional profile for better job matches'
                        : 'Build your professional profile to stand out to employers',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress section
          if (hasProfile) ...[
            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile Completeness',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$completeness%',
                      style: TextStyle(
                        color: completeness >= 80 ? mediumSeaGreen : completeness >= 50 ? Colors.orange : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: completeness / 100,
                  backgroundColor: paleGreen.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completeness >= 80 ? mediumSeaGreen : completeness >= 50 ? Colors.orange : Colors.red,
                  ),
                  minHeight: 6,
                ),
                const SizedBox(height: 8),
                Text(
                  _getCompletenessMessage(completeness),
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ApplicationProfileScreen(
                      applicationProfile: _applicationProfile,
                      onProfileUpdated: () {
                        _loadApplicationProfile();
                      },
                    ),
                  ),
                );
                // Refresh profile data when returning
                _loadApplicationProfile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: hasProfile ? mediumSeaGreen : darkTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              icon: Icon(
                hasProfile ? Icons.edit_outlined : Icons.add_circle_outline,
                size: 18,
              ),
              label: Text(
                hasProfile ? 'Update Profile' : 'Create Profile',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          // Quick stats if profile exists
          if (hasProfile) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightMint.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: paleGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  _buildQuickStat(
                    'Skills',
                    _getSkillsCount(),
                    Icons.star_outline,
                    mediumSeaGreen,
                  ),
                  const SizedBox(width: 16),
                  _buildQuickStat(
                    'Experience',
                    _getExperienceYears(),
                    Icons.work_outline,
                    paleGreen,
                  ),
                  const SizedBox(width: 16),
                  _buildQuickStat(
                    'Education',
                    _getEducationCount(),
                    Icons.school_outlined,
                    darkTeal,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCompletenessMessage(int completeness) {
    if (completeness >= 90) return 'Excellent! Your profile is complete and professional.';
    if (completeness >= 80) return 'Great! Your profile looks professional.';
    if (completeness >= 70) return 'Good progress! Add more details to stand out.';
    if (completeness >= 50) return 'Getting there! Complete more sections for better visibility.';
    if (completeness >= 30) return 'Start building your profile to attract employers.';
    return 'Create your professional profile to get started.';
  }

  String _getSkillsCount() {
    if (_applicationProfile == null) return '0';
    final skills = _applicationProfile!['skills'] as List?;
    return '${skills?.length ?? 0}';
  }

  String _getExperienceYears() {
    if (_applicationProfile == null) return '0';
    final years = _applicationProfile!['years_of_experience'] as int?;
    return '${years ?? 0}y';
  }

  String _getEducationCount() {
    if (_applicationProfile == null) return '0';
    final education = _applicationProfile!['education'] as List?;
    return '${education?.length ?? 0}';
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            'Applied',
            _isStatsLoading ? '...' : '$_appliedCount',
            Icons.work_outline,
            mediumSeaGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            'Saved',
            _isStatsLoading ? '...' : '$_savedCount',
            Icons.bookmark_outline,
            paleGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            'Interviews',
            _isStatsLoading ? '...' : '$_interviewsCount',
            Icons.calendar_today_outlined,
            darkTeal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
    );
  }

  Widget _buildMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account',
          style: TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.work_outline,
          title: 'My Applications',
          subtitle: 'View and manage your applications',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ApplicantApplicationsScreen(),
              ),
            );
            // Refresh statistics when returning
            _loadStatistics();
          },
        ),
        _buildMenuItem(
          icon: Icons.bookmark_outline,
          title: 'Saved Jobs',
          subtitle: 'Your bookmarked positions',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SavedJobsScreen(),
              ),
            );
            // Refresh statistics when returning
            _loadStatistics();
          },
        ),
        _buildMenuItem(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage your notification preferences',
          onTap: () {
            // TODO: Navigate to notifications
          },
        ),
        const SizedBox(height: 24),
        
        const Text(
          'Settings',
          style: TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.security_outlined,
          title: 'Privacy & Security',
          subtitle: 'Manage your account security',
          onTap: () {
            // TODO: Navigate to privacy settings
          },
        ),
        _buildMenuItem(
          icon: Icons.language_outlined,
          title: 'Language',
          subtitle: 'Change app language',
          onTap: () {
            // TODO: Navigate to language settings
          },
        ),
        _buildMenuItem(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Get help and contact support',
          onTap: () {
            // TODO: Navigate to help
          },
        ),
        const SizedBox(height: 24),
        
        // Sign out button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showSignOutDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              foregroundColor: Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            icon: const Icon(Icons.logout, size: 20),
            label: const Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
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
              color: lightMint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: mediumSeaGreen,
                    size: 20,
                  ),
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
                          color: darkTeal.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: darkTeal.withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog() {
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
              style: TextStyle(color: darkTeal.withValues(alpha: 0.6), fontSize: 11),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              Navigator.pop(context);
              await AuthService.signOut();
              if (mounted) {
                // Navigate to login screen and clear all previous routes
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sign Out', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.month}/${date.year}';
  }
}
