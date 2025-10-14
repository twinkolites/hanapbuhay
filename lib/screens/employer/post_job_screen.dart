import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/job_service.dart';

class PostJobScreen extends StatefulWidget {
  final Map<String, dynamic> company;

  const PostJobScreen({
    super.key,
    required this.company,
  });

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();
  final _experienceLevelController = TextEditingController();

  final List<String> _selectedJobTypeIds = [];
  String? _primaryJobTypeId;
  List<Map<String, dynamic>> _availableJobTypes = [];
  bool _isLoading = false;
  bool _isLoadingJobTypes = true;
  bool _isSalaryValid = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Safe references to inherited widgets
  ScaffoldMessengerState? _scaffoldMessenger;
  NavigatorState? _navigator;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);


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

    // Load job types
    _loadJobTypes();

    // Add listeners for real-time salary validation
    _salaryMinController.addListener(_onSalaryChanged);
    _salaryMaxController.addListener(_onSalaryChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely capture references to inherited widgets
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    _navigator = Navigator.maybeOf(context);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    _experienceLevelController.dispose();
    
    // Clear references to inherited widgets
    _scaffoldMessenger = null;
    _navigator = null;
    
    super.dispose();
  }

  Future<void> _loadJobTypes() async {
    try {
      final jobTypes = await JobService.getJobTypes();
      if (mounted) {
        setState(() {
          _availableJobTypes = jobTypes;
          _isLoadingJobTypes = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading job types: $e');
      if (mounted) {
        setState(() {
          _isLoadingJobTypes = false;
        });
      }
    }
  }

  Future<void> _postJob() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate salary range
    if (!_validateSalaryRange()) {
      return;
    }

    // Validate job types selection
    if (_selectedJobTypeIds.isEmpty) {
      _showErrorDialog('Please select at least one job type.');
      return;
    }

    // Validate company data
    if (widget.company['id'] == null) {
      _showErrorDialog('Company information is missing. Please try again.');
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showJobPostingConfirmation();
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final job = await JobService.createJob(
        companyId: widget.company['id'],
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        jobTypeIds: _selectedJobTypeIds,
        primaryJobTypeId: _primaryJobTypeId,
        salaryMin: _salaryMinController.text.isNotEmpty
            ? int.tryParse(_salaryMinController.text.replaceAll(',', ''))
            : null,
        salaryMax: _salaryMaxController.text.isNotEmpty
            ? int.tryParse(_salaryMaxController.text.replaceAll(',', ''))
            : null,
        experienceLevel: _experienceLevelController.text.trim().isNotEmpty
            ? _experienceLevelController.text.trim()
            : null,
      );

      if (job != null) {
        if (mounted && _scaffoldMessenger != null && _navigator != null) {
          _scaffoldMessenger!.showSnackBar(
            SnackBar(
              content: const Text('Job posted successfully!'),
              backgroundColor: mediumSeaGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );

          // Return to employer home with success
          _navigator!.pop(true);
        }
      } else {
        if (mounted) {
          _showErrorDialog('Failed to post job. Please try again.');
        }
      }
    } catch (e) {
      debugPrint('PostJobScreen error: $e');
      if (mounted) {
        _showErrorDialog('An error occurred while posting the job: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validateSalaryRange() {
    final minSalaryText = _salaryMinController.text.trim();
    final maxSalaryText = _salaryMaxController.text.trim();

    // If both fields are empty, that's valid (salary is optional)
    if (minSalaryText.isEmpty && maxSalaryText.isEmpty) {
      return true;
    }

    // If only one field is filled, that's valid
    if (minSalaryText.isEmpty || maxSalaryText.isEmpty) {
      return true;
    }

    // Both fields are filled, validate the range
    final minSalary = int.tryParse(minSalaryText.replaceAll(',', ''));
    final maxSalary = int.tryParse(maxSalaryText.replaceAll(',', ''));

    if (minSalary == null || maxSalary == null) {
      _showErrorDialog('Please enter valid salary amounts.');
      return false;
    }

    if (maxSalary <= minSalary) {
      _showErrorDialog('Maximum salary must be higher than minimum salary.');
      return false;
    }

    return true;
  }

  void _onSalaryChanged() {
    final minSalaryText = _salaryMinController.text.trim();
    final maxSalaryText = _salaryMaxController.text.trim();

    // If both fields are empty, that's valid (salary is optional)
    if (minSalaryText.isEmpty && maxSalaryText.isEmpty) {
      setState(() {
        _isSalaryValid = true;
      });
      return;
    }

    // If only one field is filled, that's valid
    if (minSalaryText.isEmpty || maxSalaryText.isEmpty) {
      setState(() {
        _isSalaryValid = true;
      });
      return;
    }

    // Both fields are filled, validate the range
    final minSalary = int.tryParse(minSalaryText.replaceAll(',', ''));
    final maxSalary = int.tryParse(maxSalaryText.replaceAll(',', ''));

    if (minSalary == null || maxSalary == null) {
      setState(() {
        _isSalaryValid = false;
      });
      return;
    }

    setState(() {
      _isSalaryValid = maxSalary > minSalary;
    });
  }

  Future<bool> _showJobPostingConfirmation() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  Icons.publish_rounded,
                  color: mediumSeaGreen,
                  size: 32,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Confirm Job Posting',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Job preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: lightMint.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: paleGreen.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleController.text.trim(),
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: mediumSeaGreen,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _locationController.text.trim(),
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.work_outline,
                          color: mediumSeaGreen,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getSelectedJobTypesDisplay(),
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (_salaryMinController.text.isNotEmpty || _salaryMaxController.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            color: mediumSeaGreen,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getSalaryDisplay(),
                            style: TextStyle(
                              color: mediumSeaGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Message
              Text(
                'Are you ready to post this job? It will be visible to job seekers immediately.',
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mediumSeaGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Post Job',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
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
    ) ?? false;
  }

  String _getSelectedJobTypesDisplay() {
    if (_selectedJobTypeIds.isEmpty) return 'No job types selected';
    
    final primaryJobType = _availableJobTypes.firstWhere(
      (jt) => jt['id'] == _primaryJobTypeId,
      orElse: () => {'display_name': 'Unknown'},
    );
    
    if (_selectedJobTypeIds.length == 1) {
      return primaryJobType['display_name'];
    } else {
      return '${primaryJobType['display_name']} +${_selectedJobTypeIds.length - 1}';
    }
  }

  String _getSalaryDisplay() {
    final minSalary = _salaryMinController.text.trim();
    final maxSalary = _salaryMaxController.text.trim();
    
    if (minSalary.isNotEmpty && maxSalary.isNotEmpty) {
      return '₱$minSalary - ₱$maxSalary';
    } else if (minSalary.isNotEmpty) {
      return '₱$minSalary+';
    } else if (maxSalary.isNotEmpty) {
      return 'Up to ₱$maxSalary';
    }
    return 'Salary negotiable';
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
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
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red.shade400,
                  size: 32,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Error',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Message
              Text(
                message,
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.7),
                  fontSize: 11,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // OK button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        title: Text(
          'Post New Job',
          style: TextStyle(
            color: darkTeal,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
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
            child: _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            
            const SizedBox(height: 24),
            
            // Company info header
            _buildCompanyHeader(),
            
            const SizedBox(height: 28),
            
            // Form sections with cards
            _buildFormSection(
              title: 'Job Details',
              icon: Icons.work_outline,
              children: [
                // Job title
                _buildTextField(
                  controller: _titleController,
                  label: 'Job Title',
                  hint: 'e.g., Senior Flutter Developer',
                  icon: Icons.title,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Job title is required';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Job type multi-select
                _buildJobTypeMultiSelect(),
                
                const SizedBox(height: 16),
                
                // Location
                _buildTextField(
                  controller: _locationController,
                  label: 'Location',
                  hint: 'e.g., Manila, Philippines or Remote',
                  icon: Icons.location_on_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Location is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Compensation section
            _buildFormSection(
              title: 'Compensation & Requirements',
              icon: Icons.payments_outlined,
              children: [
                // Salary range
                _buildSalarySection(),
                
                const SizedBox(height: 16),
                
                // Experience level
                _buildTextField(
                  controller: _experienceLevelController,
                  label: 'Experience Level (Optional)',
                  hint: 'e.g., Entry Level, Mid Level, Senior',
                  icon: Icons.school_outlined,
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Job description section
            _buildFormSection(
              title: 'Job Description',
              icon: Icons.description_outlined,
              children: [
                _buildDescriptionField(),
              ],
            ),
            
            const SizedBox(height: 28),
            
            // Post job button
            _buildPostJobButton(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: mediumSeaGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job Posting Progress',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete all sections to post your job',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lightMint.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
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
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Section content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            mediumSeaGreen.withValues(alpha: 0.08),
            paleGreen.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mediumSeaGreen.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Company logo placeholder
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: mediumSeaGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                widget.company['name']?.substring(0, 1).toUpperCase() ?? 'C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Company info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Posting as',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.company['name'] ?? 'Company',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: darkTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines ?? 1,
          validator: validator,
          style: TextStyle(
            fontSize: 11,
            color: darkTeal,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Container(
              height: 18,
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: mediumSeaGreen,
                size: 14,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: mediumSeaGreen,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.red.shade400,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.red.shade400,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildJobTypeMultiSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Job Type *',
          style: TextStyle(
            color: darkTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        
        if (_isLoadingJobTypes)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected job types display
                if (_selectedJobTypeIds.isNotEmpty) ...[
                  Text(
                    'Selected Job Types:',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedJobTypeIds.map((jobTypeId) {
                      final jobType = _availableJobTypes.firstWhere(
                        (jt) => jt['id'] == jobTypeId,
                        orElse: () => {'display_name': 'Unknown'},
                      );
                      final isPrimary = _primaryJobTypeId == jobTypeId;
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isPrimary ? mediumSeaGreen : mediumSeaGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isPrimary ? mediumSeaGreen : mediumSeaGreen.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              jobType['display_name'],
                              style: TextStyle(
                                color: isPrimary ? Colors.white : mediumSeaGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isPrimary) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.star,
                                size: 12,
                                color: Colors.white,
                              ),
                            ],
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _removeJobType(jobTypeId),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: isPrimary ? Colors.white : darkTeal,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Job type selection grid
                Text(
                  'Select Job Types:',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableJobTypes.map((jobType) {
                    final isSelected = _selectedJobTypeIds.contains(jobType['id']);
                    
                    return GestureDetector(
                      onTap: () => _toggleJobType(jobType['id']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? mediumSeaGreen.withValues(alpha: 0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? mediumSeaGreen : paleGreen,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? mediumSeaGreen : paleGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              jobType['display_name'],
                              style: TextStyle(
                                color: isSelected ? mediumSeaGreen : darkTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                // Primary job type selection
                if (_selectedJobTypeIds.length > 1) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Primary Job Type:',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedJobTypeIds.map((jobTypeId) {
                      final jobType = _availableJobTypes.firstWhere(
                        (jt) => jt['id'] == jobTypeId,
                        orElse: () => {'display_name': 'Unknown'},
                      );
                      final isPrimary = _primaryJobTypeId == jobTypeId;
                      
                      return GestureDetector(
                        onTap: () => _setPrimaryJobType(jobTypeId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPrimary ? mediumSeaGreen : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPrimary ? mediumSeaGreen : paleGreen,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPrimary ? Icons.star : Icons.star_border,
                                color: isPrimary ? Colors.white : mediumSeaGreen,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                jobType['display_name'],
                                style: TextStyle(
                                  color: isPrimary ? Colors.white : darkTeal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  void _toggleJobType(String jobTypeId) {
    setState(() {
      if (_selectedJobTypeIds.contains(jobTypeId)) {
        _selectedJobTypeIds.remove(jobTypeId);
        if (_primaryJobTypeId == jobTypeId) {
          _primaryJobTypeId = _selectedJobTypeIds.isNotEmpty ? _selectedJobTypeIds.first : null;
        }
      } else {
        _selectedJobTypeIds.add(jobTypeId);
        if (_selectedJobTypeIds.length == 1) {
          _primaryJobTypeId = jobTypeId;
        }
      }
    });
  }

  void _removeJobType(String jobTypeId) {
    setState(() {
      _selectedJobTypeIds.remove(jobTypeId);
      if (_primaryJobTypeId == jobTypeId) {
        _primaryJobTypeId = _selectedJobTypeIds.isNotEmpty ? _selectedJobTypeIds.first : null;
      }
    });
  }

  void _setPrimaryJobType(String jobTypeId) {
    setState(() {
      _primaryJobTypeId = jobTypeId;
    });
  }

  Widget _buildSalarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Salary Range (Optional)',
          style: TextStyle(
            color: darkTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _salaryMinController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                  _ThousandsFormatter(),
                ],
                style: TextStyle(
                  fontSize: 11,
                  color: darkTeal,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Min salary',
                  hintStyle: TextStyle(
                    color: darkTeal.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixText: '₱ ',
                  prefixStyle: TextStyle(
                    color: mediumSeaGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isSalaryValid ? paleGreen.withValues(alpha: 0.5) : Colors.red,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isSalaryValid ? paleGreen.withValues(alpha: 0.5) : Colors.red,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isSalaryValid ? mediumSeaGreen : Colors.red,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: lightMint.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _salaryMaxController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                  _ThousandsFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: 'Max salary',
                  hintStyle: TextStyle(
                    color: darkTeal.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  prefixText: '₱ ',
                  prefixStyle: const TextStyle(
                    color: mediumSeaGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isSalaryValid ? paleGreen.withValues(alpha: 0.5) : Colors.red,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isSalaryValid ? paleGreen.withValues(alpha: 0.5) : Colors.red,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _isSalaryValid ? mediumSeaGreen : Colors.red,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: lightMint.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
        if (!_isSalaryValid) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Maximum salary must be greater than minimum salary',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Job Description',
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          maxLines: 6,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Job description is required';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Describe the role, responsibilities, requirements, and qualifications...',
            hintStyle: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: paleGreen.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: mediumSeaGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            filled: true,
            fillColor: lightMint.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildPostJobButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: mediumSeaGreen.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: (_isLoading || !_isSalaryValid) ? null : _postJob,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.publish, size: 18),
        label: Text(
          _isLoading ? 'Posting Job...' : 'Post Job',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: mediumSeaGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final int value = int.tryParse(newValue.text.replaceAll(',', '')) ?? 0;
    final String formatted = value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
