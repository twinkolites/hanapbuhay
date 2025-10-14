import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/job_service.dart';
import '../../widgets/job_card_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _allJobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  List<Map<String, dynamic>> _availableJobTypes = [];
  Map<String, String> _jobTypeNames = {}; // job_type_id -> display_name
  bool _isLoading = true;
  bool _isSearching = false;
  
  // Save job optimization
  Map<String, bool> _savedJobs = {};
  Timer? _debounceTimer;
  final Set<String> _pendingSaveOperations = {};

  // Search and filter controllers
  final _searchController = TextEditingController();
  
  // Applied filters (what's currently active)
  String _appliedLocation = 'all';
  String _appliedExperience = 'all';
  String _appliedIndustry = 'all';
  String _appliedCompanySize = 'all';
  RangeValues _appliedSalaryRange = const RangeValues(0, 500000);
  bool _appliedShowRemoteOnly = false;
  
  // Temporary filters (in the filter modal, not yet applied)
  String _tempLocation = 'all';
  String _tempExperience = 'all';
  String _tempIndustry = 'all';
  String _tempCompanySize = 'all';
  RangeValues _tempSalaryRange = const RangeValues(0, 500000);
  bool _tempShowRemoteOnly = false;
  List<String> _tempJobTypeIds = ['all'];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  // Applied job types (what's currently active)
  List<String> _appliedJobTypeIds = ['all'];
  
  // Filter presets
  final Map<String, Map<String, dynamic>> _filterPresets = {
    'remote': {
      'name': 'Remote Only',
      'icon': Icons.home_work,
      'filters': {'showRemoteOnly': true},
    },
    'entry': {
      'name': 'Entry Level',
      'icon': Icons.school,
      'filters': {'experience': 'entry'},
    },
    'senior': {
      'name': 'Senior Roles',
      'icon': Icons.workspace_premium,
      'filters': {'experience': 'senior'},
    },
    'high_salary': {
      'name': 'High Salary',
      'icon': Icons.attach_money,
      'filters': {'salaryMin': 100000.0},
    },
  };
  

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
    
    _loadJobs();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      List<Map<String, dynamic>> jobs;
      
      if (user != null) {
        // OPTIMIZED: Use single query to get jobs with saved status
        debugPrint('🚀 Loading jobs with saved status (OPTIMIZED)');
        jobs = await JobService.getAllJobsWithSavedStatus(user.id);
        
        // Extract saved status from jobs
        final savedJobs = <String, bool>{};
        for (final job in jobs) {
          final jobId = job['id'] as String;
          final isSaved = job['is_saved'] as bool? ?? false;
          savedJobs[jobId] = isSaved;
          // Remove is_saved from job object to keep it clean
          job.remove('is_saved');
        }
        
        if (mounted) {
          setState(() {
            _savedJobs = savedJobs;
          });
        }
        
        debugPrint('✅ Loaded ${jobs.length} jobs with saved status in single query');
      } else {
        // User not logged in, just load jobs without saved status
        jobs = await JobService.getAllJobs();
        debugPrint('✅ Loaded ${jobs.length} jobs (no user)');
      }
      
      // Load available job types from database
      await _loadJobTypes();
      _buildJobTypeNameMap();
      await _prefetchAndAttachJobTypes(jobs);
      
      if (mounted) {
        setState(() {
          _allJobs = jobs;
          _filteredJobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading jobs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadJobTypes() async {
    try {
      final response = await Supabase.instance.client
          .from('job_types')
          .select('id, name, display_name')
          .eq('is_active', true)
          .order('sort_order');
      
      if (mounted) {
        setState(() {
          _availableJobTypes = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading job types: $e');
    }
  }

  void _buildJobTypeNameMap() {
    final Map<String, String> names = {};
    for (final t in _availableJobTypes) {
      final id = t['id']?.toString();
      if (id != null) {
        names[id] = (t['display_name'] ?? t['name'] ?? 'Unknown').toString();
      }
    }
    _jobTypeNames = names;
  }

  Future<void> _prefetchAndAttachJobTypes(List<Map<String, dynamic>> jobs) async {
    try {
      // Enrich each job with job_types and primary_job_type using mapping table
      for (final job in jobs) {
        final jobId = job['id']?.toString();
        if (jobId == null) continue;
        final mappings = await JobService.getJobTypesForJob(jobId);
        if (mappings.isEmpty) continue;
        String? primaryId;
        for (final m in mappings) {
          if (m['is_primary'] == true) {
            primaryId = m['job_type_id']?.toString();
            break;
          }
        }
        primaryId ??= mappings.first['job_type_id']?.toString();

        // Build enriched list
        final List<Map<String, dynamic>> namedTypes = mappings.map((m) {
          final id = m['job_type_id']?.toString();
          return {
            'id': id,
            'display_name': _jobTypeNames[id ?? ''] ?? 'Unknown',
            'name': _jobTypeNames[id ?? ''] ?? 'Unknown',
          };
        }).toList();

        job['job_types'] = namedTypes;
        job['primary_job_type'] = primaryId != null
            ? {
                'id': primaryId,
                'display_name': _jobTypeNames[primaryId] ?? 'Unknown',
                'name': _jobTypeNames[primaryId] ?? 'Unknown',
              }
            : null;
      }
    } catch (e) {
      debugPrint('Error prefetching job types: $e');
    }
  }


  void _performSearch() {
    setState(() {
      _isSearching = true;
    });

    final searchQuery = _searchController.text.toLowerCase().trim();
    
    _filteredJobs = _filterJobsWithMultipleTypes(
      allJobs: _allJobs,
      searchQuery: searchQuery,
      selectedJobTypeIds: _appliedJobTypeIds,
      selectedLocation: _appliedLocation,
      selectedExperience: _appliedExperience,
      selectedIndustry: _appliedIndustry,
      selectedCompanySize: _appliedCompanySize,
      showRemoteOnly: _appliedShowRemoteOnly,
      salaryMin: _appliedSalaryRange.start,
      salaryMax: _appliedSalaryRange.end,
    );

    setState(() {
      _isSearching = false;
    });
  }

  void _applyFilters() {
    setState(() {
      _isSearching = true;
    });

    final searchQuery = _searchController.text.toLowerCase().trim();
    
    _filteredJobs = _filterJobsWithMultipleTypes(
      allJobs: _allJobs,
      searchQuery: searchQuery,
      selectedJobTypeIds: _appliedJobTypeIds,
      selectedLocation: _appliedLocation,
      selectedExperience: _appliedExperience,
      selectedIndustry: _appliedIndustry,
      selectedCompanySize: _appliedCompanySize,
      showRemoteOnly: _appliedShowRemoteOnly,
      salaryMin: _appliedSalaryRange.start,
      salaryMax: _appliedSalaryRange.end,
    );

    setState(() {
      _isSearching = false;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      // Clear applied filters
      _appliedJobTypeIds = ['all'];
      _appliedLocation = 'all';
      _appliedExperience = 'all';
      _appliedIndustry = 'all';
      _appliedCompanySize = 'all';
      _appliedShowRemoteOnly = false;
      _appliedSalaryRange = const RangeValues(0, 500000);
    });
    // Apply the cleared filters
    _applyFilters();
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
          'Find Jobs',
          style: TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // Filter button with badge showing active filter count
          Stack(
            children: [
              IconButton(
                onPressed: _showFilterModal,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _hasActiveFilters() ? mediumSeaGreen : Colors.white,
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
                    Icons.tune,
                    color: _hasActiveFilters() ? Colors.white : darkTeal,
                    size: 20,
                  ),
                ),
              ),
              if (_hasActiveFilters())
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        _getActiveFilterCount().toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
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
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Search bar
        _buildSearchBar(),
        
        // Quick filter presets
        if (!_isLoading) _buildQuickFilters(),
        
        // Active filter chips
        if (_hasActiveFilters()) _buildActiveFilterChips(),
        
        // Results count
        _buildResultsCount(),
        
        // Jobs list
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: mediumSeaGreen,
                  ),
                )
              : _filteredJobs.isEmpty
                  ? _buildEmptyState()
                  : _buildJobsList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: lightMint,
        borderRadius: BorderRadius.circular(16),
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
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _performSearch(),
              decoration: InputDecoration(
                hintText: 'Search jobs, companies, locations...',
                hintStyle: TextStyle(
                  color: darkTeal.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                _performSearch();
              },
              icon: Icon(
                Icons.clear,
                color: darkTeal.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }



  Widget _buildResultsCount() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_filteredJobs.length} job${_filteredJobs.length == 1 ? '' : 's'} found',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_isSearching)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: mediumSeaGreen,
                strokeWidth: 2,
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
            Icon(
              Icons.search_off,
              size: 80,
              color: darkTeal.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Jobs Found',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search criteria or filters',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _clearFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Clear Filters',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredJobs.length,
      itemBuilder: (context, index) {
        final job = _filteredJobs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildJobCard(job),
        );
      },
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return JobCardWidget(
      job: job,
      onBookmarkTap: () => _toggleSaveJob(job['id']),
      isSaved: _savedJobs[job['id']] == true,
      isPending: _pendingSaveOperations.contains(job['id']),
    );
  }



  List<Map<String, dynamic>> _filterJobsWithMultipleTypes({
    required List<Map<String, dynamic>> allJobs,
    required String searchQuery,
    required List<String> selectedJobTypeIds,
    required String selectedLocation,
    required String selectedExperience,
    required String selectedIndustry,
    required String selectedCompanySize,
    required bool showRemoteOnly,
    required double salaryMin,
    required double salaryMax,
  }) {
    return allJobs.where((job) {
      // Search query filter
      if (searchQuery.isNotEmpty) {
        final title = (job['title'] ?? '').toString().toLowerCase();
        final company = (job['companies']?['name'] ?? '').toString().toLowerCase();
        final location = (job['location'] ?? '').toString().toLowerCase();
        final description = (job['description'] ?? '').toString().toLowerCase();
        
        if (!title.contains(searchQuery) && 
            !company.contains(searchQuery) && 
            !location.contains(searchQuery) &&
            !description.contains(searchQuery)) {
          return false;
        }
      }

      // Job type filter (multiple types support)
      if (selectedJobTypeIds.isNotEmpty && !selectedJobTypeIds.contains('all')) {
        final jobTypes = (job['job_types'] as List?)?.map((jt) => jt['id']).toList() ?? [];
        final hasMatchingJobType = selectedJobTypeIds.any((selectedId) => jobTypes.contains(selectedId));
        if (!hasMatchingJobType) {
          return false;
        }
      }

      // Location filter
      if (selectedLocation != 'all') {
        final location = (job['location'] ?? '').toString().toLowerCase();
        if (!location.contains(selectedLocation.toLowerCase())) {
          return false;
        }
      }

      // Experience level filter
      if (selectedExperience != 'all') {
        final experience = (job['experience_level'] ?? '').toString().toLowerCase();
        if (experience != selectedExperience.toLowerCase()) {
          return false;
        }
      }

      // Industry filter
      if (selectedIndustry != 'all') {
        final companyIndustry = (job['companies']?['industry'] ?? '').toString().toLowerCase();
        if (companyIndustry != selectedIndustry.toLowerCase()) {
          return false;
        }
      }

      // Company size filter
      if (selectedCompanySize != 'all') {
        final companySize = (job['companies']?['company_size'] ?? '').toString().toLowerCase();
        if (companySize != selectedCompanySize.toLowerCase()) {
          return false;
        }
      }

      // Remote work filter
      if (showRemoteOnly) {
        final jobTypes = (job['job_types'] as List?)?.map((jt) => jt['name']).toList() ?? [];
        if (!jobTypes.contains('remote')) {
          return false;
        }
      }

      // Salary range filter
      final minSalary = job['salary_min'] as int?;
      final maxSalary = job['salary_max'] as int?;
      
      if (salaryMin > 0 || salaryMax < 500000) {
        bool salaryMatches = false;
        
        if (minSalary != null && maxSalary != null) {
          // Job has both min and max salary
          salaryMatches = (minSalary >= salaryMin && maxSalary <= salaryMax) ||
                         (salaryMin >= minSalary && salaryMin <= maxSalary) ||
                         (salaryMax >= minSalary && salaryMax <= maxSalary);
        } else if (minSalary != null) {
          // Job has only min salary
          salaryMatches = minSalary >= salaryMin;
        } else if (maxSalary != null) {
          // Job has only max salary
          salaryMatches = maxSalary <= salaryMax;
        } else {
          // Job has no salary info, include it
          salaryMatches = true;
        }
        
        if (!salaryMatches) {
          return false;
        }
      }

      return true;
    }).toList();
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
      
      // Update UI with actual result
      if (mounted) {
            setState(() {
          _savedJobs[jobId] = isSaved;
        });
      }

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

  // ==================== FILTER UI COMPONENTS ====================

  Widget _buildQuickFilters() {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _filterPresets.entries.map((preset) {
          final isActive = _isPresetActive(preset.key);
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => _applyPreset(preset.key),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? mediumSeaGreen : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? mediumSeaGreen : paleGreen,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: darkTeal.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      preset.value['icon'] as IconData,
                      color: isActive ? Colors.white : mediumSeaGreen,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preset.value['name'] as String,
                      style: TextStyle(
                        color: isActive ? Colors.white : darkTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    final activeFilters = _getActiveFiltersList();
    
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...activeFilters.map((filter) => _buildFilterChip(
            label: filter['label'] as String,
            onRemove: filter['onRemove'] as VoidCallback,
          )),
          // Clear all button
          if (activeFilters.length > 1)
            InkWell(
              onTap: _clearFilters,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.clear_all,
                      size: 14,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Clear All',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: mediumSeaGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              Icons.close,
              size: 16,
              color: darkTeal.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FILTER LOGIC ====================

  bool _hasActiveFilters() {
    return _appliedLocation != 'all' ||
           _appliedExperience != 'all' ||
           _appliedIndustry != 'all' ||
           _appliedCompanySize != 'all' ||
           _appliedShowRemoteOnly ||
           (_appliedSalaryRange.start > 0 || _appliedSalaryRange.end < 500000) ||
           (_appliedJobTypeIds.isNotEmpty && !_appliedJobTypeIds.contains('all'));
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_appliedLocation != 'all') count++;
    if (_appliedExperience != 'all') count++;
    if (_appliedIndustry != 'all') count++;
    if (_appliedCompanySize != 'all') count++;
    if (_appliedShowRemoteOnly) count++;
    if (_appliedSalaryRange.start > 0 || _appliedSalaryRange.end < 500000) count++;
    if (_appliedJobTypeIds.isNotEmpty && !_appliedJobTypeIds.contains('all')) count++;
    return count;
  }

  List<Map<String, dynamic>> _getActiveFiltersList() {
    final List<Map<String, dynamic>> filters = [];

    if (_appliedLocation != 'all') {
      filters.add({
        'label': '📍 ${_appliedLocation.toUpperCase()}',
        'onRemove': () {
          setState(() {
            _appliedLocation = 'all';
          });
          _applyFilters();
        },
      });
    }

    if (_appliedExperience != 'all') {
      filters.add({
        'label': '💼 ${_appliedExperience.toUpperCase()}',
        'onRemove': () {
          setState(() {
            _appliedExperience = 'all';
          });
          _applyFilters();
        },
      });
    }

    if (_appliedIndustry != 'all') {
      filters.add({
        'label': '🏢 ${_appliedIndustry.toUpperCase()}',
        'onRemove': () {
          setState(() {
            _appliedIndustry = 'all';
          });
          _applyFilters();
        },
      });
    }

    if (_appliedCompanySize != 'all') {
      filters.add({
        'label': '👥 ${_appliedCompanySize.toUpperCase()}',
        'onRemove': () {
          setState(() {
            _appliedCompanySize = 'all';
          });
          _applyFilters();
        },
      });
    }

    if (_appliedShowRemoteOnly) {
      filters.add({
        'label': '🏠 REMOTE',
        'onRemove': () {
          setState(() {
            _appliedShowRemoteOnly = false;
          });
          _applyFilters();
        },
      });
    }

    if (_appliedSalaryRange.start > 0 || _appliedSalaryRange.end < 500000) {
      filters.add({
        'label': '💰 ₱${_appliedSalaryRange.start.toInt()}K - ₱${_appliedSalaryRange.end.toInt()}K',
        'onRemove': () {
          setState(() {
            _appliedSalaryRange = const RangeValues(0, 500000);
          });
          _applyFilters();
        },
      });
    }

    if (_appliedJobTypeIds.isNotEmpty && !_appliedJobTypeIds.contains('all')) {
      final jobTypeNames = _availableJobTypes
          .where((jt) => _appliedJobTypeIds.contains(jt['id']))
          .map((jt) => jt['display_name'] ?? jt['name'])
          .join(', ');
      filters.add({
        'label': '🏷️ $jobTypeNames',
        'onRemove': () {
          setState(() {
            _appliedJobTypeIds = ['all'];
          });
          _applyFilters();
        },
      });
    }

    return filters;
  }

  bool _isPresetActive(String presetKey) {
    final preset = _filterPresets[presetKey]!;
    final filters = preset['filters'] as Map<String, dynamic>;

    if (filters.containsKey('showRemoteOnly')) {
      return _appliedShowRemoteOnly == filters['showRemoteOnly'];
    }
    if (filters.containsKey('experience')) {
      return _appliedExperience == filters['experience'];
    }
    if (filters.containsKey('salaryMin')) {
      return _appliedSalaryRange.start >= (filters['salaryMin'] as double);
    }
    return false;
  }

  void _applyPreset(String presetKey) {
    final preset = _filterPresets[presetKey]!;
    final filters = preset['filters'] as Map<String, dynamic>;

    setState(() {
      if (filters.containsKey('showRemoteOnly')) {
        _appliedShowRemoteOnly = !_appliedShowRemoteOnly;
      }
      if (filters.containsKey('experience')) {
        _appliedExperience = _appliedExperience == filters['experience'] 
            ? 'all' 
            : filters['experience'] as String;
      }
      if (filters.containsKey('salaryMin')) {
        if (_appliedSalaryRange.start >= (filters['salaryMin'] as double)) {
          _appliedSalaryRange = const RangeValues(0, 500000);
        } else {
          _appliedSalaryRange = RangeValues(
            filters['salaryMin'] as double,
            500000,
          );
        }
      }
    });

    _applyFilters();
  }

  void _showFilterModal() {
    // Sync temp filters with applied filters
    _tempLocation = _appliedLocation;
    _tempExperience = _appliedExperience;
    _tempIndustry = _appliedIndustry;
    _tempCompanySize = _appliedCompanySize;
    _tempSalaryRange = _appliedSalaryRange;
    _tempShowRemoteOnly = _appliedShowRemoteOnly;
    _tempJobTypeIds = List.from(_appliedJobTypeIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _buildFilterModal(setModalState),
      ),
    );
  }

  Widget _buildFilterModal(StateSetter setModalState) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: lightMint,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Refine your job search',
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: darkTeal.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          
          // Filters content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Job Types (Multi-select)
                  _buildFilterSection(
                    title: 'Job Type',
                    icon: Icons.work_outline,
                    child: _buildJobTypeSelector(setModalState),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Location
                  _buildFilterSection(
                    title: 'Location',
                    icon: Icons.location_on_outlined,
                    child: _buildDropdownFilter(
                      value: _tempLocation,
                      items: ['all', 'manila', 'cebu', 'davao', 'remote'],
                      onChanged: (value) {
                        setModalState(() {
                          _tempLocation = value!;
                        });
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Experience Level
                  _buildFilterSection(
                    title: 'Experience Level',
                    icon: Icons.school_outlined,
                    child: _buildDropdownFilter(
                      value: _tempExperience,
                      items: ['all', 'entry', 'mid', 'senior', 'lead'],
                      onChanged: (value) {
                        setModalState(() {
                          _tempExperience = value!;
                        });
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Industry
                  _buildFilterSection(
                    title: 'Industry',
                    icon: Icons.business_outlined,
                    child: _buildDropdownFilter(
                      value: _tempIndustry,
                      items: ['all', 'technology', 'finance', 'healthcare', 'retail', 'education'],
                      onChanged: (value) {
                        setModalState(() {
                          _tempIndustry = value!;
                        });
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Company Size
                  _buildFilterSection(
                    title: 'Company Size',
                    icon: Icons.people_outline,
                    child: _buildDropdownFilter(
                      value: _tempCompanySize,
                      items: ['all', '1-10', '11-50', '51-200', '201-500', '500+'],
                      onChanged: (value) {
                        setModalState(() {
                          _tempCompanySize = value!;
                        });
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Salary Range
                  _buildFilterSection(
                    title: 'Salary Range (Monthly)',
                    icon: Icons.attach_money,
                    child: _buildSalaryRangeFilter(setModalState),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Remote Only Toggle
                  _buildFilterSection(
                    title: 'Work Arrangement',
                    icon: Icons.home_work_outlined,
                    child: _buildRemoteToggle(setModalState),
                  ),
                  
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          
          // Footer buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: darkTeal.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setModalState(() {
                        _tempLocation = 'all';
                        _tempExperience = 'all';
                        _tempIndustry = 'all';
                        _tempCompanySize = 'all';
                        _tempSalaryRange = const RangeValues(0, 500000);
                        _tempShowRemoteOnly = false;
                        _tempJobTypeIds = ['all'];
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: paleGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _appliedLocation = _tempLocation;
                        _appliedExperience = _tempExperience;
                        _appliedIndustry = _tempIndustry;
                        _appliedCompanySize = _tempCompanySize;
                        _appliedSalaryRange = _tempSalaryRange;
                        _appliedShowRemoteOnly = _tempShowRemoteOnly;
                        _appliedJobTypeIds = List.from(_tempJobTypeIds);
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mediumSeaGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: mediumSeaGreen,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildJobTypeSelector(StateSetter setModalState) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // All option
        _buildJobTypeChip(
          label: 'All Types',
          isSelected: _tempJobTypeIds.contains('all'),
          onTap: () {
            setModalState(() {
              _tempJobTypeIds = ['all'];
            });
          },
        ),
        // Individual job types
        ..._availableJobTypes.map((jobType) {
          final isSelected = _tempJobTypeIds.contains(jobType['id']);
          return _buildJobTypeChip(
            label: jobType['display_name'] ?? jobType['name'],
            isSelected: isSelected,
            onTap: () {
              setModalState(() {
                if (_tempJobTypeIds.contains('all')) {
                  _tempJobTypeIds = [jobType['id']];
                } else if (isSelected) {
                  _tempJobTypeIds.remove(jobType['id']);
                  if (_tempJobTypeIds.isEmpty) {
                    _tempJobTypeIds = ['all'];
                  }
                } else {
                  _tempJobTypeIds.add(jobType['id']);
                }
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildJobTypeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? mediumSeaGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? mediumSeaGreen : paleGreen,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : darkTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: lightMint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleGreen),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: darkTeal.withValues(alpha: 0.7)),
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item == 'all' ? 'All' : item.toUpperCase(),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSalaryRangeFilter(StateSetter setModalState) {
    return Column(
      children: [
        RangeSlider(
          values: _tempSalaryRange,
          min: 0,
          max: 500000,
          divisions: 50,
          activeColor: mediumSeaGreen,
          inactiveColor: paleGreen,
          labels: RangeLabels(
            '₱${_tempSalaryRange.start.toInt()}K',
            '₱${_tempSalaryRange.end.toInt()}K',
          ),
          onChanged: (RangeValues values) {
            setModalState(() {
              _tempSalaryRange = values;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₱${_tempSalaryRange.start.toInt()}K',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '₱${_tempSalaryRange.end.toInt()}K',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRemoteToggle(StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightMint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleGreen),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Show Remote Jobs Only',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Filter jobs that allow remote work',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _tempShowRemoteOnly,
            onChanged: (value) {
              setModalState(() {
                _tempShowRemoteOnly = value;
              });
            },
            activeColor: mediumSeaGreen,
          ),
        ],
      ),
    );
  }
}
