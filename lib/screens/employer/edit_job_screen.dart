import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/job_service.dart';
import '../../services/input_security_service.dart';

class EditJobScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const EditJobScreen({
    super.key,
    required this.job,
  });

  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();
  final _experienceLevelController = TextEditingController();

  // Multi job types selection (align with PostJobScreen)
  final List<String> _selectedJobTypeIds = [];
  String? _primaryJobTypeId;
  List<Map<String, dynamic>> _availableJobTypes = [];
  bool _isLoadingJobTypes = true;
  bool _isLoading = false;
  bool _hasChanges = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  // Removed old single-select job types list

  @override
  void initState() {
    super.initState();
    _initializeFormData();
    _setupChangeListeners();

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

    _loadJobTypes();
  }

  void _initializeFormData() {
    _titleController.text = widget.job['title'] ?? '';
    _descriptionController.text = widget.job['description'] ?? '';
    _locationController.text = widget.job['location'] ?? '';
    
    if (widget.job['salary_min'] != null) {
      _salaryMinController.text = widget.job['salary_min'].toString();
    }
    if (widget.job['salary_max'] != null) {
      _salaryMaxController.text = widget.job['salary_max'].toString();
    }
    
    _experienceLevelController.text = widget.job['experience_level'] ?? '';
  }

  Future<void> _loadJobTypes() async {
    try {
      final jobTypes = await JobService.getJobTypes();
      final selected = await JobService.getJobTypesForJob(widget.job['id']);

      if (mounted) {
        setState(() {
          _availableJobTypes = jobTypes;
          _selectedJobTypeIds
            ..clear()
            ..addAll(selected.map((e) => e['job_type_id'] as String));
          _primaryJobTypeId = selected.firstWhere(
            (e) => e['is_primary'] == true,
            orElse: () => {'job_type_id': (_selectedJobTypeIds.isNotEmpty ? _selectedJobTypeIds.first : null)},
          )['job_type_id'] as String?;
          _isLoadingJobTypes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingJobTypes = false;
        });
      }
    }
  }

  void _setupChangeListeners() {
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
    _salaryMinController.addListener(_onFieldChanged);
    _salaryMaxController.addListener(_onFieldChanged);
    _experienceLevelController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
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
    super.dispose();
  }

  Future<void> _updateJob() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate job types selection
    if (_selectedJobTypeIds.isEmpty) {
      _showErrorDialog('Please select at least one job type.');
      return;
    }

    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No changes detected. Job is already up to date.'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Sanitize all input data before sending to service
      final sanitizedTitle = InputSecurityService.sanitizeText(_titleController.text.trim());
      final sanitizedDescription = InputSecurityService.sanitizeText(_descriptionController.text.trim());
      final sanitizedLocation = InputSecurityService.sanitizeText(_locationController.text.trim());
      final sanitizedExperienceLevel = _experienceLevelController.text.trim().isNotEmpty
          ? InputSecurityService.sanitizeText(_experienceLevelController.text.trim())
          : null;
      
      final success = await JobService.updateJob(
        jobId: widget.job['id'],
        title: sanitizedTitle,
        description: sanitizedDescription,
        location: sanitizedLocation,
        // Do not send legacy single type; types managed in relation table
        salaryMin: _salaryMinController.text.isNotEmpty
            ? int.tryParse(_salaryMinController.text.replaceAll(',', ''))
            : null,
        salaryMax: _salaryMaxController.text.isNotEmpty
            ? int.tryParse(_salaryMaxController.text.replaceAll(',', ''))
            : null,
        experienceLevel: sanitizedExperienceLevel,
      );

      // Persist job types mapping
      final typesOk = success
          ? await JobService.setJobTypesForJob(
              jobId: widget.job['id'],
              jobTypeIds: _selectedJobTypeIds,
              primaryJobTypeId: _primaryJobTypeId,
            )
          : false;

      if (success && typesOk && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Job updated successfully!'),
            backgroundColor: mediumSeaGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        setState(() {
          _hasChanges = false;
        });

        Navigator.pop(context, true);
      } else {
        _showErrorDialog('Failed to update job. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('An error occurred while updating the job.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          style: const TextStyle(color: darkTeal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: mediumSeaGreen),
            ),
          ),
        ],
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
        title: Row(
          children: [
            const Text(
              'Edit Job',
              style: TextStyle(
                color: darkTeal,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_hasChanges) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildJobHeader(),
            
            const SizedBox(height: 32),
            
            _buildTextField(
              controller: _titleController,
              label: 'Job Title',
              hint: 'e.g., Senior Flutter Developer',
              icon: Icons.work_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Job title is required';
                }
                
                // Security validation
                final sanitized = InputSecurityService.sanitizeText(value);
                if (sanitized != value) {
                  return 'Job title contains invalid characters';
                }
                
                // Check for suspicious patterns
                final suspiciousCheck = InputSecurityService.detectSuspiciousPatterns(value, 'Job title');
                if (suspiciousCheck != null) {
                  return suspiciousCheck;
                }
                
                // Length validation
                if (value.trim().length < 3) {
                  return 'Job title must be at least 3 characters';
                }
                if (value.trim().length > 100) {
                  return 'Job title must be less than 100 characters';
                }
                
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            _buildJobTypeMultiSelect(),
            
            const SizedBox(height: 20),
            
            _buildTextField(
              controller: _locationController,
              label: 'Location',
              hint: 'e.g., Manila, Philippines or Remote',
              icon: Icons.location_on_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Location is required';
                }
                
                // Security validation
                final sanitized = InputSecurityService.sanitizeText(value);
                if (sanitized != value) {
                  return 'Location contains invalid characters';
                }
                
                // Check for suspicious patterns
                final suspiciousCheck = InputSecurityService.detectSuspiciousPatterns(value, 'Location');
                if (suspiciousCheck != null) {
                  return suspiciousCheck;
                }
                
                // Length validation
                if (value.trim().length < 2) {
                  return 'Location must be at least 2 characters';
                }
                if (value.trim().length > 100) {
                  return 'Location must be less than 100 characters';
                }
                
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            _buildSalarySection(),
            
            const SizedBox(height: 20),
            
            _buildTextField(
              controller: _experienceLevelController,
              label: 'Experience Level (Optional)',
              hint: 'e.g., Entry Level, Mid Level, Senior',
              icon: Icons.school_outlined,
              validator: (value) {
                // Optional field - only validate if not empty
                if (value == null || value.trim().isEmpty) {
                  return null;
                }
                
                // Security validation
                final sanitized = InputSecurityService.sanitizeText(value);
                if (sanitized != value) {
                  return 'Experience level contains invalid characters';
                }
                
                // Check for suspicious patterns
                final suspiciousCheck = InputSecurityService.detectSuspiciousPatterns(value, 'Experience level');
                if (suspiciousCheck != null) {
                  return suspiciousCheck;
                }
                
                // Length validation
                if (value.trim().length < 2) {
                  return 'Experience level must be at least 2 characters';
                }
                if (value.trim().length > 50) {
                  return 'Experience level must be less than 50 characters';
                }
                
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            _buildDescriptionField(),
            
            const SizedBox(height: 32),
            
            _buildUpdateJobButton(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildJobHeader() {
    final company = widget.job['companies'];
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: mediumSeaGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                company?['name']?.substring(0, 1).toUpperCase() ?? 'C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
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
                  'Editing job for',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  company?['name'] ?? 'Company',
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
          style: const TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines ?? 1,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            prefixIcon: Container(
              height: 20,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: mediumSeaGreen,
                size: 16,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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

  Widget _buildJobTypeMultiSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Job Type *',
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
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
                if (_selectedJobTypeIds.isNotEmpty) ...[
                  Text(
                    'Selected Job Types:',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.7),
                      fontSize: 12,
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
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isPrimary) ...[
                              const SizedBox(width: 4),
                              const Icon(
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
                      onTap: () => _toggleJobType(jobType['id'] as String),
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
      _hasChanges = true;
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
      _hasChanges = true;
      _selectedJobTypeIds.remove(jobTypeId);
      if (_primaryJobTypeId == jobTypeId) {
        _primaryJobTypeId = _selectedJobTypeIds.isNotEmpty ? _selectedJobTypeIds.first : null;
      }
    });
  }

  void _setPrimaryJobType(String jobTypeId) {
    setState(() {
      _hasChanges = true;
      _primaryJobTypeId = jobTypeId;
    });
  }

  Widget _buildSalarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Salary Range (Optional)',
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _salaryMinController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7), // Limit to 7 digits (1,000,000)
                  _ThousandsFormatter(),
                ],
                validator: (value) {
                  // Optional field - only validate if not empty
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  
                  // Remove commas for validation
                  final cleanValue = value.replaceAll(',', '');
                  
                  // Security validation using numeric validation
                  final numericValidation = InputSecurityService.validateSecureNumeric(
                    cleanValue,
                    'Minimum salary',
                    maxValue: 1000000, // 1 million pesos max
                    minValue: 1,
                  );
                  if (numericValidation != null) {
                    return numericValidation;
                  }
                  
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Min salary',
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
                  LengthLimitingTextInputFormatter(7), // Limit to 7 digits (1,000,000)
                  _ThousandsFormatter(),
                ],
                validator: (value) {
                  // Optional field - only validate if not empty
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }
                  
                  // Remove commas for validation
                  final cleanValue = value.replaceAll(',', '');
                  
                  // Security validation using numeric validation
                  final numericValidation = InputSecurityService.validateSecureNumeric(
                    cleanValue,
                    'Maximum salary',
                    maxValue: 1000000, // 1 million pesos max
                    minValue: 1,
                  );
                  if (numericValidation != null) {
                    return numericValidation;
                  }
                  
                  // Additional validation: max salary should be >= min salary if both provided
                  final minSalaryText = _salaryMinController.text.replaceAll(',', '');
                  if (minSalaryText.isNotEmpty) {
                    final minSalary = int.tryParse(minSalaryText);
                    final maxSalary = int.tryParse(cleanValue);
                    if (minSalary != null && maxSalary != null && maxSalary < minSalary) {
                      return 'Maximum salary must be greater than or equal to minimum salary';
                    }
                  }
                  
                  return null;
                },
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
                  filled: true,
                  fillColor: lightMint.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
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
            
            // Security validation
            final sanitized = InputSecurityService.sanitizeText(value);
            if (sanitized != value) {
              return 'Job description contains invalid characters';
            }
            
            // Check for suspicious patterns
            final suspiciousCheck = InputSecurityService.detectSuspiciousPatterns(value, 'Job description');
            if (suspiciousCheck != null) {
              return suspiciousCheck;
            }
            
            // Length validation
            if (value.trim().length < 10) {
              return 'Job description must be at least 10 characters';
            }
            if (value.trim().length > 2000) {
              return 'Job description must be less than 2000 characters';
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

  Widget _buildUpdateJobButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _updateJob,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: Text(
          _isLoading ? 'Updating Job...' : (_hasChanges ? 'Update Job' : 'No Changes'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: mediumSeaGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: mediumSeaGreen.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  // Removed legacy _formatJobTypeDisplay helper
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
