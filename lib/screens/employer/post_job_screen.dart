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

  String _selectedJobType = 'full_time';
  bool _isLoading = false;
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

  final List<String> _jobTypes = [
    'full_time',
    'part_time',
    'contract',
    'temporary',
    'internship',
    'remote',
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

  Future<void> _postJob() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate salary range
    if (!_validateSalaryRange()) {
      return;
    }

    // Validate company data
    if (widget.company['id'] == null) {
      _showErrorDialog('Company information is missing. Please try again.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final job = await JobService.createJob(
        companyId: widget.company['id'],
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        type: _selectedJobType,
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
        title: const Text(
          'Post New Job',
          style: TextStyle(
            color: darkTeal,
            fontSize: 20,
            fontWeight: FontWeight.bold,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company info header
            _buildCompanyHeader(),
            
            const SizedBox(height: 32),
            
            // Job title
            _buildTextField(
              controller: _titleController,
              label: 'Job Title',
              hint: 'e.g., Senior Flutter Developer',
              icon: Icons.work_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Job title is required';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            // Job type dropdown
            _buildJobTypeDropdown(),
            
            const SizedBox(height: 20),
            
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
            
            const SizedBox(height: 20),
            
            // Salary range
            _buildSalarySection(),
            
            const SizedBox(height: 20),
            
            // Experience level
            _buildTextField(
              controller: _experienceLevelController,
              label: 'Experience Level (Optional)',
              hint: 'e.g., Entry Level, Mid Level, Senior',
              icon: Icons.school_outlined,
            ),
            
            const SizedBox(height: 20),
            
            // Job description
            _buildDescriptionField(),
            
            const SizedBox(height: 32),
            
            // Post job button
            _buildPostJobButton(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyHeader() {
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
          // Company logo placeholder
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: mediumSeaGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.company['name']?.substring(0, 1).toUpperCase() ?? 'C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Company info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Posting as',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.company['name'] ?? 'Company',
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

  Widget _buildJobTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Job Type',
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedJobType,
          onChanged: (value) {
            setState(() {
              _selectedJobType = value!;
            });
          },
          decoration: InputDecoration(
            prefixIcon: Container(
              height: 20,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.access_time,
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
            filled: true,
            fillColor: lightMint.withValues(alpha: 0.3),
          ),
          items: _jobTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(
                _formatJobTypeDisplay(type),
                style: const TextStyle(
                  color: darkTeal,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
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
                  LengthLimitingTextInputFormatter(6),
                  _ThousandsFormatter(),
                ],
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
                  fontSize: 12,
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
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: (_isLoading || !_isSalaryValid) ? null : _postJob,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.publish),
        label: Text(
          _isLoading ? 'Posting Job...' : 'Post Job',
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
