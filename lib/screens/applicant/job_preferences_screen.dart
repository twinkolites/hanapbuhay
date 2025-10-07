import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_recommendation_service.dart';
import '../../services/job_service.dart';

class JobPreferencesScreen extends StatefulWidget {
  const JobPreferencesScreen({super.key});

  @override
  State<JobPreferencesScreen> createState() => _JobPreferencesScreenState();
}

class _JobPreferencesScreenState extends State<JobPreferencesScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _isSaving = false;

  // User preferences
  List<String> _selectedInterests = [];
  List<String> _selectedIndustries = [];
  List<String> _selectedSkills = [];

  // Available options
  final List<String> _jobInterests = [
    'Software Development',
    'Data Science',
    'UI/UX Design',
    'Product Management',
    'Marketing',
    'Sales',
    'Human Resources',
    'Finance',
    'Operations',
    'Customer Support',
    'DevOps',
    'Cybersecurity',
    'Machine Learning',
    'Mobile Development',
    'Web Development',
    'Cloud Computing',
    'Blockchain',
    'Game Development',
    'Digital Marketing',
    'Content Creation',
  ];

  final List<String> _industries = [
    'Technology',
    'Healthcare',
    'Finance',
    'Education',
    'E-commerce',
    'Manufacturing',
    'Real Estate',
    'Media & Entertainment',
    'Travel & Tourism',
    'Food & Beverage',
    'Automotive',
    'Retail',
    'Consulting',
    'Non-profit',
    'Government',
    'Energy',
    'Telecommunications',
    'Transportation',
    'Sports & Fitness',
    'Fashion',
  ];

  final List<String> _skillsToDevelop = [
    'Flutter/Dart',
    'React/JavaScript',
    'Python',
    'Machine Learning',
    'Cloud Computing (AWS/Azure)',
    'DevOps',
    'UI/UX Design',
    'Project Management',
    'Data Analysis',
    'Mobile Development',
    'Web Development',
    'Database Management',
    'Cybersecurity',
    'Blockchain',
    'Artificial Intelligence',
    'Leadership',
    'Communication',
    'Problem Solving',
    'Team Management',
    'Agile/Scrum',
  ];

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await JobService.getApplicantProfile(user.id);
      if (profile != null) {
        setState(() {
          _selectedInterests = List<String>.from(profile['job_interests'] ?? []);
          _selectedIndustries = List<String>.from(profile['preferred_industries'] ?? []);
          _selectedSkills = List<String>.from(profile['preferred_skills'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final success = await JobRecommendationService.updateJobPreferences(
        userId: user.id,
        jobInterests: _selectedInterests,
        preferredIndustries: _selectedIndustries,
        preferredSkills: _selectedSkills,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully!'),
            backgroundColor: mediumSeaGreen,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate refresh needed
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save preferences'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Job Preferences',
          style: TextStyle(
            color: darkTeal,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: darkTeal),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentPage == 2)
            TextButton(
              onPressed: _isSaving ? null : _savePreferences,
              child: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: TextStyle(
                  color: mediumSeaGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: mediumSeaGreen))
          : Column(
              children: [
                _buildProgressIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    children: [
                      _buildInterestsPage(),
                      _buildIndustriesPage(),
                      _buildSkillsPage(),
                    ],
                  ),
                ),
                _buildNavigationButtons(),
              ],
            ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: List.generate(3, (index) {
              final isActive = index <= _currentPage;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: isActive ? mediumSeaGreen : paleGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            _getPageTitle(_currentPage),
            style: TextStyle(
              color: darkTeal,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getPageTitle(int page) {
    switch (page) {
      case 0:
        return 'What interests you?';
      case 1:
        return 'Preferred Industries';
      case 2:
        return 'Skills to Develop';
      default:
        return '';
    }
  }

  Widget _buildInterestsPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select your job interests',
            style: TextStyle(
              color: darkTeal,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose areas that excite you professionally',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _jobInterests.length,
              itemBuilder: (context, index) {
                final interest = _jobInterests[index];
                final isSelected = _selectedInterests.contains(interest);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedInterests.remove(interest);
                      } else {
                        _selectedInterests.add(interest);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? mediumSeaGreen : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? mediumSeaGreen : paleGreen,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? Colors.white : mediumSeaGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            interest,
                            style: TextStyle(
                              color: isSelected ? Colors.white : darkTeal,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _buildIndustriesPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferred Industries',
            style: TextStyle(
              color: darkTeal,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select industries you\'d like to work in',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _industries.length,
              itemBuilder: (context, index) {
                final industry = _industries[index];
                final isSelected = _selectedIndustries.contains(industry);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIndustries.remove(industry);
                      } else {
                        _selectedIndustries.add(industry);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? mediumSeaGreen : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? mediumSeaGreen : paleGreen,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? Colors.white : mediumSeaGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            industry,
                            style: TextStyle(
                              color: isSelected ? Colors.white : darkTeal,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _buildSkillsPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skills to Develop',
            style: TextStyle(
              color: darkTeal,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select skills you want to learn or improve',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _skillsToDevelop.length,
              itemBuilder: (context, index) {
                final skill = _skillsToDevelop[index];
                final isSelected = _selectedSkills.contains(skill);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedSkills.remove(skill);
                      } else {
                        _selectedSkills.add(skill);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? mediumSeaGreen : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? mediumSeaGreen : paleGreen,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? Colors.white : mediumSeaGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            skill,
                            style: TextStyle(
                              color: isSelected ? Colors.white : darkTeal,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: darkTeal,
                  side: BorderSide(color: mediumSeaGreen.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Previous',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentPage < 2
                  ? () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : _isSaving ? null : _savePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentPage < 2 ? 'Next' : (_isSaving ? 'Saving...' : 'Save Preferences'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
