import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';
import 'apply_job_screen.dart';
import '../employer/employer_availability_screen.dart';
import '../../services/calendar_service.dart';

final supabase = Supabase.instance.client;

class JobDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobDetailsScreen({
    super.key,
    required this.job,
  });

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> with TickerProviderStateMixin {
  bool _hasApplied = false;
  bool _isSaved = false;
  String? _employerId;
  String? _availabilitySummary;
  // Multiple job types support
  Map<String, String> _jobTypeNames = {}; // job_type_id -> display_name
  List<Map<String, dynamic>> _jobTypeMappings = []; // [{job_type_id,is_primary}]
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    
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
    _checkJobStatus();
    _prepareAvailability();
    _loadJobTypeCatalog();
    _prefetchJobTypes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  Future<void> _prefetchJobTypes() async {
    try {
      final jobId = widget.job['id']?.toString();
      if (jobId == null) return;
      final types = await JobService.getJobTypesForJob(jobId);
      if (mounted) {
        setState(() {
          _jobTypeMappings = types;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkJobStatus() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final hasApplied = await JobService.hasUserApplied(widget.job['id'], user.id);
        final isSaved = await JobService.isJobSaved(widget.job['id'], user.id);
        
        setState(() {
          _hasApplied = hasApplied;
          _isSaved = isSaved;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _prepareAvailability() async {
    try {
      // Determine employerId from job companies relation
      String? employerId;
      final company = widget.job['companies'];
      if (company != null && company['id'] != null) {
        // Fetch owner_id from companies table
        final row = await supabase
            .from('companies')
            .select('owner_id')
            .eq('id', company['id'])
            .maybeSingle();
        employerId = row?['owner_id'] as String?;
      }

      if (employerId == null) return;
      _employerId = employerId;

      final settings = await CalendarService.getAvailabilitySettings(employerId);
      if (settings == null) {
        if (mounted) setState(() => _availabilitySummary = 'No availability set');
        return;
      }

      // Build weekly summary (Mon–Sun with first available window or Unavailable)
      final dayNames = const ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
      final List<String> parts = [];
      for (int i = 0; i < 7; i++) {
        final daySlots = settings.weeklyAvailability
            .where((s) => s.dayOfWeek == i && s.isAvailable)
            .toList();
        if (daySlots.isEmpty) {
          parts.add('${dayNames[i]}: —');
        } else {
          // Show first slot and a +N if more
          final first = daySlots.first;
          final firstStr = '${_two(first.startTime.hour)}:${_two(first.startTime.minute)}–${_two(first.endTime.hour)}:${_two(first.endTime.minute)}';
          final extra = daySlots.length > 1 ? ' (+${daySlots.length - 1})' : '';
          parts.add('${dayNames[i]}: $firstStr$extra');
        }
      }

      if (mounted) setState(() => _availabilitySummary = parts.join('  |  '));
    } catch (_) {}
  }

  Future<void> _toggleSaveJob() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final isSaved = await JobService.toggleSaveJob(widget.job['id'], user.id);
      
      setState(() {
        _isSaved = isSaved;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSaved ? 'Job saved!' : 'Job removed from saved'),
            backgroundColor: mediumSeaGreen,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update saved job'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _navigateToApplyJob() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplyJobScreen(job: widget.job),
      ),
    );
    
    if (result == true) {
      await _checkJobStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
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
              child: Icon(
                Icons.arrow_back,
                color: darkTeal,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Job Details',
              style: const TextStyle(
                color: darkTeal,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: _toggleSaveJob,
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
              child: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: mediumSeaGreen,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildJobHeader(),
              
              const SizedBox(height: 24),
              
              _buildJobInfo(),
              
              const SizedBox(height: 24),
              
              _buildDescription(),
              
              const SizedBox(height: 24),
              
              _buildRequirements(),
              
              const SizedBox(height: 24),
              
              _buildCompanyInfo(),

              const SizedBox(height: 24),
              _buildAvailabilityPreview(),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightMint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleGreen.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.schedule_rounded, color: mediumSeaGreen, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Employer Availability', style: TextStyle(color: darkTeal, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _availabilitySummary ?? 'Loading availability...',
            style: TextStyle(color: darkTeal.withValues(alpha: 0.8), fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _employerId == null
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmployerAvailabilityScreen(employerId: _employerId!),
                        ),
                      );
                    },
              child: const Text('View Slots', style: TextStyle(color: mediumSeaGreen, fontWeight: FontWeight.w600)),
            ),
          )
        ],
      ),
    );
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  Widget _buildJobHeader() {
    final company = widget.job['companies'];
    
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                child: Center(
                  child: Text(
                    (company?['name'] ?? 'Company').substring(0, 1),
                    style: TextStyle(
                      color: mediumSeaGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
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
                    ),
                    const SizedBox(height: 4),
                    Text(
                      company?['name'] ?? 'Company',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          // Job type chips (multiple types supported)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildJobTypeChips(widget.job),
          ),
        ],
      ),
    );
  }

  Widget _buildJobInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: lightMint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.location_on_outlined,
            'Location',
            widget.job['location'] ?? 'Location not specified',
          ),
          
          const SizedBox(height: 16),
          
          // Job Types row (chips)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.work_outline,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildJobTypeChips(widget.job),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (widget.job['salary_min'] != null || widget.job['salary_max'] != null)
            _buildInfoRow(
              Icons.payments_outlined,
              'Salary',
              _formatSalaryRange(widget.job['salary_min'], widget.job['salary_max']),
            ),
          
          if (widget.job['salary_min'] != null || widget.job['salary_max'] != null)
            const SizedBox(height: 16),
          
          if (widget.job['experience_level'] != null)
            _buildInfoRow(
              Icons.school_outlined,
              'Experience Level',
              widget.job['experience_level'],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: mediumSeaGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
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
                label,
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: darkTeal,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Job Description',
          style: TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 12),
        
        Text(
          widget.job['description'] ?? 'No description provided.',
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.8),
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Requirements',
          style: TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: lightMint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: paleGreen.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            'Requirements will be detailed during the application process. Please ensure you meet the experience level requirements mentioned above.',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyInfo() {
    final company = widget.job['companies'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About Company',
          style: TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: lightMint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: paleGreen.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
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
                        (company?['name'] ?? 'Company').substring(0, 1),
                        style: TextStyle(
                          color: mediumSeaGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company?['name'] ?? 'Company',
                          style: const TextStyle(
                            color: darkTeal,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          company?['is_public'] == true ? 'Public Company' : 'Private Company',
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              if (company?['about'] != null) ...[
                const SizedBox(height: 16),
                Text(
                  company['about'],
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.8),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
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
        child: _hasApplied
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: mediumSeaGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Applied',
                      style: TextStyle(
                        color: mediumSeaGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : ElevatedButton(
                onPressed: _navigateToApplyJob,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mediumSeaGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

  // Build chips for multiple job types with primary highlighted
  List<Widget> _buildJobTypeChips(Map<String, dynamic> job) {
    // Prefer mapped job_job_types if available
    if (_jobTypeMappings.isNotEmpty) {
      String? primaryId;
      for (final t in _jobTypeMappings) {
        if (t['is_primary'] == true) {
          primaryId = t['job_type_id']?.toString();
          break;
        }
      }
      primaryId ??= _jobTypeMappings.first['job_type_id']?.toString();
      return _jobTypeMappings.map((t) {
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
                  fontSize: 11,
                  fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList();
    }

    // Fallback to embedded job['job_types'] if present
    final List<Map<String, dynamic>> jobTypes =
        (job['job_types'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final Map<String, dynamic>? primary = job['primary_job_type'] as Map<String, dynamic>?;
    if (jobTypes.isNotEmpty) {
      return jobTypes.map((jt) {
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
                  fontSize: 11,
                  fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList();
    }

    // Legacy fallback
    final legacy = _formatJobTypeDisplay(job['type'] ?? 'full_time');
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
          legacy,
          style: TextStyle(
            color: mediumSeaGreen,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ];
  }
}
