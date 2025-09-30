import 'package:flutter/material.dart';
import '../../services/job_service.dart';
import '../../services/search_service.dart';
import '../../widgets/job_card_widget.dart';
import '../../utils/formatters.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _allJobs = [];
  List<Map<String, dynamic>> _filteredJobs = [];
  bool _isLoading = true;
  bool _isSearching = false;

  // Search and filter controllers
  final _searchController = TextEditingController();
  String _selectedJobType = 'all';
  String _selectedLocation = 'all';
  String _selectedExperience = 'all';
  RangeValues _salaryRange = const RangeValues(0, 500000);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  final List<String> _jobTypes = [
    'all',
    'full_time',
    'part_time',
    'contract',
    'temporary',
    'internship',
    'remote',
  ];

  final List<String> _experienceLevels = [
    'all',
    'entry_level',
    'mid_level',
    'senior',
    'executive',
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
    
    _loadJobs();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await JobService.getAllJobs();
      setState(() {
        _allJobs = jobs;
        _filteredJobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _performSearch() {
    setState(() {
      _isSearching = true;
    });

    final searchQuery = _searchController.text.toLowerCase().trim();
    
    _filteredJobs = SearchService.filterJobs(
      allJobs: _allJobs,
      searchQuery: searchQuery,
      selectedJobType: _selectedJobType,
      selectedLocation: _selectedLocation,
      selectedExperience: _selectedExperience,
      salaryMin: _salaryRange.start,
      salaryMax: _salaryRange.end,
    );

    setState(() {
      _isSearching = false;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedJobType = 'all';
      _selectedLocation = 'all';
      _selectedExperience = 'all';
      _salaryRange = const RangeValues(0, 500000);
      _filteredJobs = _allJobs;
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterSheet(),
    );
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
          IconButton(
            onPressed: _showFilterDialog,
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
                Icons.tune,
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
        
        // Filter chips
        _buildFilterChips(),
        
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

  Widget _buildFilterChips() {
    final hasActiveFilters = SearchService.hasActiveFilters(
      selectedJobType: _selectedJobType,
      selectedLocation: _selectedLocation,
      selectedExperience: _selectedExperience,
      salaryMin: _salaryRange.start,
      salaryMax: _salaryRange.end,
    );

    if (!hasActiveFilters) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_selectedJobType != 'all')
                    _buildFilterChip(
                      Formatters.formatJobTypeDisplay(_selectedJobType),
                      () {
                        setState(() {
                          _selectedJobType = 'all';
                        });
                        _performSearch();
                      },
                    ),
                  if (_selectedLocation != 'all')
                    _buildFilterChip(
                      _selectedLocation,
                      () {
                        setState(() {
                          _selectedLocation = 'all';
                        });
                        _performSearch();
                      },
                    ),
                  if (_selectedExperience != 'all')
                    _buildFilterChip(
                      Formatters.formatExperienceDisplay(_selectedExperience),
                      () {
                        setState(() {
                          _selectedExperience = 'all';
                        });
                        _performSearch();
                      },
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: _clearFilters,
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
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        backgroundColor: mediumSeaGreen.withValues(alpha: 0.1),
        deleteIconColor: mediumSeaGreen,
        labelStyle: const TextStyle(color: mediumSeaGreen),
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
      onBookmarkTap: () {
        // TODO: Toggle bookmark
      },
    );
  }

  Widget _buildFilterSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _clearFilters,
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
          ),
          
          // Filter content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Job Type
                  _buildFilterSection(
                    'Job Type',
                    _buildJobTypeFilter(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Experience Level
                  _buildFilterSection(
                    'Experience Level',
                    _buildExperienceFilter(),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Salary Range
                  _buildFilterSection(
                    'Salary Range',
                    _buildSalaryFilter(),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          // Apply button
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performSearch();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mediumSeaGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget content) {
    return Column(
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
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildJobTypeFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _jobTypes.map((type) {
        final isSelected = _selectedJobType == type;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedJobType = type;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? mediumSeaGreen : lightMint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? mediumSeaGreen : paleGreen,
                width: 1,
              ),
            ),
                          child: Text(
                type == 'all' ? 'All Types' : Formatters.formatJobTypeDisplay(type),
                style: TextStyle(
                  color: isSelected ? Colors.white : darkTeal,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExperienceFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _experienceLevels.map((level) {
        final isSelected = _selectedExperience == level;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedExperience = level;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? mediumSeaGreen : lightMint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? mediumSeaGreen : paleGreen,
                width: 1,
              ),
            ),
                          child: Text(
                level == 'all' ? 'All Levels' : Formatters.formatExperienceDisplay(level),
                style: TextStyle(
                  color: isSelected ? Colors.white : darkTeal,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSalaryFilter() {
    return Column(
      children: [
        RangeSlider(
          values: _salaryRange,
          min: 0,
          max: 500000,
          divisions: 50,
          activeColor: mediumSeaGreen,
          inactiveColor: paleGreen,
          labels: RangeLabels(
            '₱${Formatters.formatNumber(_salaryRange.start.round())}',
            '₱${Formatters.formatNumber(_salaryRange.end.round())}',
          ),
          onChanged: (values) {
            setState(() {
              _salaryRange = values;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '₱${Formatters.formatNumber(_salaryRange.start.round())}',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
            Text(
              '₱${Formatters.formatNumber(_salaryRange.end.round())}',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }


}
