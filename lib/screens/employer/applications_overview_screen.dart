import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_service.dart';
import '../../services/chat_service.dart';
import '../../services/ai_screening_service.dart';
import 'applications_screen.dart';
import 'chat_screen.dart';

class ApplicationsOverviewScreen extends StatefulWidget {
  const ApplicationsOverviewScreen({super.key});

  @override
  State<ApplicationsOverviewScreen> createState() => _ApplicationsOverviewScreenState();
}

class _ApplicationsOverviewScreenState extends State<ApplicationsOverviewScreen> with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allApplications = [];
  List<Map<String, dynamic>> _aiResults = []; // Add AI results
  bool _isLoading = true;
  bool _isAIScreening = false; // Add AI screening state
  String _selectedFilter = 'all';
  String _searchQuery = '';

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
    'shortlisted',
    'interview',
    'hired',
    'rejected',
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
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    try {
      setState(() => _isLoading = true);
      
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get user's company
      final company = await JobService.getUserCompany(user.id);
      if (company == null) return;

      // Get all jobs for the company
      final jobs = await JobService.getJobsByCompany(company['id']);
      
      // Get applications for each job
      List<Map<String, dynamic>> allApplications = [];
      for (final job in jobs) {
        final applications = await JobService.getJobApplications(job['id']);
        for (final application in applications) {
          // Add job info to each application
          application['job'] = job;
          allApplications.add(application);
        }
      }

      setState(() {
        _allApplications = allApplications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load applications: $e');
    }
  }

  Future<void> _loadAIScreeningResults() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get user's company
      final company = await JobService.getUserCompany(user.id);
      if (company == null) return;

      // Get all jobs for the company
      final jobs = await JobService.getJobsByCompany(company['id']);
      
      // Get AI results for all jobs
      List<Map<String, dynamic>> allAIResults = [];
      for (final job in jobs) {
        final results = await AIScreeningService.getScreeningResults(job['id']);
        allAIResults.addAll(results);
      }
      
      setState(() {
        _aiResults = allAIResults;
      });
    } catch (e) {
      debugPrint('Error loading AI results: $e');
    }
  }

  Future<void> _screenAllApplications() async {
    setState(() {
      _isAIScreening = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get user's company
      final company = await JobService.getUserCompany(user.id);
      if (company == null) return;

      // Get all jobs for the company
      final jobs = await JobService.getJobsByCompany(company['id']);
      
      int totalProcessed = 0;
      for (final job in jobs) {
        final results = await AIScreeningService.screenAllApplications(job['id']);
        totalProcessed += results.length;
      }
      
      // Reload results after screening
      await _loadAIScreeningResults();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI screening completed! Processed $totalProcessed applications.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during AI screening: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isAIScreening = false;
      });
    }
  }

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

  String _getRecommendationText(String? recommendation) {
    if (recommendation == null) return 'No Recommendation';
    
    switch (recommendation) {
      case 'strong_match': return 'Strong Match';
      case 'good_match': return 'Good Match';
      case 'weak_match': return 'Weak Match';
      case 'not_suitable': return 'Not Suitable';
      default: return 'Unknown';
    }
  }

  List<Map<String, dynamic>> get _filteredApplications {
    List<Map<String, dynamic>> filtered = _allApplications;

    // Filter by status
    if (_selectedFilter != 'all') {
      filtered = filtered.where((app) => app['status'] == _selectedFilter).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((app) {
        final jobTitle = app['job']?['title']?.toString().toLowerCase() ?? '';
        final applicantName = _getApplicantName(app).toLowerCase();
        final query = _searchQuery.toLowerCase();
        
        return jobTitle.contains(query) || applicantName.contains(query);
      }).toList();
    }

    return filtered;
  }

  String _getApplicantName(Map<String, dynamic> application) {
    final profiles = application['profiles'];
    if (profiles == null) return 'Unknown Applicant';
    
    final fullName = profiles['full_name']?.toString().trim() ?? '';
    
    if (fullName.isEmpty) {
      return 'Unknown Applicant';
    }
    
    return fullName;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
              ),
            )
          : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'All Applications',
        style: TextStyle(
          color: darkTeal,
          fontWeight: FontWeight.bold,
          fontSize: 18,
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
        IconButton(
          onPressed: _loadApplications,
          icon: const Icon(
            Icons.refresh,
            color: mediumSeaGreen,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            // Compact header with key stats
            _buildCompactHeader(),
            
            // Search and filter section
            _buildSearchAndFilter(),
            
            // Applications list
            Expanded(
              child: _filteredApplications.isEmpty
                  ? _buildEmptyState()
                  : _buildApplicationsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    final totalApplications = _allApplications.length;
    final appliedCount = _allApplications.where((app) => app['status'] == 'applied').length;
    final hiredCount = _allApplications.where((app) => app['status'] == 'hired').length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // AI Screening Button and Quick Stats
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isAIScreening ? null : _screenAllApplications,
                  icon: _isAIScreening 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(
                    _isAIScreening ? 'Screening...' : 'AI Screening',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mediumSeaGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _buildQuickStat('Total', '$totalApplications', mediumSeaGreen),
                    const SizedBox(width: 8),
                    _buildQuickStat('Applied', '$appliedCount', paleGreen),
                    const SizedBox(width: 8),
                    _buildQuickStat('Hired', '$hiredCount', Colors.green),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
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
              color: color.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: lightMint,
              borderRadius: BorderRadius.circular(12),
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
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search applications...',
                      hintStyle: TextStyle(
                        color: darkTeal.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: Icon(
                      Icons.clear,
                      color: darkTeal.withValues(alpha: 0.6),
                      size: 18,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Compact filter chips
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: EdgeInsets.only(right: index < _statusFilters.length - 1 ? 6 : 0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? mediumSeaGreen : lightMint,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? mediumSeaGreen : paleGreen,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        filter == 'all' ? 'All' : _formatStatusDisplay(filter),
                        style: TextStyle(
                          color: isSelected ? Colors.white : darkTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: lightMint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 48,
                color: darkTeal.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'No Applications Found'
                  : 'No Applications Yet',
              style: const TextStyle(
                color: darkTeal,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'all'
                  ? 'Try adjusting your search criteria or filters'
                  : 'Applications will appear here once candidates apply to your jobs',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (_searchQuery.isNotEmpty || _selectedFilter != 'all') ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedFilter = 'all';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mediumSeaGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Clear Filters',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: _filteredApplications.length,
      itemBuilder: (context, index) {
        final application = _filteredApplications[index];
        return _buildApplicationCard(application);
      },
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final job = application['job'];
    final profiles = application['profiles'];
    final applicantName = _getApplicantName(application);
    final status = application['status'] ?? 'applied';
    final aiResult = _getAIResult(application['id']);
    final profileCompleteness = application['profile_completeness_score'] ?? 0;
    final applicationSource = application['application_source'] ?? 'direct';
    final employerRating = application['employer_rating'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with avatar, name, email, and status
          Row(
            children: [
              // Compact avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: mediumSeaGreen.withValues(alpha: 0.1),
                child: Text(
                  applicantName.isNotEmpty ? applicantName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: mediumSeaGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // Applicant info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      applicantName,
                      style: const TextStyle(
                        color: darkTeal,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      profiles?['email'] ?? '',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
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
          
          const SizedBox(height: 8),
          
          // Job title and location in one compact row
          Row(
            children: [
              Icon(
                Icons.work_outline,
                color: mediumSeaGreen,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  job?['title'] ?? 'Unknown Job',
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.location_on_outlined,
                color: darkTeal.withValues(alpha: 0.5),
                size: 12,
              ),
              const SizedBox(width: 2),
              Text(
                job?['location'] ?? 'Remote',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          
          // Compact info row with AI score, profile completeness, and source
          const SizedBox(height: 6),
          Row(
            children: [
              // AI Score
              if (aiResult != null) ...[
                Icon(
                  Icons.auto_awesome,
                  color: Colors.blue,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  '${aiResult['overall_score'] ?? 0}/10',
                  style: TextStyle(
                    color: _getScoreColor(aiResult['overall_score']),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              // Profile Completeness
              if (profileCompleteness > 0) ...[
                Icon(
                  Icons.person_outline,
                  color: profileCompleteness >= 80 ? mediumSeaGreen : Colors.orange,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  '$profileCompleteness%',
                  style: TextStyle(
                    color: profileCompleteness >= 80 ? mediumSeaGreen : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              // Application Source
              Icon(
                _getSourceIcon(applicationSource),
                color: darkTeal.withValues(alpha: 0.5),
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                _formatApplicationSource(applicationSource),
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              
              // Employer Rating
              if (employerRating != null) ...[
                const Spacer(),
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 12,
                ),
                const SizedBox(width: 2),
                Text(
                  '$employerRating',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Compact action buttons
          Row(
            children: [
              // AI Analysis button (if available)
              if (aiResult != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAIDetails(application, aiResult),
                    icon: const Icon(Icons.auto_awesome, size: 12),
                    label: const Text('AI', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              
              // Chat button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startChatWithApplicant(application, job),
                  icon: const Icon(Icons.chat, size: 12),
                  label: const Text('Chat', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    elevation: 0,
                  ),
                ),
              ),
              
              const SizedBox(width: 6),
              
              // View Details button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToJobApplications(job),
                  icon: const Icon(Icons.visibility, size: 12),
                  label: const Text('View', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mediumSeaGreen,
                    side: const BorderSide(color: mediumSeaGreen, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'applied':
        return mediumSeaGreen;
      case 'shortlisted':
        return Colors.orange;
      case 'interview':
        return Colors.blue;
      case 'hired':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return darkTeal;
    }
  }

  String _formatStatusDisplay(String status) {
    switch (status) {
      case 'applied':
        return 'Applied';
      case 'shortlisted':
        return 'Shortlisted';
      case 'interview':
        return 'Interview';
      case 'hired':
        return 'Hired';
      case 'rejected':
        return 'Rejected';
      default:
        return status.toUpperCase();
    }
  }

  void _navigateToJobApplications(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplicationsScreen(job: job),
      ),
    );
  }

  Future<void> _startChatWithApplicant(Map<String, dynamic> application, Map<String, dynamic> job) async {
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
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        Navigator.pop(context); // Close loading dialog
        _showErrorSnackBar('User not authenticated');
        return;
      }

      // Get applicant info
      final applicantId = application['applicant_id'];
      final applicantName = _getApplicantName(application);
      final jobTitle = job['title'] ?? 'Job Application';

      // Create or get chat
      final chatId = await ChatService.createOrGetChat(
        jobId: job['id'],
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
      _showErrorSnackBar('Failed to start chat: $e');
    }
  }

  void _showAIDetails(Map<String, dynamic> application, Map<String, dynamic> aiResult) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAIDetailsSheet(application, aiResult),
    );
  }

  Widget _buildAIDetailsSheet(Map<String, dynamic> application, Map<String, dynamic> aiResult) {
    final applicant = application['profiles'] ?? {};
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: darkTeal.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Compact Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withValues(alpha: 0.1),
                        Colors.blue.withValues(alpha: 0.05),
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
                              return _buildAvatarPlaceholder(_getApplicantName(application));
                            },
                          ),
                        )
                      : _buildAvatarPlaceholder(_getApplicantName(application)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Analysis Report',
                        style: const TextStyle(
                          color: darkTeal,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _getApplicantName(application),
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: darkTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: darkTeal,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compact Overall Score
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getScoreColor(aiResult['overall_score']).withValues(alpha: 0.08),
                          _getScoreColor(aiResult['overall_score']).withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getScoreColor(aiResult['overall_score']).withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: _getScoreColor(aiResult['overall_score']),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Overall Score',
                              style: const TextStyle(
                                color: darkTeal,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${aiResult['overall_score'] ?? 0}/10',
                          style: TextStyle(
                            color: _getScoreColor(aiResult['overall_score']),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getScoreColor(aiResult['overall_score']).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getRecommendationText(aiResult['recommendation']),
                            style: TextStyle(
                              color: _getScoreColor(aiResult['overall_score']),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Detailed Scores
                  Text(
                    'Detailed Analysis',
                    style: const TextStyle(
                      color: darkTeal,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Skills Analysis
                  if (aiResult['skills_analysis'] != null) ...[
                    _buildAnalysisSection(
                      'Skills Match',
                      aiResult['skills_match_score'],
                      aiResult['skills_analysis'],
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Experience Analysis
                  if (aiResult['experience_analysis'] != null) ...[
                    _buildAnalysisSection(
                      'Experience Match',
                      aiResult['experience_match_score'],
                      aiResult['experience_analysis'],
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Education Analysis
                  if (aiResult['education_analysis'] != null) ...[
                    _buildAnalysisSection(
                      'Education Match',
                      aiResult['education_match_score'],
                      aiResult['education_analysis'],
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Strengths
                  if (aiResult['strengths'] != null && (aiResult['strengths'] as List).isNotEmpty) ...[
                    _buildListSection(
                      'Strengths',
                      aiResult['strengths'],
                      Colors.green,
                      Icons.check_circle,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Concerns
                  if (aiResult['concerns'] != null && (aiResult['concerns'] as List).isNotEmpty) ...[
                    _buildListSection(
                      'Areas of Concern',
                      aiResult['concerns'],
                      Colors.orange,
                      Icons.warning,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Reasoning
                  if (aiResult['reasoning'] != null) ...[
                    _buildReasoningSection(aiResult['reasoning']),
                    const SizedBox(height: 12),
                  ],
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection(String title, double score, Map<String, dynamic> analysis) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: darkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${score}/10',
                style: TextStyle(
                  color: _getScoreColor(score),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...analysis.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.key}: ',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: const TextStyle(
                      color: darkTeal,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<dynamic> items, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: darkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.toString(),
                    style: const TextStyle(
                      color: darkTeal,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildReasoningSection(String reasoning) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.blue, size: 16),
              const SizedBox(width: 6),
              Text(
                'AI Reasoning',
                style: const TextStyle(
                  color: darkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reasoning,
            style: const TextStyle(
              color: darkTeal,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: mediumSeaGreen,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Helper methods for new enhanced fields
  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'mobile_app':
        return Icons.phone_android;
      case 'web_app':
        return Icons.web;
      case 'linkedin':
        return Icons.link;
      case 'referral':
        return Icons.group;
      case 'job_board':
        return Icons.work;
      default:
        return Icons.touch_app;
    }
  }

  String _formatApplicationSource(String source) {
    switch (source) {
      case 'mobile_app':
        return 'Mobile';
      case 'web_app':
        return 'Web';
      case 'linkedin':
        return 'LinkedIn';
      case 'referral':
        return 'Referral';
      case 'job_board':
        return 'Job Board';
      case 'direct':
        return 'Direct';
      default:
        return source.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
    }
  }
}
