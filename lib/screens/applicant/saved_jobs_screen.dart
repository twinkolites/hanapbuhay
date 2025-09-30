import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';
import 'apply_job_screen.dart';

class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  List<Map<String, dynamic>> _savedJobs = [];
  bool _isLoading = true;
  Map<String, bool> _appliedJobs = {};

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadSavedJobs();
  }

  Future<void> _loadSavedJobs() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Load saved jobs with company information
      final savedJobs = await Supabase.instance.client
          .from('saved_jobs')
          .select('''
            saved_at,
            jobs (
              id,
              title,
              description,
              location,
              type,
              salary_min,
              salary_max,
              experience_level,
              status,
              created_at,
              companies (
                id,
                name,
                logo_url,
                about
              )
            )
          ''')
          .eq('seeker_id', user.id)
          .order('saved_at', ascending: false);

      final jobs = <Map<String, dynamic>>[];
      for (final savedJob in savedJobs) {
        if (savedJob['jobs'] != null) {
          final job = Map<String, dynamic>.from(savedJob['jobs']);
          job['saved_at'] = savedJob['saved_at'];
          job['companies'] = savedJob['jobs']['companies'];
          jobs.add(job);
        }
      }

      setState(() {
        _savedJobs = jobs;
        _isLoading = false;
      });

      // Check which jobs the user has applied to
      await _checkAppliedJobs(jobs);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAppliedJobs(List<Map<String, dynamic>> jobs) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final appliedJobs = <String, bool>{};
      
      for (final job in jobs) {
        final jobId = job['id'];
        final hasApplied = await JobService.hasUserApplied(jobId, user.id);
        appliedJobs[jobId] = hasApplied;
      }

      setState(() {
        _appliedJobs = appliedJobs;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _toggleSaveJob(String jobId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final isSaved = await JobService.toggleSaveJob(jobId, user.id);
      
      if (!isSaved) {
        // Job was unsaved, remove from list
        setState(() {
          _savedJobs.removeWhere((job) => job['id'] == jobId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Job removed from saved jobs'),
              backgroundColor: mediumSeaGreen,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update saved job'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
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
      // Refresh applied jobs status
      await _checkAppliedJobs(_savedJobs);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        title: const Text(
          'Saved Jobs',
          style: TextStyle(
            color: darkTeal,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios,
            color: darkTeal,
            size: 24,
          ),
        ),
        actions: [
          if (_savedJobs.isNotEmpty)
            IconButton(
              onPressed: () {
                _showClearAllDialog();
              },
              icon: const Icon(
                Icons.delete_sweep,
                color: Colors.red,
                size: 24,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: mediumSeaGreen,
              ),
            )
          : _savedJobs.isEmpty
              ? _buildEmptyState()
              : _buildSavedJobsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: darkTeal.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Saved Jobs',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save jobs you\'re interested in to view them here later',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: mediumSeaGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Browse Jobs',
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

  Widget _buildSavedJobsList() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _savedJobs.length,
        itemBuilder: (context, index) {
          final job = _savedJobs[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildSavedJobCard(job),
          );
        },
      ),
    );
  }

  Widget _buildSavedJobCard(Map<String, dynamic> job) {
    
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
                      fontSize: 16,
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
              
              // Bookmark button (filled)
              GestureDetector(
                onTap: () => _toggleSaveJob(job['id']),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bookmark,
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
              Expanded(
                child: Text(
                  job['location'] ?? 'Location not specified',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: paleGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: paleGreen.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Saved',
                  style: TextStyle(
                    color: paleGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _appliedJobs[job['id']] == true
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: mediumSeaGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: mediumSeaGreen,
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: mediumSeaGreen,
                              size: 16,
                            ),
                            SizedBox(width: 8),
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
                    : ElevatedButton(
                        onPressed: () => _navigateToApplyJob(job),
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
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _toggleSaveJob(job['id']),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Clear All Saved Jobs',
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to remove all saved jobs? This action cannot be undone.',
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
            onPressed: () {
              Navigator.pop(context);
              _clearAllSavedJobs();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Clear All', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllSavedJobs() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('saved_jobs')
          .delete()
          .eq('seeker_id', user.id);

      setState(() {
        _savedJobs.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All saved jobs cleared'),
            backgroundColor: mediumSeaGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clear saved jobs'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
}
