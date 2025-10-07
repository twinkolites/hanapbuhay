import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';
import 'post_job_screen.dart';
import 'edit_job_screen.dart';
import 'profile_screen.dart';
import 'applications_screen.dart';
import 'applications_overview_screen.dart';
import 'chat_list_screen.dart';

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

  Future<void> _initializeEmployerData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _displayName = user.userMetadata?['full_name'] ?? user.email;
      
      // Get or create company
      _company = await JobService.getUserCompany(user.id) ?? 
        await JobService.createCompany(
          ownerId: user.id,
          name: '$_displayName\'s Company',
          about: 'Professional services company',
        );
      
      // Load jobs and applications
      if (_company != null) {
        await Future.wait([
          _loadJobs(),
          _loadApplicationsCount(),
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


  void _navigateToPostJob() async {
    if (_company != null && _navigator != null) {
      final result = await _navigator!.push(
        MaterialPageRoute(
          builder: (context) => PostJobScreen(company: _company!),
        ),
      );
      
      if (result == true) {
        // Reload jobs and applications count after posting
        await _loadJobs();
        await _loadApplicationsCount();
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
      floatingActionButton: _jobs.isNotEmpty ? FloatingActionButton.extended(
        onPressed: _navigateToPostJob,
        backgroundColor: mediumSeaGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Post Job',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ) : null,
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
                      // TODO: Implement notifications
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.person,
                    onTap: () {
                      if (_navigator != null) {
                        _navigator!.push(
                          MaterialPageRoute(
                            builder: (context) => const EmployerProfileScreen(),
                          ),
                        );
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Applications',
                  '$_totalApplications',
                  Icons.people_outline,
                  paleGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Company',
                  _company?['name']?.split(' ').first ?? 'N/A',
                  Icons.business_outlined,
                  darkTeal,
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
        child: Center(
          child: Icon(
            icon,
            color: darkTeal,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
                onPressed: _navigateToPostJob,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Post New'),
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
              icon: const Icon(Icons.add),
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
                        Text(
                          job['type'] ?? 'Full-time',
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
                  onPressed: () {
                    if (_navigator != null) {
                      _navigator!.push(
                        MaterialPageRoute(
                          builder: (context) => ApplicationsScreen(job: job),
                        ),
                      );
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

  void _navigateToEditJob(Map<String, dynamic> job) async {
    if (_navigator != null) {
      final result = await _navigator!.push(
        MaterialPageRoute(
          builder: (context) => EditJobScreen(job: job),
        ),
      );
      
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0),
              _buildNavItem(Icons.message_rounded, 'Messages', 1),
              _buildNavItem(Icons.people_rounded, 'Applications', 2),
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
        if (mounted) {
          setState(() {
            _currentIndex = index;
          });
        }
        
        // Handle navigation based on index
        if (index == 1 && _navigator != null) {
          // Navigate to messages
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
        } else if (index == 2 && _navigator != null) {
          // Navigate to applications overview
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
        } else if (index == 3 && _navigator != null) {
          // Navigate to profile
          _navigator!.push(
            MaterialPageRoute(
              builder: (context) => const EmployerProfileScreen(),
            ),
          ).then((_) {
            // Reset to home tab after returning from profile
            if (mounted) {
              setState(() {
                _currentIndex = 0;
              });
            }
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


}
