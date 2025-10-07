import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/applicant/apply_job_screen.dart';

class JobCardWidget extends StatefulWidget {
  final Map<String, dynamic> job;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onApplyTap;

  const JobCardWidget({
    super.key,
    required this.job,
    this.onBookmarkTap,
    this.onApplyTap,
  });

  @override
  State<JobCardWidget> createState() => _JobCardWidgetState();
}

class _JobCardWidgetState extends State<JobCardWidget> {
  bool _hasApplied = false;
  String? _applicationStatus;
  bool _isCheckingApplication = true;
  final SupabaseClient _supabase = Supabase.instance.client;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
  }

  Future<void> _checkApplicationStatus() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        // Get application details including status
        final response = await _supabase
            .from('job_applications')
            .select('status')
            .eq('job_id', widget.job['id'])
            .eq('applicant_id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _hasApplied = response != null;
            _applicationStatus = response?['status'];
            _isCheckingApplication = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _hasApplied = false;
            _applicationStatus = null;
            _isCheckingApplication = false;
          });
        }
      }
    } else {
      setState(() {
        _hasApplied = false;
        _applicationStatus = null;
        _isCheckingApplication = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    (widget.job['companies']?['name'] ?? 'Company').substring(0, 1),
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
                      widget.job['title'] ?? 'Untitled Job',
                      style: const TextStyle(
                        color: darkTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.job['companies']?['name'] ?? 'Company',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bookmark button
              GestureDetector(
                onTap: widget.onBookmarkTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lightMint,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bookmark_border,
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
                      widget.job['location'] ?? 'Location not specified',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                      _formatSalaryRange(widget.job['salary_min'], widget.job['salary_max']),
                style: const TextStyle(
                  color: mediumSeaGreen,
                  fontSize: 14,
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
                  _formatJobTypeDisplay(widget.job['type'] ?? 'full_time'),
                  style: TextStyle(
                    color: mediumSeaGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.job['experience_level'] != null)
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
                    _formatExperienceDisplay(widget.job['experience_level']),
                    style: TextStyle(
                      color: paleGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Apply button with application status
          SizedBox(
            width: double.infinity,
            child: _buildApplyButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyButton() {
    if (_isCheckingApplication) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: mediumSeaGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: mediumSeaGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
            ),
          ),
        ),
      );
    }

    if (_hasApplied && _applicationStatus != null) {
      return _buildApplicationStatusButton();
    }

    return ElevatedButton(
      onPressed: widget.onApplyTap ?? () => _navigateToApplyJob(context),
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
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _navigateToApplyJob(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyJobScreen(job: widget.job),
      ),
    );
    
    // Refresh application status after applying
    if (result == true) {
      _checkApplicationStatus();
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

  Widget _buildApplicationStatusButton() {
    final status = _applicationStatus!;
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final statusText = _getStatusDisplayText(status);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToApplicationDetails(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                statusIcon,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios,
                color: statusColor.withValues(alpha: 0.7),
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToApplicationDetails() {
    // Navigate to application details screen
    // This would show the full application timeline and details
    Navigator.pushNamed(context, '/application-details', arguments: {
      'job': widget.job,
      'status': _applicationStatus,
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'applied':
        return mediumSeaGreen; // Green - Successfully applied
      case 'under_review':
        return Colors.orange; // Orange - In progress
      case 'shortlisted':
        return Colors.blue; // Blue - Under consideration
      case 'interview':
        return Colors.purple; // Purple - Interview stage
      case 'hired':
        return Colors.green; // Green - Success!
      case 'rejected':
        return Colors.red; // Red - Declined
      default:
        return darkTeal;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'applied':
        return Icons.check_circle;
      case 'under_review':
        return Icons.hourglass_empty;
      case 'shortlisted':
        return Icons.star;
      case 'interview':
        return Icons.calendar_today;
      case 'hired':
        return Icons.celebration;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'applied':
        return 'Applied';
      case 'under_review':
        return 'Under Review';
      case 'shortlisted':
        return 'Shortlisted';
      case 'interview':
        return 'Interview';
      case 'hired':
        return 'Hired!';
      case 'rejected':
        return 'Not Selected';
      default:
        return status.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
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

  String _formatExperienceDisplay(String experience) {
    switch (experience.toLowerCase()) {
      case 'entry_level':
        return 'Entry Level';
      case 'mid_level':
        return 'Mid Level';
      case 'senior':
        return 'Senior';
      case 'executive':
        return 'Executive';
      default:
        return experience.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }
}
