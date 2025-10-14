import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';
import '../../services/chat_service.dart';
import '../../utils/formatters.dart';
import 'home_screen.dart';
import 'chat_list_screen.dart';

final supabase = Supabase.instance.client;

class ApplicantApplicationsScreen extends StatefulWidget {
  const ApplicantApplicationsScreen({super.key});

  @override
  State<ApplicantApplicationsScreen> createState() => _ApplicantApplicationsScreenState();
}

class _ApplicantApplicationsScreenState extends State<ApplicantApplicationsScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  final Map<String, bool> _applicationChatStatus = {}; // Track chat status for each application
  // Multiple job types support
  Map<String, List<Map<String, dynamic>>> _jobTypesByJobId = {}; // jobId -> [{job_type_id,is_primary}]
  Map<String, String> _jobTypeNames = {}; // job_type_id -> display_name
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    _loadJobTypeCatalog();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final applications = await JobService.getUserApplications(user.id);
        
        // Check chat status for each application
        await _checkChatStatusForApplications(applications, user.id);
        // Prefetch job types for jobs in the result
        await _prefetchJobTypes(applications);
        
        setState(() {
          _applications = applications;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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

  Future<void> _prefetchJobTypes(List<Map<String, dynamic>> applications) async {
    try {
      final Set<String> jobIds = {};
      for (final a in applications) {
        final jobId = a['jobs']?['id']?.toString();
        if (jobId != null) jobIds.add(jobId);
      }
      final Map<String, List<Map<String, dynamic>>> temp = {};
      for (final jobId in jobIds) {
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

  Future<void> _checkChatStatusForApplications(List<Map<String, dynamic>> applications, String userId) async {
    try {
      // Get all user chats to check which applications have active chats
      final userChats = await ChatService.getUserChats(userId);
      
      // Create a map of job_id to chat existence
      final Map<String, bool> chatStatusMap = {};
      
      for (final chat in userChats) {
        final jobId = chat.jobId;
        if (jobId != null) {
          chatStatusMap[jobId] = true;
        }
      }
      
      // Update chat status for each application
      for (final application in applications) {
        final jobId = application['jobs']?['id']?.toString();
        if (jobId != null) {
          _applicationChatStatus[application['id']] = chatStatusMap[jobId] ?? false;
        }
      }
    } catch (e) {
      // If chat check fails, just continue without chat indicators
      debugPrint('Error checking chat status: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredApplications {
    if (_selectedStatus == 'all') {
      return _applications;
    }
    return _applications.where((app) => app['status'] == _selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
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
            child: const Icon(
              Icons.arrow_back,
              color: darkTeal,
              size: 20,
            ),
          ),
        ),
        title: const Text(
          'My Applications',
          style: TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
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
        // Statistics
        _buildStatistics(),
        
        // Filter tabs
        _buildFilterTabs(),
        
        // Applications list
        Expanded(
          child: _filteredApplications.isEmpty
              ? _buildEmptyState()
              : _buildApplicationsList(),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    final totalApplications = _applications.length;
    final activeApplications = _applications.where((app) => 
      ['applied', 'under_review', 'shortlisted', 'interview'].contains(app['status'])
    ).length;
    final hired = _applications.where((app) => app['status'] == 'hired').length;
    final rejected = _applications.where((app) => app['status'] == 'rejected').length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Application Overview',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [mediumSeaGreen, mediumSeaGreen.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$totalApplications Total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Compact statistics cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Active',
                  activeApplications.toString(),
                  Icons.trending_up,
                  mediumSeaGreen,
                  'In Progress',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Hired',
                  hired.toString(),
                  Icons.celebration,
                  Colors.green,
                  'Success!',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Rejected',
                  rejected.toString(),
                  Icons.cancel_outlined,
                  Colors.red.shade400,
                  'Declined',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: darkTeal,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Status',
            style: TextStyle(
              color: darkTeal,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
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
                  margin: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStatus = status;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isSelected 
                            ? LinearGradient(
                                colors: [mediumSeaGreen, mediumSeaGreen.withValues(alpha: 0.8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? mediumSeaGreen : Colors.grey.shade300,
                          width: 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: mediumSeaGreen.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ] : [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
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
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : mediumSeaGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
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
          ),
        ],
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: lightMint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.work_outline,
                size: 64,
                color: mediumSeaGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Applications Found',
              style: TextStyle(
                color: darkTeal,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStatus == 'all' 
                  ? 'Start applying to jobs to see your applications here'
                  : 'No applications found for the selected status filter',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.6),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_selectedStatus != 'all') ...[
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = 'all';
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: mediumSeaGreen,
                      side: const BorderSide(color: mediumSeaGreen),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Show All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text(
                    'Browse Jobs',
                    style: TextStyle(
                      fontSize: 12,
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: _filteredApplications.length,
      itemBuilder: (context, index) {
        final application = _filteredApplications[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildApplicationCard(application, index),
        );
      },
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application, int index) {
    final job = application['jobs'] ?? {};
    final company = job['companies'] ?? {};
    final status = application['status'] ?? 'applied';

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(status).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with enhanced design
          Row(
            children: [
              // Company logo with enhanced styling
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getStatusColor(status).withValues(alpha: 0.1),
                      _getStatusColor(status).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getStatusColor(status).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: company['logo_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          company['logo_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildCompanyPlaceholder(company['name'] ?? 'C');
                          },
                        ),
                      )
                    : _buildCompanyPlaceholder(company['name'] ?? 'C'),
              ),
              
              const SizedBox(width: 16),
              
              // Job info with enhanced typography
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
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      company['name'] ?? 'Company',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Status badge and chat indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chat indicator
                  if (_applicationChatStatus[application['id']] == true) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.blue,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Chat',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getStatusColor(status).withValues(alpha: 0.1),
                          _getStatusColor(status).withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _getStatusColor(status).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatStatusDisplay(status),
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Enhanced job details section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lightMint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: mediumSeaGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        job['location'] ?? 'Location not specified',
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.work_outline,
                      color: mediumSeaGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatJobTypesDisplay(job),
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Full job types chips (if available)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildJobTypeChips(job),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      color: mediumSeaGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Applied ${_formatDate(application['created_at'])}',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.7),
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
          
          // Enhanced action buttons
          Row(
            children: [
              // Chat button (only show if chat exists)
              if (_applicationChatStatus[application['id']] == true) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openChat(application),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showApplicationDetails(application),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mediumSeaGreen,
                    side: const BorderSide(color: mediumSeaGreen, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Removed Job Details button per request
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showWithdrawDialog(application);
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text(
                    'Withdraw',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyPlaceholder(String name) {
    return Center(
      child: Text(
        name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: mediumSeaGreen,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _openChat(Map<String, dynamic> application) {
    // Navigate to chat list screen with a filter for this specific job
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ApplicantChatListScreen(),
      ),
    );
  }

  void _showWithdrawDialog(Map<String, dynamic> application) {
    final job = application['jobs'] ?? {};
    final company = job['companies'] ?? {};
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _WithdrawApplicationDialog(
          application: application,
          job: job,
          company: company,
          onWithdraw: (reason, category) => _processWithdrawal(application, reason, category),
        );
      },
    );
  }

  Future<void> _processWithdrawal(Map<String, dynamic> application, String? reason, String? category) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await JobService.withdrawApplication(
        applicationId: application['id'],
        withdrawalReason: reason,
        withdrawalCategory: category,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result['success'] == true) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result['message'] ?? 'Application withdrawn successfully',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: mediumSeaGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Refresh applications list
        await _loadApplications();
      } else {
        // Show specific error message based on error code
        final errorCode = result['code'] as String?;
        final errorMessage = _getWithdrawalErrorMessage(errorCode, result['error']);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error during withdrawal process: $e');
      
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'An unexpected error occurred. Please try again later.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _getWithdrawalErrorMessage(String? errorCode, dynamic error) {
    switch (errorCode) {
      case 'AUTH_ERROR':
        return 'Please log in to withdraw your application';
      case 'NOT_FOUND':
        return 'Application not found. It may have been already removed.';
      case 'UNAUTHORIZED':
        return 'You are not authorized to withdraw this application';
      case 'ALREADY_WITHDRAWN':
        return 'This application has already been withdrawn';
      case 'CANNOT_WITHDRAW_HIRED':
        return 'Cannot withdraw an accepted job offer';
      case 'SYSTEM_ERROR':
      default:
        return error?.toString() ?? 'Failed to withdraw application. Please try again.';
    }
  }

  void _showApplicationDetails(Map<String, dynamic> application) {
    final job = application['jobs'] ?? {};
    final company = job['companies'] ?? {};
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
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
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header with enhanced design
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    lightMint.withValues(alpha: 0.3),
                    Colors.white,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
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
                    ),
                    child: company['logo_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              company['logo_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildCompanyPlaceholder(company['name'] ?? 'C');
                              },
                            ),
                          )
                        : _buildCompanyPlaceholder(company['name'] ?? 'C'),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['title'] ?? 'Untitled Job',
                          style: const TextStyle(
                            color: darkTeal,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          company['name'] ?? 'Company',
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(application['status'] ?? 'applied').withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(application['status'] ?? 'applied'),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatStatusDisplay(application['status'] ?? 'applied'),
                                    style: TextStyle(
                                      color: _getStatusColor(application['status'] ?? 'applied'),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Chat indicator in modal
                            if (_applicationChatStatus[application['id']] == true) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      color: Colors.blue,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Chat Available',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
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
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Application Status Timeline
                    _buildStatusTimeline(application),
                    
                    const SizedBox(height: 24),
                    
                    // Job Details
                    const Text(
                      'Job Details',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Location', job['location'] ?? 'Not specified'),
                    // Replace single-line Type with chips list
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Type',
                              style: TextStyle(
                                color: darkTeal.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(child: _buildJobTypeChips(job)),
                        ],
                      ),
                    ),
                    _buildInfoRow('Experience', job['experience_level'] ?? 'Not specified'),
                    if (job['salary_min'] != null || job['salary_max'] != null)
                      _buildInfoRow('Salary', Formatters.formatSalaryRange(job['salary_min'], job['salary_max'])),
                    
                    const SizedBox(height: 24),
                    
                    // Application Details
                    const Text(
                      'Application Details',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Applied', _formatDate(application['created_at'])),
                    _buildInfoRow('Status', _formatStatusDisplay(application['status'] ?? 'applied')),
                    if (application['cover_letter'] != null && application['cover_letter'].toString().isNotEmpty)
                      _buildInfoRow('Cover Letter', 'Submitted'),
                    if (application['resume_url'] != null)
                      _buildInfoRow('Resume', 'Submitted'),
                  ],
                ),
              ),
            ),
            
            // Action buttons with enhanced design
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Primary actions
                  Row(
                    children: [
                      // Chat button (only show if chat exists)
                      if (_applicationChatStatus[application['id']] == true) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _openChat(application);
                            },
                            icon: const Icon(Icons.chat_bubble_outline, size: 16),
                            label: const Text(
                              'Open Chat',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HomeScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text(
                            'Browse Jobs',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: mediumSeaGreen,
                            side: const BorderSide(color: mediumSeaGreen, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showWithdrawDialog(application);
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text(
                            'Withdraw',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Secondary action
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: darkTeal.withValues(alpha: 0.7),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(Map<String, dynamic> application) {
    final status = application['status'] ?? 'applied';
    final statuses = ['applied', 'under_review', 'shortlisted', 'interview', 'hired', 'rejected'];
    final currentIndex = statuses.indexOf(status);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Application Timeline',
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...statuses.asMap().entries.map((entry) {
          final index = entry.key;
          final statusName = entry.value;
          final isCompleted = index <= currentIndex;
          final isCurrent = index == currentIndex;
          
          return Row(
            children: [
              // Timeline dot
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isCompleted ? mediumSeaGreen : Colors.grey.shade300,
                  shape: BoxShape.circle,
                  border: isCurrent ? Border.all(color: mediumSeaGreen, width: 3) : null,
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      )
                    : null,
              ),
              
              // Timeline line
              if (index < statuses.length - 1)
                Container(
                  width: 2,
                  height: 30,
                  color: isCompleted ? mediumSeaGreen : Colors.grey.shade300,
                  margin: const EdgeInsets.only(left: 9),
                ),
              
              const SizedBox(width: 16),
              
              // Status info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatStatusDisplay(statusName),
                      style: TextStyle(
                        color: isCompleted ? darkTeal : Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isCurrent)
                      Text(
                        'Current status',
                        style: TextStyle(
                          color: mediumSeaGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: darkTeal,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      case 'withdrawn':
        return Colors.grey; // Grey - Withdrawn by applicant
      default:
        return darkTeal;
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

}

// Helpers for multiple job types formatting
extension on _ApplicantApplicationsScreenState {
  String _formatJobTypesDisplay(Map<String, dynamic> job) {
    final jobId = job['id']?.toString();
    final types = jobId != null ? _jobTypesByJobId[jobId] : null;
    if (types != null && types.isNotEmpty) {
      String? primaryId;
      for (final t in types) {
        if (t['is_primary'] == true) {
          primaryId = t['job_type_id']?.toString();
          break;
        }
      }
      primaryId ??= types.first['job_type_id']?.toString();
      final primaryName = _jobTypeNames[primaryId ?? ''] ?? 'Unknown';
      if (types.length == 1) return primaryName;
      return '$primaryName +${types.length - 1}';
    }

    // Fallback to legacy single type enum
    return Formatters.formatJobTypeDisplay(job['type'] ?? 'full_time');
  }

  Widget _buildJobTypeChips(Map<String, dynamic> job) {
    final jobId = job['id']?.toString();
    final types = jobId != null ? _jobTypesByJobId[jobId] : null;
    if (types == null || types.isEmpty) {
      // Fallback to single type chip if legacy type exists
      final legacy = Formatters.formatJobTypeDisplay(job['type'] ?? 'full_time');
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _ApplicantApplicationsScreenState.mediumSeaGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _ApplicantApplicationsScreenState.mediumSeaGreen.withValues(alpha: 0.3), width: 1),
            ),
            child: Text(
              legacy,
              style: const TextStyle(
                color: _ApplicantApplicationsScreenState.mediumSeaGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    // Render chips for all job types; star the primary
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: types.map((t) {
        final id = t['job_type_id']?.toString() ?? '';
        final isPrimary = t['is_primary'] == true;
        final name = _jobTypeNames[id] ?? 'Unknown';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isPrimary ? _ApplicantApplicationsScreenState.mediumSeaGreen : _ApplicantApplicationsScreenState.mediumSeaGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary ? _ApplicantApplicationsScreenState.mediumSeaGreen : _ApplicantApplicationsScreenState.mediumSeaGreen.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: isPrimary ? Colors.white : _ApplicantApplicationsScreenState.mediumSeaGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isPrimary) ...[
                const SizedBox(width: 4),
                const Icon(Icons.star, size: 12, color: Colors.white),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _WithdrawApplicationDialog extends StatefulWidget {
  final Map<String, dynamic> application;
  final Map<String, dynamic> job;
  final Map<String, dynamic> company;
  final Function(String?, String?) onWithdraw;

  const _WithdrawApplicationDialog({
    required this.application,
    required this.job,
    required this.company,
    required this.onWithdraw,
  });

  @override
  State<_WithdrawApplicationDialog> createState() => _WithdrawApplicationDialogState();
}

// Color constants for the withdrawal dialog
const Color _dialogDarkTeal = Color(0xFF013237);
const Color _dialogLightMint = Color(0xFFEAF9E7);
const Color _dialogPaleGreen = Color(0xFFC0E6BA);
const Color _dialogMediumSeaGreen = Color(0xFF4CA771);

class _WithdrawApplicationDialogState extends State<_WithdrawApplicationDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedReason;
  bool _isLoading = false;

  final List<String> _commonReasons = [
    'Found another opportunity',
    'Changed my mind about the role',
    'Salary expectations not met',
    'Location not suitable',
    'Application process too complex',
    'Timing not right',
    'Other',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.cancel_outlined,
              color: Colors.red.shade400,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Withdraw Application',
              style: const TextStyle(
                color: _dialogDarkTeal,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _dialogLightMint.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _dialogPaleGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.job['title'] ?? 'Untitled Job',
                    style: const TextStyle(
                      color: _dialogDarkTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.company['name'] ?? 'Company',
                    style: TextStyle(
                      color: _dialogDarkTeal.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Withdrawal reason selection
            Text(
              'Reason for withdrawal (optional):',
              style: const TextStyle(
                color: _dialogDarkTeal,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            
            // Quick reason selection
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _commonReasons.map((reason) {
                final isSelected = _selectedReason == reason;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedReason = isSelected ? null : reason;
                      if (!isSelected) {
                        _reasonController.clear();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? _dialogMediumSeaGreen : _dialogLightMint,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? _dialogMediumSeaGreen : _dialogPaleGreen,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      reason,
                      style: TextStyle(
                        color: isSelected ? Colors.white : _dialogDarkTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 12),
            
            // Custom reason text field
            TextField(
              controller: _reasonController,
              maxLines: 2,
              maxLength: 200,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    _selectedReason = null;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Or provide additional details...',
                hintStyle: TextStyle(
                  color: _dialogDarkTeal.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _dialogPaleGreen,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _dialogMediumSeaGreen,
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
                counterStyle: TextStyle(
                  color: _dialogDarkTeal.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
              style: const TextStyle(fontSize: 11),
            ),
            
            const SizedBox(height: 12),
            
            // Warning message
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.red.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. You\'ll need to apply again if you change your mind.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: _dialogDarkTeal.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () {
            setState(() {
              _isLoading = true;
            });
            
            final reason = _selectedReason ?? 
                          (_reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null);
            final category = _selectedReason; // Use selected reason as category
            
            widget.onWithdraw(reason, category);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade400,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Withdraw',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}
