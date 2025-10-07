import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../services/job_service.dart';
import '../../services/ai_screening_service.dart';

class ApplyJobScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const ApplyJobScreen({
    super.key,
    required this.job,
  });

  @override
  State<ApplyJobScreen> createState() => _ApplyJobScreenState();
}

class _ApplyJobScreenState extends State<ApplyJobScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _coverLetterController = TextEditingController();
  final _resumeUrlController = TextEditingController();
  final _applicationNotesController = TextEditingController();
  
  bool _isLoading = false;
  bool _hasApplied = false;
  bool _isGeneratingCoverLetter = false;
  bool _isUploadingResume = false;
  Map<String, dynamic>? _applicantProfile;
  String? _resumeUrl;
  String? _resumeFilename;
  int _profileCompleteness = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);
  static const Color accentBlue = Color(0xFF2196F3);

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
    
    _checkApplicationStatus();
    _loadApplicantProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _coverLetterController.dispose();
    _resumeUrlController.dispose();
    _applicationNotesController.dispose();
    super.dispose();
  }

  Future<void> _checkApplicationStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final hasApplied = await JobService.hasUserApplied(widget.job['id'], user.id);
      setState(() {
        _hasApplied = hasApplied;
      });
    }
  }

  Future<void> _loadApplicantProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await JobService.getApplicantProfile(user.id);
      setState(() {
        _applicantProfile = profile;
        _profileCompleteness = profile?['profile_completeness'] ?? 0;
        
        // Pre-populate resume URL if available
        if (profile?['resume_url'] != null) {
          _resumeUrlController.text = profile!['resume_url'];
          _resumeUrl = profile['resume_url'];
          _resumeFilename = profile['resume_filename'];
        }
      });
    }
  }

  Future<void> _generatePersonalizedCoverLetter() async {
    if (_applicantProfile == null) return;

    setState(() {
      _isGeneratingCoverLetter = true;
    });

    try {
      final coverLetter = await JobService.generatePersonalizedCoverLetter(
        job: widget.job,
        applicantProfile: _applicantProfile!,
      );

      if (coverLetter != null) {
        _coverLetterController.text = coverLetter;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Personalized cover letter generated!'),
              backgroundColor: mediumSeaGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating cover letter: $e'),
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
        _isGeneratingCoverLetter = false;
      });
    }
  }

  Future<void> _uploadResume() async {
    setState(() {
      _isUploadingResume = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final user = Supabase.instance.client.auth.currentUser;
        
        if (user != null && file.bytes != null) {
          final uploadUrl = await JobService.uploadResume(
            userId: user.id,
            fileName: file.name,
            fileBytes: Uint8List.fromList(file.bytes!),
          );

          if (uploadUrl != null) {
            setState(() {
              _resumeUrl = uploadUrl;
              _resumeFilename = file.name;
            });
            
            _resumeUrlController.text = uploadUrl;

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Resume uploaded successfully: ${file.name}'),
                  backgroundColor: mediumSeaGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading resume: $e'),
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
        _isUploadingResume = false;
      });
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showErrorDialog('You must be logged in to apply for jobs.');
        return;
      }

      // Submit application with enhanced data
      final application = await JobService.applyForJob(
        jobId: widget.job['id'],
        applicantId: user.id,
        resumeUrl: _resumeUrl ?? (_resumeUrlController.text.trim().isNotEmpty 
            ? _resumeUrlController.text.trim() 
            : null),
        resumeFilename: _resumeFilename,
        coverLetter: _coverLetterController.text.trim().isNotEmpty 
            ? _coverLetterController.text.trim() 
            : null,
        applicationNotes: _applicationNotesController.text.trim().isNotEmpty 
            ? _applicationNotesController.text.trim() 
            : null,
        applicationSource: 'mobile_app',
      );

      if (application != null && mounted) {
        setState(() {
          _hasApplied = true;
        });
        
        // Trigger AI screening immediately
        await AIScreeningService.triggerAIScreening(
          applicationId: application['id'],
        );
        
        // Show success dialog with enhanced UX
        _showSuccessDialog();

        // Return to previous screen after user acknowledges
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else {
        _showErrorDialog('Failed to submit application. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('An error occurred while submitting your application.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with success icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      mediumSeaGreen.withValues(alpha: 0.1),
                      paleGreen.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [mediumSeaGreen, mediumSeaGreen.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: mediumSeaGreen.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Application Submitted!',
                      style: TextStyle(
                        color: darkTeal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your application for "${widget.job['title']}" has been submitted successfully.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // AI Screening info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: mediumSeaGreen.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: mediumSeaGreen.withValues(alpha: 0.2),
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
                              Icons.psychology,
                              color: mediumSeaGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'AI screening is now analyzing your application. You\'ll receive updates on your application status.',
                              style: TextStyle(
                                color: darkTeal,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Tracking info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: lightMint.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: paleGreen.withValues(alpha: 0.3),
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
                              Icons.info_outline,
                              color: mediumSeaGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can track your application status in the Applications section.',
                              style: TextStyle(
                                color: darkTeal,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: darkTeal,
                          side: BorderSide(color: darkTeal.withValues(alpha: 0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue Browsing',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mediumSeaGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View Applications',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          'Apply for Job',
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
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_hasApplied) {
      return _buildAlreadyApplied();
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job info header
            _buildJobHeader(),
            
            const SizedBox(height: 24),
            
            // Profile completeness indicator
            if (_applicantProfile != null) _buildProfileCompleteness(),
            
            const SizedBox(height: 24),
            
            // Cover letter section
            _buildCoverLetterSection(),
            
            const SizedBox(height: 20),
            
            // Resume section
            _buildResumeSection(),
            
            const SizedBox(height: 20),
            
            // Application notes
            _buildApplicationNotes(),
            
            const SizedBox(height: 32),
            
            // Submit button
            _buildSubmitButton(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyApplied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: mediumSeaGreen,
            ),
            const SizedBox(height: 24),
            Text(
              'Already Applied!',
              style: TextStyle(
                color: darkTeal,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You have already applied for this position.\nWe will review your application and get back to you soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: mediumSeaGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Back to Jobs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobHeader() {
    final company = widget.job['companies'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
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
          // Header section with gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mediumSeaGreen.withValues(alpha: 0.1),
                  paleGreen.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Company logo with enhanced design
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [mediumSeaGreen, mediumSeaGreen.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: mediumSeaGreen.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      (company?['name'] ?? 'Company').substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Job info with better typography
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.job['title'] ?? 'Untitled Job',
                        style: const TextStyle(
                          color: darkTeal,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        company?['name'] ?? 'Company',
                        style: TextStyle(
                          color: darkTeal.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Job details section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                // Location and type row
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.location_on_outlined,
                        text: widget.job['location'] ?? 'Location not specified',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        icon: Icons.work_outline,
                        text: _formatJobTypeDisplay(widget.job['type'] ?? 'full_time'),
                      ),
                    ),
                  ],
                ),
                
                // Salary row
                if (widget.job['salary_min'] != null || widget.job['salary_max'] != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSalaryChip(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: lightMint.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: mediumSeaGreen,
            size: 14,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            mediumSeaGreen.withValues(alpha: 0.1),
            mediumSeaGreen.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: mediumSeaGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.payments_outlined,
            color: mediumSeaGreen,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            _formatSalaryRange(widget.job['salary_min'], widget.job['salary_max']),
            style: const TextStyle(
              color: mediumSeaGreen,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCompleteness() {
    final isComplete = _profileCompleteness >= 80;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete 
              ? mediumSeaGreen.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
          width: 1,
        ),
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
          // Status icon with enhanced design
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isComplete 
                  ? mediumSeaGreen.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isComplete ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: isComplete ? mediumSeaGreen : Colors.orange,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Completeness',
                  style: TextStyle(
                    color: darkTeal,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Progress bar with percentage
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _profileCompleteness / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isComplete 
                                    ? [mediumSeaGreen, mediumSeaGreen.withValues(alpha: 0.8)]
                                    : [Colors.orange, Colors.orange.withValues(alpha: 0.8)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_profileCompleteness%',
                      style: TextStyle(
                        color: isComplete ? mediumSeaGreen : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                
                if (!isComplete) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Complete your profile for better job matching',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverLetterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(20),
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
          // Header with AI generate button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cover Letter',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_applicantProfile != null)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentBlue, accentBlue.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isGeneratingCoverLetter ? null : _generatePersonalizedCoverLetter,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isGeneratingCoverLetter
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              _isGeneratingCoverLetter ? 'Generating...' : 'AI Generate',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Tell us why you\'re the perfect fit for this role',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Enhanced text field
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: TextFormField(
              controller: _coverLetterController,
              maxLines: 8,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Cover letter is required';
                }
                if (value.trim().length < 50) {
                  return 'Cover letter must be at least 50 characters';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: 'Write your cover letter here...\n\nExplain your relevant experience, skills, and why you\'re interested in this position.',
                hintStyle: TextStyle(
                  color: darkTeal.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
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
                fillColor: lightMint.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(20),
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
          // Header with upload button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Resume',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [mediumSeaGreen, mediumSeaGreen.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isUploadingResume ? null : _uploadResume,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isUploadingResume
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.upload_file, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            _isUploadingResume ? 'Uploading...' : 'Upload PDF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Upload your resume or provide a link',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Enhanced text field
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: TextFormField(
              controller: _resumeUrlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://example.com/resume.pdf',
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
                  child: const Icon(
                    Icons.link,
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
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: mediumSeaGreen,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: lightMint.withValues(alpha: 0.2),
              ),
            ),
          ),
          
          // Uploaded file indicator
          if (_resumeFilename != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: mediumSeaGreen.withValues(alpha: 0.2),
                  width: 1,
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
                      Icons.description,
                      color: mediumSeaGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uploaded Successfully',
                          style: TextStyle(
                            color: darkTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _resumeFilename!,
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _resumeFilename = null;
                        _resumeUrl = null;
                        _resumeUrlController.clear();
                      });
                    },
                    icon: const Icon(Icons.close, size: 20),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApplicationNotes() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(20),
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.note_add_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Additional Notes',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Optional',
                  style: TextStyle(
                    color: Colors.grey.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Any additional information you\'d like to share',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Enhanced text field
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: TextFormField(
              controller: _applicationNotesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Additional notes, availability, or special considerations...',
                hintStyle: TextStyle(
                  color: darkTeal.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: mediumSeaGreen,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: lightMint.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [mediumSeaGreen, mediumSeaGreen.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: mediumSeaGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _submitApplication,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  _isLoading ? 'Submitting Application...' : 'Submit Application',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSalaryRange(int? min, int? max) {
    if (min != null && max != null) {
      return '₱${_formatNumber(min)} - ₱${_formatNumber(max)}';
    } else if (min != null) {
      return '₱${_formatNumber(min)}+';
    } else if (max != null) {
      return 'Up to ₱${_formatNumber(max)}';
    }
    return 'Salary negotiable';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toString();
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