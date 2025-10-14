import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'profile_preview_screen.dart';
import '../../services/onesignal_notification_service.dart';

class ApplicationProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? applicationProfile;
  final VoidCallback? onProfileUpdated;

  const ApplicationProfileScreen({
    super.key,
    this.applicationProfile,
    this.onProfileUpdated,
  });

  @override
  State<ApplicationProfileScreen> createState() => _ApplicationProfileScreenState();
}

class _ApplicationProfileScreenState extends State<ApplicationProfileScreen> with TickerProviderStateMixin {
  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);
  static const Color accentBlue = Color(0xFF2196F3);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _professionalSummaryController = TextEditingController();
  final _currentPositionController = TextEditingController();
  final _currentCompanyController = TextEditingController();
  final _yearsExperienceController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _githubController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();

  // Form data
  List<String> _skills = [];
  List<Map<String, dynamic>> _education = [];
  List<Map<String, dynamic>> _workExperience = [];
  List<Map<String, dynamic>> _certifications = [];
  List<Map<String, dynamic>> _languages = [];
  
  String? _resumeUrl;
  String? _resumeFilename;
  int _profileCompleteness = 0;
  bool _isLoading = false;
  bool _isSaving = false;
  
  // Animation controllers for progressive disclosure
  late AnimationController _progressAnimationController;
  late AnimationController _sectionAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _sectionAnimation;
  
  // Progressive disclosure state
  int _currentStep = 0;
  final List<String> _steps = [
    'Basic Information',
    'Professional Summary',
    'Work Experience',
    'Education',
    'Skills',
    'Resume',
    'Job Preferences',
    'Social Links'
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _sectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeInOut),
    );
    
    _sectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sectionAnimationController, curve: Curves.easeOutCubic),
    );
    
    _loadExistingProfile();
    
    // Start animations
    _progressAnimationController.forward();
    _sectionAnimationController.forward();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _professionalSummaryController.dispose();
    _currentPositionController.dispose();
    _currentCompanyController.dispose();
    _yearsExperienceController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    _githubController.dispose();
    _availabilityController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    
    // Dispose animation controllers
    _progressAnimationController.dispose();
    _sectionAnimationController.dispose();
    
    super.dispose();
  }

  void _loadExistingProfile() async {
    // First, try to load from application profile if provided
    if (widget.applicationProfile != null) {
      final profile = widget.applicationProfile!;
      
      _fullNameController.text = profile['full_name'] ?? '';
      _emailController.text = profile['email'] ?? '';
      _phoneController.text = profile['phone_number'] ?? '';
      _locationController.text = profile['location'] ?? '';
      _professionalSummaryController.text = profile['professional_summary'] ?? '';
      _currentPositionController.text = profile['current_position'] ?? '';
      _currentCompanyController.text = profile['current_company'] ?? '';
      _yearsExperienceController.text = profile['years_of_experience']?.toString() ?? '';
      _linkedinController.text = profile['linkedin_url'] ?? '';
      _portfolioController.text = profile['portfolio_url'] ?? '';
      _githubController.text = profile['github_url'] ?? '';
      _availabilityController.text = profile['availability'] ?? '';
      _salaryMinController.text = profile['salary_expectation_min']?.toString() ?? '';
      _salaryMaxController.text = profile['salary_expectation_max']?.toString() ?? '';
      
      _skills = List<String>.from(profile['skills'] ?? []);
      _education = List<Map<String, dynamic>>.from(profile['education'] ?? []);
      _workExperience = List<Map<String, dynamic>>.from(profile['work_experience'] ?? []);
      _certifications = List<Map<String, dynamic>>.from(profile['certifications'] ?? []);
      _languages = List<Map<String, dynamic>>.from(profile['languages'] ?? []);
      
      _resumeUrl = profile['resume_url'];
      _resumeFilename = profile['resume_filename'];
      _profileCompleteness = profile['profile_completeness'] ?? 0;
      
      setState(() {});
    } else {
      // If no application profile, fetch from user profiles table
      await _loadUserProfileData();
    }
  }

  Future<void> _loadUserProfileData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Fetch user data from profiles table
      final response = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        // Pre-populate basic information from user profile
        _fullNameController.text = response['full_name'] ?? '';
        _emailController.text = response['email'] ?? '';
        _phoneController.text = response['phone'] ?? '';
        _locationController.text = response['location'] ?? '';
        
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading user profile data: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Calculate profile completeness
      _profileCompleteness = _calculateCompleteness();

      final profileData = {
        'user_id': user.id,
        'full_name': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'professional_summary': _professionalSummaryController.text.trim(),
        'current_position': _currentPositionController.text.trim(),
        'current_company': _currentCompanyController.text.trim(),
        'years_of_experience': int.tryParse(_yearsExperienceController.text) ?? 0,
        'skills': _skills,
        'education': _education,
        'work_experience': _workExperience,
        'certifications': _certifications,
        'languages': _languages,
        'linkedin_url': _linkedinController.text.trim(),
        'portfolio_url': _portfolioController.text.trim(),
        'github_url': _githubController.text.trim(),
        'availability': _availabilityController.text.trim(),
        'salary_expectation_min': int.tryParse(_salaryMinController.text),
        'salary_expectation_max': int.tryParse(_salaryMaxController.text),
        'resume_url': _resumeUrl,
        'resume_filename': _resumeFilename,
        'profile_completeness': _profileCompleteness,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.applicationProfile != null) {
        // Update existing profile
        await Supabase.instance.client
            .from('applicant_profile')
            .update(profileData)
            .eq('user_id', user.id);
      } else {
        // Create new profile
        profileData['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client
            .from('applicant_profile')
            .insert(profileData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile saved successfully!'),
            backgroundColor: mediumSeaGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Send profile update notification
        try {
          await OneSignalNotificationService.sendProfileUpdateNotification(
            applicantId: user.id,
            applicantName: _fullNameController.text.trim(),
            profileCompleteness: _profileCompleteness,
            updatedFields: _getUpdatedFields(),
          );

          debugPrint('✅ Profile update notification sent successfully');
        } catch (notificationError) {
          debugPrint('❌ Error sending profile update notification: $notificationError');
          // Don't fail the profile save if notifications fail
        }

        widget.onProfileUpdated?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<String> _getUpdatedFields() {
    final updatedFields = <String>[];
    
    if (_fullNameController.text.isNotEmpty) updatedFields.add('full_name');
    if (_emailController.text.isNotEmpty) updatedFields.add('email');
    if (_phoneController.text.isNotEmpty) updatedFields.add('phone_number');
    if (_locationController.text.isNotEmpty) updatedFields.add('location');
    if (_professionalSummaryController.text.isNotEmpty) updatedFields.add('professional_summary');
    if (_currentPositionController.text.isNotEmpty) updatedFields.add('current_position');
    if (_currentCompanyController.text.isNotEmpty) updatedFields.add('current_company');
    if (_yearsExperienceController.text.isNotEmpty) updatedFields.add('years_of_experience');
    if (_skills.isNotEmpty) updatedFields.add('skills');
    if (_education.isNotEmpty) updatedFields.add('education');
    if (_workExperience.isNotEmpty) updatedFields.add('work_experience');
    if (_certifications.isNotEmpty) updatedFields.add('certifications');
    if (_languages.isNotEmpty) updatedFields.add('languages');
    if (_linkedinController.text.isNotEmpty) updatedFields.add('linkedin_url');
    if (_portfolioController.text.isNotEmpty) updatedFields.add('portfolio_url');
    if (_githubController.text.isNotEmpty) updatedFields.add('github_url');
    if (_availabilityController.text.isNotEmpty) updatedFields.add('availability');
    if (_salaryMinController.text.isNotEmpty) updatedFields.add('salary_expectation_min');
    if (_salaryMaxController.text.isNotEmpty) updatedFields.add('salary_expectation_max');
    if (_resumeUrl != null) updatedFields.add('resume');
    
    return updatedFields;
  }

  int _calculateCompleteness() {
    int score = 0;
    int totalFields = 15; // Total number of important fields

    // Basic info (3 points)
    if (_fullNameController.text.isNotEmpty) score++;
    if (_emailController.text.isNotEmpty) score++;
    if (_phoneController.text.isNotEmpty) score++;

    // Professional info (2 points)
    if (_professionalSummaryController.text.isNotEmpty) score++;
    if (_locationController.text.isNotEmpty) score++;

    // Skills and experience (3 points)
    if (_skills.isNotEmpty) score++;
    if (_workExperience.isNotEmpty) score++;
    if (_education.isNotEmpty) score++;

    // Resume and availability (2 points)
    if (_resumeUrl != null && _resumeUrl!.isNotEmpty) score++;
    if (_availabilityController.text.isNotEmpty) score++;

    // Salary expectations (1 point)
    if (_salaryMinController.text.isNotEmpty || _salaryMaxController.text.isNotEmpty) score++;

    // Social presence (2 points)
    if (_linkedinController.text.isNotEmpty) score++;
    if (_portfolioController.text.isNotEmpty || _githubController.text.isNotEmpty) score++;

    // Additional sections (2 points)
    if (_certifications.isNotEmpty) score++;
    if (_languages.isNotEmpty) score++;

    return ((score / totalFields) * 100).round();
  }

  Future<void> _uploadResume() async {
    try {
      // Pick PDF file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        setState(() {
          _isLoading = true;
        });

        try {
          // Upload file to Supabase Storage
          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final fileBytes = file.bytes!;
          
          await Supabase.instance.client.storage
              .from('resumes')
              .uploadBinary(fileName, fileBytes);

          final resumeUrl = Supabase.instance.client.storage
              .from('resumes')
              .getPublicUrl(fileName);

          setState(() {
            _resumeUrl = resumeUrl;
            _resumeFilename = file.name;
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Resume uploaded successfully: ${file.name}'),
                backgroundColor: mediumSeaGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading resume: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: _buildEnhancedAppBar(),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Enhanced Progress Header
            _buildProgressHeader(),
            
            // Main Content with Progressive Disclosure
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _sectionAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(_sectionAnimation),
                    child: _buildProgressiveContent(),
                  ),
                ),
              ),
            ),
            
            // Enhanced Bottom Action Bar
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }


  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: mediumSeaGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool required, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          prefixIcon: Icon(
            icon, 
            color: required ? mediumSeaGreen : darkTeal.withValues(alpha: 0.6),
            size: 20,
          ),
          suffixIcon: required && controller.text.isNotEmpty
              ? Icon(
                  Icons.check_circle,
                  color: mediumSeaGreen,
                  size: 20,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: required ? mediumSeaGreen.withValues(alpha: 0.3) : paleGreen,
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: required ? mediumSeaGreen.withValues(alpha: 0.3) : paleGreen,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: required ? mediumSeaGreen : darkTeal.withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: required 
              ? mediumSeaGreen.withValues(alpha: 0.05)
              : lightMint.withValues(alpha: 0.3),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildWorkExperienceSection() {
    return _buildSectionCard(
      'Work Experience',
      Icons.work_outline,
      [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: lightMint.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: paleGreen),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Work Experience (${_workExperience.length})',
                    style: TextStyle(
                      color: darkTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addWorkExperience,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: mediumSeaGreen,
                    ),
                  ),
                ],
              ),
              if (_workExperience.isEmpty)
                Text(
                  'No work experience added yet',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                )
              else
                ..._workExperience.asMap().entries.map((entry) {
                  final index = entry.key;
                  final experience = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: paleGreen.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${experience['title'] ?? 'Position'} at ${experience['company'] ?? 'Company'}',
                                style: TextStyle(
                                  color: darkTeal,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeWorkExperience(index),
                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                            ),
                          ],
                        ),
                        if (experience['duration'] != null)
                          Text(
                            experience['duration'],
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        if (experience['description'] != null)
                          Text(
                            experience['description'],
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEducationSection() {
    return _buildSectionCard(
      'Education',
      Icons.school_outlined,
      [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: lightMint.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: paleGreen),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Education (${_education.length})',
                    style: TextStyle(
                      color: darkTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addEducation,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: mediumSeaGreen,
                    ),
                  ),
                ],
              ),
              if (_education.isEmpty)
                Text(
                  'No education added yet',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                )
              else
                ..._education.asMap().entries.map((entry) {
                  final index = entry.key;
                  final education = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: paleGreen.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${education['degree'] ?? 'Degree'} from ${education['institution'] ?? 'Institution'}',
                                style: TextStyle(
                                  color: darkTeal,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeEducation(index),
                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                            ),
                          ],
                        ),
                        if (education['year'] != null)
                          Text(
                            'Graduated: ${education['year']}',
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        if (education['field'] != null)
                          Text(
                            'Field: ${education['field']}',
                            style: TextStyle(
                              color: darkTeal.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkillsSection() {
    return _buildSectionCard(
      'Skills',
      Icons.star_outline,
      [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: lightMint.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: paleGreen),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Skills (${_skills.length})',
                    style: TextStyle(
                      color: darkTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addSkill,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: mediumSeaGreen,
                    ),
                  ),
                ],
              ),
              if (_skills.isEmpty)
                Text(
                  'No skills added yet',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skills.map((skill) => Chip(
                    label: Text(skill),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeSkill(skill),
                    backgroundColor: mediumSeaGreen.withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: mediumSeaGreen,
                      fontSize: 12,
                    ),
                  )).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJobPreferencesSection() {
    return _buildSectionCard(
      'Job Preferences',
      Icons.settings_outlined,
      [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: lightMint.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: paleGreen),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help employers understand your preferences',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField(_availabilityController, 'When can you start?', Icons.schedule, false),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_salaryMinController, 'Min Salary (₱)', Icons.attach_money, false, keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(_salaryMaxController, 'Max Salary (₱)', Icons.attach_money, false, keyboardType: TextInputType.number),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResumeSection() {
    return _buildSectionCard(
      'Resume (PDF Only)',
      Icons.picture_as_pdf_outlined,
      [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: lightMint.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: paleGreen),
          ),
          child: Column(
            children: [
              // PDF requirement info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only PDF files are accepted for resume uploads',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              if (_resumeFilename != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: mediumSeaGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _resumeFilename!,
                              style: TextStyle(
                                color: darkTeal,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'PDF Resume',
                              style: TextStyle(
                                color: darkTeal.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _resumeUrl = null;
                            _resumeFilename = null;
                          });
                        },
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Remove resume',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _uploadResume,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_resumeFilename != null ? 'Replace PDF Resume' : 'Upload PDF Resume'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mediumSeaGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
              
              if (_resumeFilename == null) ...[
                const SizedBox(height: 12),
                Text(
                  'Upload your resume in PDF format for AI screening',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _addSkill() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Skill'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter skill name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _skills.add(controller.text.trim());
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  void _addWorkExperience() {
    showDialog(
      context: context,
      builder: (context) {
        final titleController = TextEditingController();
        final companyController = TextEditingController();
        final durationController = TextEditingController();
        final descriptionController = TextEditingController();
        
        return AlertDialog(
          title: const Text('Add Work Experience'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Job Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: companyController,
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (e.g., "Jan 2020 - Dec 2022")',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty && companyController.text.trim().isNotEmpty) {
                  setState(() {
                    _workExperience.add({
                      'title': titleController.text.trim(),
                      'company': companyController.text.trim(),
                      'duration': durationController.text.trim(),
                      'description': descriptionController.text.trim(),
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeWorkExperience(int index) {
    setState(() {
      _workExperience.removeAt(index);
    });
  }

  void _addEducation() {
    showDialog(
      context: context,
      builder: (context) {
        final degreeController = TextEditingController();
        final institutionController = TextEditingController();
        final yearController = TextEditingController();
        final fieldController = TextEditingController();
        
        return AlertDialog(
          title: const Text('Add Education'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: degreeController,
                  decoration: const InputDecoration(
                    labelText: 'Degree (e.g., Bachelor of Science)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: institutionController,
                  decoration: const InputDecoration(
                    labelText: 'Institution',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearController,
                  decoration: const InputDecoration(
                    labelText: 'Graduation Year',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fieldController,
                  decoration: const InputDecoration(
                    labelText: 'Field of Study',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (degreeController.text.trim().isNotEmpty && institutionController.text.trim().isNotEmpty) {
                  setState(() {
                    _education.add({
                      'degree': degreeController.text.trim(),
                      'institution': institutionController.text.trim(),
                      'year': yearController.text.trim(),
                      'field': fieldController.text.trim(),
                    });
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeEducation(int index) {
    setState(() {
      _education.removeAt(index);
    });
  }

  String _getCompletenessMessage(int completeness) {
    if (completeness >= 90) return 'Excellent! Your profile is complete and professional.';
    if (completeness >= 80) return 'Great! Your profile looks professional.';
    if (completeness >= 70) return 'Good progress! Add more details to stand out.';
    if (completeness >= 50) return 'Getting there! Complete more sections for better visibility.';
    if (completeness >= 30) return 'Start building your profile to attract employers.';
    return 'Create your professional profile to get started.';
  }

  void _showProfilePreview() {
    // Create a profile map from current form data
    final profileData = {
      'full_name': _fullNameController.text,
      'email': _emailController.text,
      'phone_number': _phoneController.text,
      'location': _locationController.text,
      'professional_summary': _professionalSummaryController.text,
      'current_position': _currentPositionController.text,
      'current_company': _currentCompanyController.text,
      'years_of_experience': int.tryParse(_yearsExperienceController.text),
      'skills': _skills,
      'education': _education,
      'work_experience': _workExperience,
      'certifications': _certifications,
      'languages': _languages,
      'resume_url': _resumeUrl,
      'resume_filename': _resumeFilename,
      'linkedin_url': _linkedinController.text,
      'portfolio_url': _portfolioController.text,
      'github_url': _githubController.text,
      'availability': _availabilityController.text,
      'salary_expectation_min': int.tryParse(_salaryMinController.text),
      'salary_expectation_max': int.tryParse(_salaryMaxController.text),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePreviewScreen(profile: profileData),
      ),
    );
  }

  // Enhanced UI Components
  PreferredSizeWidget _buildEnhancedAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
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
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkTeal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.applicationProfile != null ? 'Update Profile' : 'Create Profile',
            style: const TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Step ${_currentStep + 1} of ${_steps.length}',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        // Save button removed - using bottom action bar instead
      ],
    );
  }

  Widget _buildProgressHeader() {
    final completeness = _calculateCompleteness();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Progress Circle - Smaller
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: (_progressAnimation.value * completeness) / 100,
                      strokeWidth: 6,
                      backgroundColor: paleGreen.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completeness >= 80 ? successGreen : 
                        completeness >= 50 ? warningOrange : errorRed,
                      ),
                    ),
                  ),
                  Text(
                    '$completeness%',
                    style: TextStyle(
                      color: completeness >= 80 ? successGreen : 
                             completeness >= 50 ? warningOrange : errorRed,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(width: 16),
          
          // Progress Message and Step Indicators - Side by side
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Message
                Text(
                  _getCompletenessMessage(completeness),
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Step Indicators
                Row(
                  children: _steps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final isActive = index <= _currentStep;
                    final isCompleted = index < _currentStep;
                    
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isCompleted ? successGreen : 
                               isActive ? mediumSeaGreen : paleGreen,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressiveContent() {
    return Column(
      children: [
        // Current Step Content
        _buildCurrentStepContent(),
        
        const SizedBox(height: 20),
        
        // Navigation Buttons
        _buildStepNavigation(),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInformationStep();
      case 1:
        return _buildProfessionalSummaryStep();
      case 2:
        return _buildWorkExperienceStep();
      case 3:
        return _buildEducationStep();
      case 4:
        return _buildSkillsStep();
      case 5:
        return _buildResumeStep();
      case 6:
        return _buildJobPreferencesStep();
      case 7:
        return _buildSocialLinksStep();
      default:
        return _buildBasicInformationStep();
    }
  }

  Widget _buildBasicInformationStep() {
    return _buildStepCard(
      'Basic Information',
      Icons.person_outline,
      'Let\'s start with your basic contact information',
      [
        // Info message about pre-populated data
        if (widget.applicationProfile == null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: successGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Basic information has been pre-filled from your profile',
                    style: TextStyle(
                      color: successGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (widget.applicationProfile == null) const SizedBox(height: 16),
        
        _buildEnhancedTextField(_fullNameController, 'Full Name', Icons.person, true),
        _buildEnhancedTextField(_emailController, 'Email Address', Icons.email, true, keyboardType: TextInputType.emailAddress),
        _buildEnhancedTextField(_phoneController, 'Phone Number', Icons.phone, false, keyboardType: TextInputType.phone),
        _buildEnhancedTextField(_locationController, 'Location', Icons.location_on, false),
      ],
    );
  }

  Widget _buildProfessionalSummaryStep() {
    return _buildStepCard(
      'Professional Summary',
      Icons.description_outlined,
      'Tell employers about yourself and your career goals',
      [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accentBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentBlue.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: accentBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pro Tip',
                    style: TextStyle(
                      color: accentBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Write 2-3 sentences highlighting your key strengths, experience, and what you\'re looking for in your next role.',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildEnhancedTextField(_professionalSummaryController, 'Professional Summary', Icons.person_outline, true, maxLines: 4),
      ],
    );
  }

  Widget _buildWorkExperienceStep() {
    return _buildStepCard(
      'Work Experience',
      Icons.work_outline,
      'Showcase your professional journey',
      [
        _buildWorkExperienceSection(),
      ],
    );
  }

  Widget _buildEducationStep() {
    return _buildStepCard(
      'Education',
      Icons.school_outlined,
      'Highlight your educational background',
      [
        _buildEducationSection(),
      ],
    );
  }

  Widget _buildSkillsStep() {
    return _buildStepCard(
      'Skills',
      Icons.star_outline,
      'List your technical and soft skills',
      [
        _buildSkillsSection(),
      ],
    );
  }

  Widget _buildResumeStep() {
    return _buildStepCard(
      'Resume',
      Icons.picture_as_pdf_outlined,
      'Upload your professional resume',
      [
        _buildResumeSection(),
      ],
    );
  }

  Widget _buildJobPreferencesStep() {
    return _buildStepCard(
      'Job Preferences',
      Icons.settings_outlined,
      'Help employers understand your preferences',
      [
        _buildJobPreferencesSection(),
      ],
    );
  }

  Widget _buildSocialLinksStep() {
    return _buildStepCard(
      'Social Links',
      Icons.link,
      'Connect your professional profiles',
      [
        _buildSectionCard(
          'Social Links',
          Icons.link,
          [
            _buildEnhancedTextField(_linkedinController, 'LinkedIn URL', Icons.link, false),
            _buildEnhancedTextField(_portfolioController, 'Portfolio URL', Icons.web, false),
            _buildEnhancedTextField(_githubController, 'GitHub URL', Icons.code, false),
          ],
        ),
      ],
    );
  }

  Widget _buildStepCard(String title, IconData icon, String description, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: mediumSeaGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: darkTeal,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Step Content
          ...children,
        ],
      ),
    );
  }

  Widget _buildEnhancedTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool required, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with required indicator
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: errorRed.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      color: errorRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          
          // Text Field
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: required ? 'Enter $label' : 'Optional',
              prefixIcon: Icon(
                icon, 
                color: required ? mediumSeaGreen : darkTeal.withValues(alpha: 0.6),
                size: 20,
              ),
              suffixIcon: required && controller.text.isNotEmpty
                  ? Icon(
                      Icons.check_circle,
                      color: successGreen,
                      size: 20,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: required ? mediumSeaGreen.withValues(alpha: 0.3) : paleGreen,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: required ? mediumSeaGreen.withValues(alpha: 0.3) : paleGreen,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: required ? mediumSeaGreen : accentBlue,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: errorRed, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: errorRed, width: 2),
              ),
              filled: true,
              fillColor: required 
                  ? mediumSeaGreen.withValues(alpha: 0.05)
                  : lightMint.withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStepNavigation() {
    return Row(
      children: [
        // Previous Button
        if (_currentStep > 0)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStep--;
                });
                _sectionAnimationController.reset();
                _sectionAnimationController.forward();
              },
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Previous'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: darkTeal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: paleGreen),
                ),
                elevation: 0,
              ),
            ),
          ),
        
        if (_currentStep > 0) const SizedBox(width: 12),
        
        // Next Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              if (_currentStep < _steps.length - 1) {
                setState(() {
                  _currentStep++;
                });
                _sectionAnimationController.reset();
                _sectionAnimationController.forward();
              }
            },
            icon: Icon(
              _currentStep < _steps.length - 1 ? Icons.arrow_forward : Icons.check,
              size: 16,
            ),
            label: Text(_currentStep < _steps.length - 1 ? 'Next' : 'Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentStep < _steps.length - 1 ? mediumSeaGreen : successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Preview Button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showProfilePreview,
              icon: const Icon(Icons.preview, size: 16),
              label: const Text('Preview'),
              style: OutlinedButton.styleFrom(
                foregroundColor: darkTeal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: paleGreen),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Save Button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _saveProfile,
              icon: _isSaving 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 16),
              label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

