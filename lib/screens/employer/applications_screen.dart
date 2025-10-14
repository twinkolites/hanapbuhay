import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';
import '../../services/chat_service.dart';
import '../../services/ai_screening_service.dart';
import '../../widgets/application_details_sheet.dart';
import 'chat_screen.dart';
import 'ai_insights_page.dart';

final supabase = Supabase.instance.client;

class ApplicationsScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  
  const ApplicationsScreen({
    super.key,
    required this.job,
  });

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _aiResults = []; // Add AI results
  bool _isLoading = true;
  // Removed unused _isAIScreening field
  String _selectedStatus = 'all';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Safe references to inherited widgets
  NavigatorState? _navigator;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  final List<String> _statusFilters = [
    'all',
    'applied',
    'under_review',
    'shortlisted',
    'interview',
    'hired',
    'rejected',
    'withdrawn',
  ];

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
    
    _loadApplications();
    _loadAIScreeningResults(); // Load AI results
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely capture references to inherited widgets
    _navigator = Navigator.maybeOf(context);
  }

  @override
  void dispose() {
    _animationController.dispose();
    
    // Clear references to inherited widgets
    _navigator = null;
    
    super.dispose();
  }

  Future<void> _loadApplications() async {
    try {
      final applications = await JobService.getJobApplications(widget.job['id']);
      setState(() {
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAIScreeningResults() async {
    try {
      final results = await AIScreeningService.getScreeningResults(widget.job['id']);
      setState(() {
        _aiResults = results;
      });
    } catch (e) {
      debugPrint('Error loading AI results: $e');
    }
  }

  // Removed unused _screenAllApplications method

  Map<String, dynamic>? _getAIResult(String applicationId) {
    try {
      return _aiResults.firstWhere(
        (result) => result['application_id'] == applicationId,
      );
    } catch (e) {
      return null;
    }
  }

  Color _getScoreColor(double? score) {
    if (score == null) return Colors.grey;
    if (score >= 8.0) return Colors.green;
    if (score >= 6.0) return Colors.orange;
    return Colors.red;
  }

  // Removed unused _getRecommendationText method - moved to ApplicationDetailsSheet

  List<Map<String, dynamic>> get _filteredApplications {
    if (_selectedStatus == 'all') {
      return _applications;
    }
    return _applications.where((app) => app['status'] == _selectedStatus).toList();
  }

  Future<void> _updateApplicationStatus(String applicationId, String newStatus, {String? notes, DateTime? interviewDate, int? rating}) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        _showErrorDialog('User not authenticated');
        return;
      }

      // Use the secure RPC function for status updates
      await supabase.rpc('update_application_status', params: {
        'p_application_uuid': applicationId,
        'p_new_status': newStatus,
        'p_updated_by_uuid': currentUser.id,
        'p_interview_scheduled_at': interviewDate?.toIso8601String(),
        'p_interview_notes': notes,
        'p_employer_rating': rating,
      });

      // Reload applications
      await _loadApplications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application status updated to ${_formatStatusDisplay(newStatus)}'),
            backgroundColor: mediumSeaGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error updating application status: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Error',
          style: TextStyle(
            color: darkTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: mediumSeaGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showApplicationDetails(Map<String, dynamic> application) {
    final aiResult = _getAIResult(application['id']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ApplicationDetailsSheet(
        application: application,
        aiResult: aiResult,
      ),
    );
  }

  // Removed unused _showAIDetails method

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (_navigator != null) {
              _navigator!.pop(context);
            }
          },
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
              Icons.arrow_back,
              color: darkTeal,
              size: 20,
            ),
          ),
        ),
        title: Column(
          children: [
            const Text(
              'Applications',
              style: TextStyle(
                color: darkTeal,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.job['title'] ?? 'Job Title',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadApplications,
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
                Icons.refresh,
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
    return Column(
      children: [
        // Compact Header with AI Button and Key Stats
        _buildCompactHeader(),
        
        // Filter tabs
        _buildFilterTabs(),
        
        // Bulk Operations (only when items are selected)
        _buildBulkOperations(),
        
        // Applications list
        Expanded(
          child: _filteredApplications.isEmpty
              ? _buildEmptyState()
              : _buildApplicationsList(),
        ),
      ],
    );
  }

  // Compact Header combining AI button and key stats
  Widget _buildCompactHeader() {
    final totalApplications = _applications.length;
    final newApplications = _applications.where((app) => app['status'] == 'applied').length;
    final activeApplications = _applications.where((app) => 
      ['under_review', 'shortlisted', 'interview'].contains(app['status'])).length;
    final hiredApplications = _applications.where((app) => app['status'] == 'hired').length;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // AI Button Row
          Row(
            children: [
              Expanded(
      child: ElevatedButton.icon(
        onPressed: () {
          if (_navigator != null) {
            _navigator!.push(
              MaterialPageRoute(
                builder: (context) => AIInsightsPage(job: widget.job),
              ),
            );
          }
        },
                  icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text(
                    'AI Screening',
          style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: mediumSeaGreen,
          foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
                ),
              ),
              const SizedBox(width: 12),
              // Quick Stats Summary
              _buildQuickStats(totalApplications, newApplications, activeApplications, hiredApplications),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Conversion Analytics (Compact)
          _buildCompactAnalytics(),
        ],
      ),
    );
  }

  Widget _buildQuickStats(int total, int newApps, int active, int hired) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: lightMint.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniStat('$total', 'Total', darkTeal),
          const SizedBox(width: 8),
          _buildMiniStat('$newApps', 'New', mediumSeaGreen),
          const SizedBox(width: 8),
          _buildMiniStat('$active', 'Active', Colors.blue),
          const SizedBox(width: 8),
          _buildMiniStat('$hired', 'Hired', mediumSeaGreen),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            color: color.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactAnalytics() {
    final totalApplications = _applications.length;
    final interviews = _applications.where((app) => app['status'] == 'interview').length;
    final hired = _applications.where((app) => app['status'] == 'hired').length;
    
    final applicationToInterviewRate = totalApplications > 0 ? (interviews / totalApplications * 100) : 0.0;
    final interviewToHireRate = interviews > 0 ? (hired / interviews * 100) : 0.0;
    final overallHireRate = totalApplications > 0 ? (hired / totalApplications * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightMint.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.analytics,
            color: darkTeal.withValues(alpha: 0.7),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Conversion: ',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnalyticsBadge('App→Interview', '${applicationToInterviewRate.toStringAsFixed(0)}%', Colors.blue),
                _buildAnalyticsBadge('Interview→Hire', '${interviewToHireRate.toStringAsFixed(0)}%', Colors.green),
                _buildAnalyticsBadge('Overall', '${overallHireRate.toStringAsFixed(0)}%', mediumSeaGreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Removed old _buildStatistics method - now using compact header

  // Removed unused _buildStatCard and _buildMiniStat methods

  // Bulk Operations Widget
  Widget _buildBulkOperations() {
    final selectedApplications = _applications.where((app) => app['selected'] == true).length;
    
    if (selectedApplications == 0) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: mediumSeaGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mediumSeaGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: mediumSeaGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '$selectedApplications selected',
                style: TextStyle(
                  color: mediumSeaGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearAllSelections,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: mediumSeaGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBulkActionButton(
                'Review All',
                Icons.visibility,
                Colors.orange,
                'under_review',
              ),
              _buildBulkActionButton(
                'Shortlist All',
                Icons.star,
                Colors.blue,
                'shortlisted',
              ),
              _buildBulkActionButton(
                'Reject All',
                Icons.close,
                Colors.red,
                'rejected',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionButton(String label, IconData icon, Color color, String status) {
    return GestureDetector(
      onTap: () => _showBulkStatusUpdateDialog(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
              size: 14,
          ),
            const SizedBox(width: 4),
          Text(
              label,
            style: TextStyle(
              color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearAllSelections() {
    setState(() {
      for (var app in _applications) {
        app['selected'] = false;
      }
    });
  }

  void _showBulkStatusUpdateDialog(String status) {
    final selectedCount = _applications.where((app) => app['selected'] == true).length;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Enhanced Header with Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(status).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 24,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Title
          Text(
                'Bulk Status Update',
            style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Content
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
                  'Are you sure you want to update $selectedCount applications to "${_formatStatusDisplay(status)}"?',
            textAlign: TextAlign.center,
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: darkTeal,
                        side: BorderSide(color: darkTeal.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _performBulkStatusUpdate(status);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getStatusColor(status),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                      ),
                      child: Text(
                        'Update $selectedCount',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performBulkStatusUpdate(String status) async {
    final selectedApplications = _applications.where((app) => app['selected'] == true).toList();
    
    for (final application in selectedApplications) {
      await _updateApplicationStatus(application['id'], status);
    }
    
    _clearAllSelections();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated ${selectedApplications.length} applications to ${_formatStatusDisplay(status)}'),
          backgroundColor: mediumSeaGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _statusFilters.length,
        itemBuilder: (context, index) {
          final status = _statusFilters[index];
          final isSelected = _selectedStatus == status;
          final count = status == 'all' 
              ? _applications.length 
              : _applications.where((app) => app['status'] == status).length;

          return Container(
            margin: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedStatus = status;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? mediumSeaGreen : lightMint,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? mediumSeaGreen : paleGreen,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatStatusDisplay(status),
                      style: TextStyle(
                        color: isSelected ? Colors.white : darkTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Colors.white.withValues(alpha: 0.2)
                              : mediumSeaGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : mediumSeaGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: darkTeal.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Applications Yet',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Applications will appear here once candidates apply',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationsList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 20),
      itemCount: _filteredApplications.length,
      itemBuilder: (context, index) {
        final application = _filteredApplications[index];
        return _buildApplicationCard(application);
      },
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final applicant = application['profiles'] ?? {};
    final status = application['status'] ?? 'applied';
    final isViewed = application['viewed_by_employer'] ?? false;
    final aiResult = _getAIResult(application['id']);
    final isWithdrawn = status == 'withdrawn';
    // Removed unused variables for cleaner code

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWithdrawn ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWithdrawn 
              ? Colors.grey.withValues(alpha: 0.4)
              : paleGreen.withValues(alpha: 0.3),
          width: isWithdrawn ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isWithdrawn 
                ? Colors.grey.withValues(alpha: 0.1)
                : darkTeal.withValues(alpha: 0.05),
            blurRadius: isWithdrawn ? 5 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Withdrawal Banner (if withdrawn)
          if (isWithdrawn) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Application Withdrawn',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (application['withdrawn_at'] != null)
                    Text(
                      _formatDate(application['withdrawn_at']),
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Header row - More compact
          Row(
            children: [
              // Selection checkbox
              GestureDetector(
                onTap: () {
                  setState(() {
                    application['selected'] = !(application['selected'] ?? false);
                  });
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: application['selected'] == true ? mediumSeaGreen : Colors.transparent,
                    border: Border.all(
                      color: application['selected'] == true ? mediumSeaGreen : darkTeal.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: application['selected'] == true
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        )
                      : null,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Applicant avatar - Smaller
              Container(
                width: 40,
                height: 40,
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
                ),
                child: applicant['avatar_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          applicant['avatar_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildAvatarPlaceholder(applicant['full_name'] ?? 'A');
                          },
                        ),
                      )
                    : _buildAvatarPlaceholder(applicant['full_name'] ?? 'A'),
              ),
              
              const SizedBox(width: 12),
              
              // Applicant info - Compact
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                _getApplicantName(application),
                                style: TextStyle(
                                  color: isWithdrawn ? Colors.grey.shade600 : darkTeal,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: isWithdrawn ? TextDecoration.lineThrough : TextDecoration.none,
                                ),
                              ),
                              if (isWithdrawn) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.grey.shade500,
                                  size: 14,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Status badge - Smaller
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusColor(status).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _formatStatusDisplay(status),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      applicant['email'] ?? '',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Compact info row
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: darkTeal.withValues(alpha: 0.6),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(application['created_at']),
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                        if (!isViewed) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: mediumSeaGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        const Spacer(),
                        // AI Score (if available)
                    if (aiResult != null) ...[
                          Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getScoreColor(aiResult['overall_score']).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                              'AI: ${aiResult['overall_score'] ?? 0}/10',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getScoreColor(aiResult['overall_score']),
                                  fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                            ),
                          ),
                        ],
              ),
              
          const SizedBox(height: 12),
          
          // Withdrawal reason (if withdrawn)
          if (status == 'withdrawn' && application['withdrawal_reason'] != null && application['withdrawal_reason'].toString().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Withdrawal Reason:',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          application['withdrawal_reason'],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                        if (application['withdrawn_at'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Withdrawn: ${_formatDate(application['withdrawn_at'])}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Compact cover letter preview (if exists)
          if (application['cover_letter'] != null && application['cover_letter'].toString().isNotEmpty)
              Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                color: lightMint.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                  color: paleGreen.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  application['cover_letter'],
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 12,
                  ),
                maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ),
          
          // Action buttons
          Column(
            children: [
              // Status Quick Actions (disabled for withdrawn)
              if (!isWithdrawn) ...[
                _buildCompactStatusActions(application),
                const SizedBox(height: 8),
              ],
              
              // Withdrawal Summary (if withdrawn)
              if (isWithdrawn) ...[
                _buildWithdrawalSummary(application),
                const SizedBox(height: 12),
              ],
              
              // Primary Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showApplicationTracking(application),
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isWithdrawn ? Colors.grey.shade600 : darkTeal,
                        side: BorderSide(
                          color: isWithdrawn 
                              ? Colors.grey.withValues(alpha: 0.4)
                              : darkTeal.withValues(alpha: 0.3)
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isWithdrawn ? null : () => _startChatWithApplicant(application),
                      icon: Icon(
                        Icons.chat, 
                        size: 16,
                        color: isWithdrawn ? Colors.grey.shade400 : Colors.white,
                      ),
                      label: Text(
                        'Chat',
                        style: TextStyle(
                          color: isWithdrawn ? Colors.grey.shade400 : Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isWithdrawn ? Colors.grey.shade100 : darkTeal,
                        side: BorderSide(
                          color: isWithdrawn 
                              ? Colors.grey.withValues(alpha: 0.4)
                              : darkTeal
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Bottom row: Wide Details button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showApplicationDetails(application),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: Text(isWithdrawn ? 'View Withdrawal Details' : 'View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isWithdrawn ? Colors.grey.shade700 : mediumSeaGreen,
                    side: BorderSide(
                      color: isWithdrawn 
                          ? Colors.grey.withValues(alpha: 0.4)
                          : mediumSeaGreen
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Withdrawal Summary Widget
  Widget _buildWithdrawalSummary(Map<String, dynamic> application) {
    final withdrawalReason = application['withdrawal_reason'] ?? 'No reason provided';
    final withdrawnAt = application['withdrawn_at'];
    final appliedAt = application['created_at'];
    
    // Calculate how long the application was active
    String activeDuration = '';
    if (withdrawnAt != null && appliedAt != null) {
      try {
        final appliedDate = DateTime.parse(appliedAt);
        final withdrawnDate = DateTime.parse(withdrawnAt);
        final duration = withdrawnDate.difference(appliedDate);
        
        if (duration.inDays > 0) {
          activeDuration = 'Active for ${duration.inDays} day${duration.inDays == 1 ? '' : 's'}';
        } else if (duration.inHours > 0) {
          activeDuration = 'Active for ${duration.inHours} hour${duration.inHours == 1 ? '' : 's'}';
        } else {
          activeDuration = 'Active for ${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'}';
        }
      } catch (e) {
        activeDuration = 'Duration unavailable';
      }
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.grey.shade600,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Withdrawal Summary',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Reason
          if (withdrawalReason.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason: ',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    withdrawalReason,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          
          // Duration and Date
          Row(
            children: [
              if (activeDuration.isNotEmpty) ...[
                Icon(
                  Icons.schedule,
                  color: Colors.grey.shade500,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  activeDuration,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (withdrawnAt != null) ...[
                Icon(
                  Icons.event,
                  color: Colors.grey.shade500,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'Withdrawn: ${_formatDate(withdrawnAt)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Compact Status Actions Widget
  Widget _buildCompactStatusActions(Map<String, dynamic> application) {
    final currentStatus = application['status'] ?? 'applied';
    
    // Don't show status actions for withdrawn or hired applications
    if (currentStatus == 'withdrawn' || currentStatus == 'hired') {
      return const SizedBox.shrink();
    }
    
    final statusWorkflow = _getStatusWorkflow(currentStatus);
    
    if (statusWorkflow.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: lightMint.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: statusWorkflow.map((action) {
          return GestureDetector(
            onTap: () => _showStatusUpdateDialog(application, action['status']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: action['color'].withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: action['color'].withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    action['icon'],
                    color: action['color'],
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    action['label'],
                    style: TextStyle(
                      color: action['color'],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Removed unused _buildCompactActionButton method

  // Missing helper methods
  String _formatStatusDisplay(String status) {
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
        return 'Hired';
      case 'rejected':
        return 'Rejected';
      case 'withdrawn':
        return 'Withdrawn';
      default:
        return status.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'applied':
        return mediumSeaGreen;
      case 'under_review':
        return Colors.orange;
      case 'shortlisted':
        return Colors.blue;
      case 'interview':
        return Colors.purple;
      case 'hired':
        return mediumSeaGreen;
      case 'rejected':
        return Colors.red;
      case 'withdrawn':
        return Colors.grey;
      default:
        return darkTeal;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'applied': return Icons.send;
      case 'under_review': return Icons.visibility;
      case 'shortlisted': return Icons.star;
      case 'interview': return Icons.event;
      case 'hired': return Icons.check_circle;
      case 'rejected': return Icons.close;
      case 'withdrawn': return Icons.cancel_outlined;
      default: return Icons.work;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown date';
    
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _getApplicantName(Map<String, dynamic> application) {
    // The profiles data is directly in the application object
    final fullName = application['profiles']?['full_name']?.toString().trim() ?? '';
    
    if (fullName.isEmpty) {
      return 'Unknown Applicant';
    }
    
    return fullName;
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: mediumSeaGreen,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Removed unused helper methods for source icons and formatting

  // Removed unused _showApplicationDetailsSheet method

  // Removed _buildApplicationDetailsSheet and related helper methods - moved to separate widget file

  // Removed unused _showAIDetailsSheet method

  // Removed unused _buildAIDetailsSheet method

  // Removed old _buildStatusQuickActions method - now using compact version

  // Get status workflow based on current status (industry standard flow)
  List<Map<String, dynamic>> _getStatusWorkflow(String currentStatus) {
    switch (currentStatus) {
      case 'applied':
        return [
          {
            'status': 'under_review',
            'label': 'Review',
            'icon': Icons.visibility,
            'color': Colors.orange,
          },
          {
            'status': 'shortlisted',
            'label': 'Shortlist',
            'icon': Icons.star,
            'color': Colors.blue,
          },
          {
            'status': 'rejected',
            'label': 'Reject',
            'icon': Icons.close,
            'color': Colors.red,
          },
        ];
      case 'under_review':
        return [
          {
            'status': 'shortlisted',
            'label': 'Shortlist',
            'icon': Icons.star,
            'color': Colors.blue,
          },
          {
            'status': 'interview',
            'label': 'Interview',
            'icon': Icons.event,
            'color': Colors.purple,
          },
          {
            'status': 'rejected',
            'label': 'Reject',
            'icon': Icons.close,
            'color': Colors.red,
          },
        ];
      case 'shortlisted':
        return [
          {
            'status': 'interview',
            'label': 'Interview',
            'icon': Icons.event,
            'color': Colors.purple,
          },
          {
            'status': 'hired',
            'label': 'Hire',
            'icon': Icons.check_circle,
            'color': mediumSeaGreen,
          },
          {
            'status': 'rejected',
            'label': 'Reject',
            'icon': Icons.close,
            'color': Colors.red,
          },
        ];
      case 'interview':
        return [
          {
            'status': 'hired',
            'label': 'Hire',
            'icon': Icons.check_circle,
            'color': mediumSeaGreen,
          },
          {
            'status': 'shortlisted',
            'label': '2nd Interview',
            'icon': Icons.event_repeat,
            'color': Colors.purple,
          },
          {
            'status': 'rejected',
            'label': 'Reject',
            'icon': Icons.close,
            'color': Colors.red,
          },
        ];
      default:
        return [];
    }
  }

  // Show status update dialog with additional options
  void _showStatusUpdateDialog(Map<String, dynamic> application, String newStatus) {
    showDialog(
      context: context,
      builder: (context) => _StatusUpdateDialog(
        application: application,
        newStatus: newStatus,
        onUpdate: (status, notes, interviewDate, rating) {
          _updateApplicationStatus(
            application['id'],
            status,
            notes: notes,
            interviewDate: interviewDate,
            rating: rating,
          );
        },
      ),
    );
  }

  // Show application tracking history
  Future<void> _startChatWithApplicant(Map<String, dynamic> application) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current user
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        Navigator.pop(context); // Close loading dialog
        _showErrorDialog('User not authenticated');
        return;
      }

      // Get applicant info
      final applicantId = application['applicant_id'];
      final applicantName = _getApplicantName(application);
      final jobTitle = widget.job['title'] ?? 'Job Application';

      // Create or get chat
      final chatId = await ChatService.createOrGetChat(
        jobId: widget.job['id'],
        employerId: currentUser.id,
        applicantId: applicantId,
      );

      // Close loading dialog
      Navigator.pop(context);

      // Navigate to chat screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmployerChatScreen(
            chatId: chatId,
            applicantId: applicantId,
            applicantName: applicantName,
            jobTitle: jobTitle,
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      Navigator.pop(context);
      _showErrorDialog('Failed to start chat: $e');
    }
  }

  void _showApplicationTracking(Map<String, dynamic> application) async {
    try {
      final trackingHistory = await JobService.getApplicationTracking(application['id']);
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: mediumSeaGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.history,
                        color: mediumSeaGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Application History',
                            style: TextStyle(
                              color: darkTeal,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getApplicantName(application),
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tracking list
              Expanded(
                child: trackingHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: darkTeal.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tracking history available',
                              style: TextStyle(
                                color: darkTeal.withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: trackingHistory.length,
                        itemBuilder: (context, index) {
                          final entry = trackingHistory[index];
                          final isFirst = index == 0;
                          final isLast = index == trackingHistory.length - 1;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Timeline indicator
                                Column(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: isFirst ? mediumSeaGreen : paleGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    if (!isLast)
                                      Container(
                                        width: 2,
                                        height: 40,
                                        color: paleGreen.withValues(alpha: 0.3),
                                      ),
                                  ],
                                ),
                                
                                const SizedBox(width: 16),
                                
                                // Content
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: lightMint.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: paleGreen.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _formatStatusDisplay(entry['status']),
                                                style: TextStyle(
                                                  color: darkTeal,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatDate(entry['created_at']),
                                              style: TextStyle(
                                                color: darkTeal.withValues(alpha: 0.6),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (entry['notes'] != null && entry['notes'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            entry['notes'],
                                            style: TextStyle(
                                              color: darkTeal.withValues(alpha: 0.8),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                        if (entry['profiles'] != null) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.person,
                                                color: darkTeal.withValues(alpha: 0.6),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Updated by: ${entry['profiles']['full_name'] ?? 'Unknown'}',
                                                style: TextStyle(
                                                  color: darkTeal.withValues(alpha: 0.6),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading tracking history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Status Update Dialog Widget
class _StatusUpdateDialog extends StatefulWidget {
  final Map<String, dynamic> application;
  final String newStatus;
  final Function(String status, String? notes, DateTime? interviewDate, int? rating) onUpdate;

  const _StatusUpdateDialog({
    required this.application,
    required this.newStatus,
    required this.onUpdate,
  });

  @override
  State<_StatusUpdateDialog> createState() => _StatusUpdateDialogState();
}

class _StatusUpdateDialogState extends State<_StatusUpdateDialog> {
  late TextEditingController _notesController;
  DateTime? _selectedInterviewDate;
  int? _selectedRating;
  
  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'applied': return 'Applied';
      case 'under_review': return 'Under Review';
      case 'shortlisted': return 'Shortlisted';
      case 'interview': return 'Interview';
      case 'hired': return 'Hired';
      case 'rejected': return 'Rejected';
      case 'withdrawn': return 'Withdrawn';
      default: return status.split('_').map((word) => 
        word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'applied': return mediumSeaGreen;
      case 'under_review': return Colors.orange;
      case 'shortlisted': return Colors.blue;
      case 'interview': return Colors.purple;
      case 'hired': return mediumSeaGreen;
      case 'rejected': return Colors.red;
      case 'withdrawn': return Colors.grey;
      default: return darkTeal;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'applied': return Icons.send;
      case 'under_review': return Icons.visibility;
      case 'shortlisted': return Icons.star;
      case 'interview': return Icons.event;
      case 'hired': return Icons.check_circle;
      case 'rejected': return Icons.close;
      case 'withdrawn': return Icons.cancel_outlined;
      default: return Icons.work;
    }
  }

  Future<void> _selectInterviewDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
      );
      
      if (time != null) {
        setState(() {
          _selectedInterviewDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header with clear visual hierarchy
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.newStatus).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(widget.newStatus).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _getStatusIcon(widget.newStatus),
                    color: _getStatusColor(widget.newStatus),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Status',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getApplicantName(widget.application),
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
            
            // Clear Status Change Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(widget.newStatus).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _getStatusColor(widget.newStatus).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_forward,
                    color: _getStatusColor(widget.newStatus),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Changing status to: ${_getStatusDisplayName(widget.newStatus)}',
                      style: TextStyle(
                        color: _getStatusColor(widget.newStatus),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Interview Date Selection (if applicable)
            if (widget.newStatus == 'interview') ...[
              Text(
                'Interview Details',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              GestureDetector(
                onTap: _selectInterviewDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightMint.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: paleGreen.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        color: darkTeal.withValues(alpha: 0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedInterviewDate != null
                              ? 'Interview: ${_formatDateTime(_selectedInterviewDate!)}'
                              : 'Select Interview Date & Time',
                          style: TextStyle(
                            color: _selectedInterviewDate != null 
                                ? darkTeal 
                                : darkTeal.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: _selectedInterviewDate != null 
                                ? FontWeight.w600 
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: darkTeal.withValues(alpha: 0.7),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
            
            // Rating Selection (if applicable)
            if (widget.newStatus == 'hired' || widget.newStatus == 'rejected') ...[
              Text(
                'Rate Candidate',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              Row(
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRating = rating;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: Icon(
                        rating <= (_selectedRating ?? 0) ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 20),
            ],
            
            // Notes
            Text(
              'Notes (Optional)',
              style: TextStyle(
                color: darkTeal,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Add notes about this status change...',
                hintStyle: TextStyle(
                  color: darkTeal.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: paleGreen.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: mediumSeaGreen,
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Enhanced Action Buttons with clear CTAs
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: darkTeal,
                      side: BorderSide(color: darkTeal.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onUpdate(
                        widget.newStatus,
                        _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                        _selectedInterviewDate,
                        _selectedRating,
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getStatusColor(widget.newStatus),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                    ),
                    child: Text(
                      'Confirm Update',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getApplicantName(Map<String, dynamic> application) {
    final fullName = application['profiles']?['full_name']?.toString().trim() ?? '';
    return fullName.isEmpty ? 'Unknown Applicant' : fullName;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

