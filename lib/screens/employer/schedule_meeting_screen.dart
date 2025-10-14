import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/calendar_models.dart';
import '../../services/calendar_service.dart';
import '../../services/meeting_validation_service.dart';

/// Schedule Meeting Screen
/// 
/// Timezone: Philippines Standard Time (PST/PHST - UTC+8)
/// - All date/time pickers use device's local timezone (Philippines)
/// - Time picker displays in 12-hour format (AM/PM)
/// - Past dates and times are blocked
/// - Database stores times in UTC, displayed in local time

class ScheduleMeetingScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final String? applicantId;
  final String? applicantName;
  final String? jobTitle;
  final String? jobId;
  final String? chatId;
  
  const ScheduleMeetingScreen({
    super.key, 
    this.selectedDate,
    this.applicantId,
    this.applicantName,
    this.jobTitle,
    this.jobId,
    this.chatId,
  });

  @override
  State<ScheduleMeetingScreen> createState() => _ScheduleMeetingScreenState();
}

class _ScheduleMeetingScreenState extends State<ScheduleMeetingScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  CalendarEventType _selectedType = CalendarEventType.meeting;
  String? _selectedApplicantId;
  String? _selectedJobId;
  
  bool _isLoading = false;
  bool _isSaving = false;
  
  List<Map<String, dynamic>> _applicants = [];
  List<Map<String, dynamic>> _allApplicants = []; // Store all applicants for filtering
  List<Map<String, dynamic>> _jobs = [];
  Map<String, List<String>> _jobApplicants = {}; // Map job_id to list of applicant_ids

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
    
    // Debug: Print received data
    debugPrint('🔍 [ScheduleMeeting] Received data:');
    debugPrint('  - applicantId: ${widget.applicantId}');
    debugPrint('  - applicantName: ${widget.applicantName}');
    debugPrint('  - jobTitle: ${widget.jobTitle}');
    debugPrint('  - jobId: ${widget.jobId}');
    debugPrint('  - chatId: ${widget.chatId}');
    
    // Pre-populate data if coming from chat
    if (widget.applicantId != null) {
      _selectedApplicantId = widget.applicantId;
      debugPrint('✅ [ScheduleMeeting] Pre-selected applicant: ${widget.applicantId}');
    }
    if (widget.jobId != null) {
      _selectedJobId = widget.jobId;
      debugPrint('✅ [ScheduleMeeting] Pre-selected job ID: ${widget.jobId}');
    }
    if (widget.jobTitle != null) {
      _titleController.text = 'Meeting about ${widget.jobTitle}';
      debugPrint('✅ [ScheduleMeeting] Pre-filled title: ${_titleController.text}');
    }
    
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Load jobs first - get the company for this employer
        try {
          debugPrint('🔍 [ScheduleMeeting] Looking for company owned by user: $userId');
          final companyData = await _supabase
              .from('companies')
              .select('id, name, created_at')
              .eq('owner_id', userId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          
          if (companyData == null) {
            debugPrint('⚠️ [ScheduleMeeting] No company found for user: $userId');
            setState(() {
              _jobs = [];
              _selectedJobId = null;
              _applicants = [];
            });
            return;
          }

          debugPrint('✅ [ScheduleMeeting] Found company: ${companyData['id']} - ${companyData['name']}');
          
          // Fetch jobs via secure RPC scoped by owner (bypasses RLS edge cases)
          final jobsData = await _supabase
              .rpc('get_owner_jobs', params: { 'owner': userId });
          debugPrint('✅ [ScheduleMeeting] RPC jobs loaded: ${jobsData.length}');
          setState(() {
            _jobs = List<Map<String, dynamic>>.from(
              (jobsData as List).map((j) => {
                'id': j['id'],
                'title': j['title'],
                'company_id': j['company_id'],
              }),
            );
            if (_selectedJobId != null && !_jobs.any((j) => j['id'] == _selectedJobId)) {
              _selectedJobId = null;
            }
          });
          
          // Load all job applications to map jobs to applicants
          debugPrint('🔍 [ScheduleMeeting] Loading job applications for filtering...');
          // Fetch applications via secure RPC scoped by owner
          final appsData = await _supabase
              .rpc('get_owner_applications', params: { 'owner': userId });

          // Optionally filter to the currently loaded jobs
          final jobIdsSet = _jobs.map((j) => j['id'] as String).toSet();
          final applications = (appsData as List).where((row) => jobIdsSet.contains(row['job_id'] as String)).toList();

          debugPrint('✅ [ScheduleMeeting] RPC applications loaded: ${applications.length}');
          
          // Build job -> applicants mapping
          final jobApplicantsMap = <String, List<String>>{};
          final allApplicantsMap = <String, Map<String, dynamic>>{};
          
          for (final app in applications) {
            final jobId = app['job_id'] as String;
            final applicantId = app['applicant_id'] as String;
            // From RPC we have applicant_full_name/email columns
            final applicantData = <String, dynamic>{
              'id': applicantId,
              'full_name': app['applicant_full_name'],
              'email': app['applicant_email'],
            };
            
            // Store applicant data
            allApplicantsMap[applicantId] = applicantData;
            
            // Map job to applicant
            jobApplicantsMap[jobId] = (jobApplicantsMap[jobId] ?? [])..add(applicantId);
          }
          
          debugPrint('✅ [ScheduleMeeting] Built job-applicants mapping: ${jobApplicantsMap.map((k, v) => MapEntry(k, v.length))}');
          
          setState(() {
            _jobApplicants = jobApplicantsMap;
            _allApplicants = allApplicantsMap.values.toList();
            debugPrint('✅ [ScheduleMeeting] Total unique applicants: ${_allApplicants.length}');
          });
          
          // Pre-select job if provided
          if (widget.jobId != null) {
            debugPrint('🔍 [ScheduleMeeting] Looking for job by ID: ${widget.jobId}');
            
            final matchingJob = _jobs.firstWhere(
              (job) => job['id'] == widget.jobId,
              orElse: () => {},
            );
            
            if (matchingJob.isNotEmpty) {
              setState(() {
                _selectedJobId = matchingJob['id'] as String;
              });
              debugPrint('✅ [ScheduleMeeting] Pre-selected job: ${matchingJob['title']}');
              
              // Filter applicants for this job
              _filterApplicantsByJob(_selectedJobId);
            }
          } else if (widget.jobTitle != null) {
            // Try to match by title
            var matchingJob = _jobs.firstWhere(
              (job) => job['title'] == widget.jobTitle,
              orElse: () => {},
            );
            
            if (matchingJob.isEmpty) {
              matchingJob = _jobs.firstWhere(
                (job) => (job['title'] as String).toLowerCase() == widget.jobTitle!.toLowerCase(),
                orElse: () => {},
              );
            }
            
            if (matchingJob.isNotEmpty) {
              setState(() {
                _selectedJobId = matchingJob['id'] as String;
              });
              debugPrint('✅ [ScheduleMeeting] Pre-selected job by title: ${matchingJob['title']}');
              
              // Filter applicants for this job
              _filterApplicantsByJob(_selectedJobId);
            }
          } else {
            // No job pre-selected, show all applicants
            setState(() {
              _applicants = _allApplicants;
            });
          }
          
        } catch (e) {
          debugPrint('❌ [ScheduleMeeting] Error loading company/jobs: $e');
          setState(() {
            _jobs = [];
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  /// Filter applicants based on selected job
  void _filterApplicantsByJob(String? jobId) {
    if (jobId == null) {
      // No job selected, show all applicants
      setState(() {
        _applicants = _allApplicants;
      });
      debugPrint('🔍 [ScheduleMeeting] No job selected, showing all ${_allApplicants.length} applicants');
      return;
    }
    
    // Get applicant IDs for this job
    final applicantIds = _jobApplicants[jobId] ?? [];
    debugPrint('🔍 [ScheduleMeeting] Job "$jobId" has ${applicantIds.length} applicants');
    
    // Filter applicants
    final filteredApplicants = _allApplicants
        .where((app) => applicantIds.contains(app['id']))
        .toList();
    
    setState(() {
      _applicants = filteredApplicants;
      
      // If currently selected applicant is not in filtered list, clear selection
      if (_selectedApplicantId != null && !applicantIds.contains(_selectedApplicantId)) {
        debugPrint('⚠️ [ScheduleMeeting] Selected applicant not in filtered list, clearing selection');
        _selectedApplicantId = null;
      }
    });
    
    debugPrint('✅ [ScheduleMeeting] Filtered to ${filteredApplicants.length} applicants for this job');
  }

  Future<void> _saveMeeting() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedStartTime == null || _selectedEndTime == null) {
      _showErrorSnackBar('Please select date and time');
      return;
    }
    // Require at least one participant (applicant or chat-linked applicant)
    if (_selectedApplicantId == null || _selectedApplicantId!.isEmpty) {
      _showErrorSnackBar('Please select an applicant (participant)');
      return;
    }

    try {
      setState(() => _isSaving = true);
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Create DateTime objects in local time
      final startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedStartTime!.hour,
        _selectedStartTime!.minute,
      );
      
      final endDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedEndTime!.hour,
        _selectedEndTime!.minute,
      );

      // Validate meeting date and time
      final dateTimeValidation = MeetingValidationService.validateMeetingDateTime(
        startTime: startDateTime,
        endTime: endDateTime,
      );
      
      if (!dateTimeValidation.isValid) {
        _showErrorSnackBar(dateTimeValidation.errorMessage!);
        return;
      }
      
      // Check for overlapping meetings
      final overlapValidation = await MeetingValidationService.checkForOverlaps(
        userId: userId,
        startTime: startDateTime,
        endTime: endDateTime,
      );
      
      if (!overlapValidation.isValid) {
        _showErrorSnackBar(overlapValidation.errorMessage!);
        return;
      }

      final meetingLink = CalendarService.generateMeetingLink();
      
      final event = CalendarEvent(
        id: '',
        title: _titleController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        description: _descriptionController.text.trim(),
        color: _getEventColor(_selectedType),
        type: _selectedType,
        employerId: userId,
        applicantId: _selectedApplicantId,
        jobId: _selectedJobId,
        location: _locationController.text.trim(),
        meetingLink: meetingLink,
        status: CalendarEventStatus.scheduled,
        createdAt: DateTime.now(),
      );

      final createdEvent = await CalendarService.createEvent(event);
      if (createdEvent != null) {
        // Notify employer realtime listeners by inserting triggers already handled by DB; UI reloads via subscription
        // Send notification to applicant if selected
        if (_selectedApplicantId != null) {
          await CalendarService.sendCalendarNotification(
            userId: _selectedApplicantId!,
            title: 'New Meeting Scheduled',
            message: '${_titleController.text.trim()} has been scheduled for ${_formatDateTime(startDateTime)}',
            type: 'meeting_scheduled',
          );
        }
        
        _showSuccessSnackBar('Meeting scheduled successfully!');
        Navigator.pop(context, createdEvent);
      } else {
        // Show error if event creation failed
        _showErrorSnackBar('Failed to create meeting. Please check your inputs and try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to schedule meeting: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: mediumSeaGreen,
      ),
    );
  }

  Color _getEventColor(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.meeting:
        return Colors.blue;
      case CalendarEventType.interview:
        return Colors.orange;
      case CalendarEventType.availability:
        return Colors.green;
      case CalendarEventType.reminder:
        return Colors.purple;
      case CalendarEventType.blocked:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingState()
          : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: darkTeal.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: lightMint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: darkTeal,
            size: 20,
          ),
        ),
      ),
      title: const Text(
        'Schedule Meeting',
        style: TextStyle(
          color: darkTeal,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: mediumSeaGreen.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(mediumSeaGreen),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading data...',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBasicInfoSection(),
            const SizedBox(height: 16),
            _buildDateTimeSection(),
            const SizedBox(height: 16),
            _buildParticipantsSection(),
            const SizedBox(height: 16),
            _buildTypeSection(),
            const SizedBox(height: 20),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.05),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  color: mediumSeaGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Basic Information',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _titleController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Meeting Title',
              labelStyle: const TextStyle(fontSize: 11),
              hintText: 'Enter meeting title',
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a meeting title';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: const TextStyle(fontSize: 11),
              hintText: 'Enter meeting description',
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _locationController,
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
              labelText: 'Location (Optional)',
              labelStyle: const TextStyle(fontSize: 11),
              hintText: 'Enter meeting location or video call link',
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.05),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: mediumSeaGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Date & Time',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDateTimeField(
            'Date',
            _selectedDate != null ? _formatDate(_selectedDate!) : 'Select Date',
            Icons.calendar_month_rounded,
            () => _selectDate(),
          ),
          // Current time indicator
          _buildCurrentTimeIndicator(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateTimeField(
                  'Start Time',
                  _selectedStartTime != null ? _formatTimeOfDay(_selectedStartTime!) : 'Select Time',
                  Icons.access_time_rounded,
                  () => _selectStartTime(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateTimeField(
                  'End Time',
                  _selectedEndTime != null ? _formatTimeOfDay(_selectedEndTime!) : 'Select Time',
                  Icons.access_time_rounded,
                  () => _selectEndTime(),
                ),
              ),
            ],
          ),
          // Duration indicator
          if (_selectedStartTime != null && _selectedEndTime != null) ...[
            const SizedBox(height: 12),
            _buildDurationIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.05),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people_rounded,
                  color: mediumSeaGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Participants',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.applicantName != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: mediumSeaGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_rounded,
                    color: mediumSeaGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Applicant',
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.applicantName!,
                          style: const TextStyle(
                            color: darkTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle_rounded,
                    color: mediumSeaGreen,
                    size: 14,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_applicants.isEmpty && _selectedJobId != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No applicants have applied to this job yet.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            _buildDropdownField(
              'Applicant (Optional)',
              _selectedApplicantId,
              _applicants.map((app) => DropdownMenuItem<String>(
                value: app['id'] as String,
                child: Text(
                  app['full_name'] ?? app['email'],
                  style: const TextStyle(fontSize: 11),
                ),
              )).toList(),
              (value) => setState(() => _selectedApplicantId = value),
              'Select an applicant',
            ),
          const SizedBox(height: 12),
          if (widget.jobTitle != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: mediumSeaGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.work_outline_rounded,
                    color: mediumSeaGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedJobId != null ? 'Related Job (Found)' : 'Related Job (Not Found)',
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.jobTitle!,
                          style: const TextStyle(
                            color: darkTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_selectedJobId == null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Please select the correct job below',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 9,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _selectedJobId != null ? Icons.check_circle_rounded : Icons.warning_rounded,
                    color: _selectedJobId != null ? mediumSeaGreen : Colors.orange,
                    size: 14,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildDropdownField(
            'Related Job (Optional)',
            _selectedJobId,
            _jobs.map((job) => DropdownMenuItem<String>(
              value: job['id'] as String,
              child: Text(
                job['title'],
                style: const TextStyle(fontSize: 11),
              ),
            )).toList(),
            (value) {
              setState(() => _selectedJobId = value);
              // Filter applicants when job changes
              _filterApplicantsByJob(value);
            },
            'Select a job',
          ),
          if (_selectedJobId != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: mediumSeaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: mediumSeaGreen.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    color: mediumSeaGreen,
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_applicants.length} ${_applicants.length == 1 ? 'applicant' : 'applicants'} for this job',
                    style: const TextStyle(
                      color: mediumSeaGreen,
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
    );
  }

  Widget _buildTypeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.05),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: mediumSeaGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Event Type',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CalendarEventType.values.map((type) {
              final isSelected = _selectedType == type;
              return _buildTypeChip(type, isSelected);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(CalendarEventType type, bool isSelected) {
    final color = _getEventColor(type);
    final label = type.name.toUpperCase();
    
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeField(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: lightMint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: paleGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: mediumSeaGreen,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: darkTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: darkTeal.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator() {
    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    final currentDate = _formatDate(now);
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: mediumSeaGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: mediumSeaGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_rounded,
            color: mediumSeaGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Time',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$currentDate at ${_formatTimeOfDay(currentTime)}',
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.info_outline_rounded,
            color: mediumSeaGreen,
            size: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildDurationIndicator() {
    if (_selectedStartTime == null || _selectedEndTime == null) {
      return const SizedBox.shrink();
    }

    final startMinutes = _selectedStartTime!.hour * 60 + _selectedStartTime!.minute;
    final endMinutes = _selectedEndTime!.hour * 60 + _selectedEndTime!.minute;
    
    // Calculate duration considering day boundaries
    int durationMinutes;
    if (endMinutes > startMinutes) {
      // Same day: end time is after start time
      durationMinutes = endMinutes - startMinutes;
    } else if (endMinutes < startMinutes) {
      // Next day: end time is next day (crosses midnight)
      durationMinutes = (24 * 60) - startMinutes + endMinutes;
    } else {
      // Same time: invalid
      durationMinutes = 0;
    }

    // Determine color based on duration
    Color indicatorColor;
    String statusText;
    IconData statusIcon;

    if (durationMinutes < 5) {
      indicatorColor = Colors.red;
      statusText = 'Too short (min 5 min)';
      statusIcon = Icons.warning_rounded;
    } else if (durationMinutes > 240) {
      indicatorColor = Colors.red;
      statusText = 'Too long (max 4 hours)';
      statusIcon = Icons.warning_rounded;
    } else if (durationMinutes < 30) {
      indicatorColor = Colors.orange;
      statusText = 'Short meeting';
      statusIcon = Icons.info_outline_rounded;
    } else if (durationMinutes > 180) {
      indicatorColor = Colors.blue;
      statusText = 'Long meeting';
      statusIcon = Icons.info_outline_rounded;
    } else {
      indicatorColor = mediumSeaGreen;
      statusText = 'Good duration';
      statusIcon = Icons.check_circle_rounded;
    }

    // Format duration
    String durationText;
    bool crossesMidnight = endMinutes < startMinutes;
    
    if (durationMinutes < 60) {
      durationText = '${durationMinutes}m';
    } else {
      final hours = durationMinutes ~/ 60;
      final minutes = durationMinutes % 60;
      if (minutes == 0) {
        durationText = '${hours}h';
      } else {
        durationText = '${hours}h ${minutes}m';
      }
    }
    
    // Add midnight crossing indicator
    if (crossesMidnight) {
      durationText += ' (next day)';
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: indicatorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: indicatorColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: indicatorColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meeting Duration: $durationText',
                  style: TextStyle(
                    color: indicatorColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    color: indicatorColor.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    Function(String?) onChanged,
    String hint,
  ) {
    debugPrint('🔍 [ScheduleMeeting] Building dropdown for $label with value: $value');
    debugPrint('🔍 [ScheduleMeeting] Available items: ${items.map((i) => '${i.value}:${i.child}').toList()}');
    
    // Ensure current value exists in items; otherwise reset to null to avoid assertion
    final bool containsValue = items.any((i) => i.value == value);
    final String? effectiveValue = containsValue ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: effectiveValue,
          style: const TextStyle(fontSize: 11, color: darkTeal),
          items: items,
          onChanged: onChanged,
          hint: Text(
            hint,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveMeeting,
        style: ElevatedButton.styleFrom(
          backgroundColor: mediumSeaGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Schedule Meeting',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now, // Can't select past dates
      lastDate: now.add(const Duration(days: MeetingValidationService.maxAdvanceDays)), // 90 days max
      helpText: 'Select Meeting Date',
      confirmText: 'Select',
      cancelText: 'Cancel',
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      
      // Show helpful message for today's date
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Selected today! Start time will suggest current time + 10 minutes'),
              backgroundColor: mediumSeaGreen,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _selectStartTime() async {
    // Get current device time for smart defaults
    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    
    // Smart default: If selecting today's date, suggest current time + 10 minutes
    TimeOfDay initialTime;
    if (_selectedDate != null && 
        _selectedDate!.year == now.year && 
        _selectedDate!.month == now.month && 
        _selectedDate!.day == now.day) {
      // Today's date - suggest current time + 10 minutes (minimum delay)
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final suggestedMinutes = currentMinutes + 10; // 10 minutes from now
      
      initialTime = TimeOfDay(
        hour: (suggestedMinutes ~/ 60) % 24,
        minute: suggestedMinutes % 60,
      );
    } else {
      // Future date - use previous selection or default
      initialTime = _selectedStartTime ?? const TimeOfDay(hour: 9, minute: 0);
    }

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select Start Time',
      confirmText: 'Select',
      cancelText: 'Cancel',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    
    if (time != null) {
      // Validate: If selecting today's date, prevent past times
      if (_selectedDate != null) {
        final now = DateTime.now();
        final selectedDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          time.hour,
          time.minute,
        );
        
        if (selectedDateTime.isBefore(now)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Cannot select a time in the past'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          return;
        }
      }
      
      setState(() => _selectedStartTime = time);
      
      // Auto-suggest end time if not already set
      if (_selectedEndTime == null) {
        _suggestEndTime(time);
      }
    }
  }

  Future<void> _selectEndTime() async {
    // Get current device time for smart defaults
    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    
    // Smart default: If start time is selected, default to 1 hour later
    TimeOfDay initialTime;
    if (_selectedStartTime != null) {
      final startMinutes = _selectedStartTime!.hour * 60 + _selectedStartTime!.minute;
      final endMinutes = startMinutes + 60; // Default 1 hour duration
      
      // Handle day boundary crossing
      if (endMinutes >= 24 * 60) {
        // Crosses midnight - show next day time
        initialTime = TimeOfDay(
          hour: (endMinutes - 24 * 60) ~/ 60,
          minute: (endMinutes - 24 * 60) % 60,
        );
      } else {
        // Same day
        initialTime = TimeOfDay(
          hour: endMinutes ~/ 60,
          minute: endMinutes % 60,
        );
      }
    } else {
      // No start time selected - use smart defaults based on current time
      if (_selectedDate != null && 
          _selectedDate!.year == now.year && 
          _selectedDate!.month == now.month && 
          _selectedDate!.day == now.day) {
        // Today's date - suggest current time + 1 hour (minimum meeting duration)
        final currentMinutes = currentTime.hour * 60 + currentTime.minute;
        final suggestedMinutes = currentMinutes + 60; // 1 hour from now
        
        if (suggestedMinutes >= 24 * 60) {
          // Crosses midnight
          initialTime = TimeOfDay(
            hour: (suggestedMinutes - 24 * 60) ~/ 60,
            minute: (suggestedMinutes - 24 * 60) % 60,
          );
        } else {
          // Same day
          initialTime = TimeOfDay(
            hour: suggestedMinutes ~/ 60,
            minute: suggestedMinutes % 60,
          );
        }
      } else {
        // Future date - use previous selection or default
        initialTime = _selectedEndTime ?? const TimeOfDay(hour: 10, minute: 0);
      }
    }

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: _selectedStartTime != null 
          ? 'Select End Time (suggested: 1 hour after start)'
          : 'Select End Time',
      confirmText: 'Select',
      cancelText: 'Cancel',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    
    if (time != null) {
      // Validate: If selecting today's date, prevent past times
      if (_selectedDate != null) {
        final now = DateTime.now();
        final selectedDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          time.hour,
          time.minute,
        );
        
        if (selectedDateTime.isBefore(now)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Cannot select a time in the past'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          return;
        }
      }

      // Validate: End time must be after start time
      if (_selectedStartTime != null) {
        final startMinutes = _selectedStartTime!.hour * 60 + _selectedStartTime!.minute;
        final endMinutes = time.hour * 60 + time.minute;
        
        // Calculate duration considering day boundaries
        int durationMinutes;
        if (endMinutes > startMinutes) {
          // Same day: end time is after start time
          durationMinutes = endMinutes - startMinutes;
        } else if (endMinutes < startMinutes) {
          // Next day: end time is next day (crosses midnight)
          durationMinutes = (24 * 60) - startMinutes + endMinutes;
        } else {
          // Same time: invalid
          durationMinutes = 0;
        }
        
        // Check if end time is actually after start time (considering day boundaries)
        if (durationMinutes == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('End time must be after start time'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          return;
        }

        // Validate: Check duration constraints
        if (durationMinutes < 5) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Meeting duration must be at least 5 minutes'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          return;
        }

        if (durationMinutes > 240) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Meeting duration cannot exceed 4 hours'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          return;
        }
      }
      
      setState(() => _selectedEndTime = time);
      
      // Show helpful message if no start time is selected
      if (_selectedStartTime == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Don\'t forget to select a start time!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        // Show duration confirmation
        final startMinutes = _selectedStartTime!.hour * 60 + _selectedStartTime!.minute;
        final endMinutes = time.hour * 60 + time.minute;
        
        // Calculate duration considering day boundaries
        int durationMinutes;
        if (endMinutes > startMinutes) {
          durationMinutes = endMinutes - startMinutes;
        } else if (endMinutes < startMinutes) {
          durationMinutes = (24 * 60) - startMinutes + endMinutes;
        } else {
          durationMinutes = 0;
        }
        
        // Format duration for display
        String durationText;
        bool crossesMidnight = endMinutes < startMinutes;
        
        if (durationMinutes < 60) {
          durationText = '${durationMinutes}m';
        } else {
          final hours = durationMinutes ~/ 60;
          final minutes = durationMinutes % 60;
          if (minutes == 0) {
            durationText = '${hours}h';
          } else {
            durationText = '${hours}h ${minutes}m';
          }
        }
        
        if (crossesMidnight) {
          durationText += ' (next day)';
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meeting duration: $durationText'),
              backgroundColor: mediumSeaGreen,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    return '${weekdays[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} at ${_formatTimeOfDay(TimeOfDay.fromDateTime(dateTime))}';
  }

  /// Auto-suggest end time based on start time
  void _suggestEndTime(TimeOfDay startTime) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = startMinutes + 60; // Default 1 hour duration
    
    TimeOfDay suggestedEndTime;
    if (endMinutes >= 24 * 60) {
      // Crosses midnight
      suggestedEndTime = TimeOfDay(
        hour: (endMinutes - 24 * 60) ~/ 60,
        minute: (endMinutes - 24 * 60) % 60,
      );
    } else {
      // Same day
      suggestedEndTime = TimeOfDay(
        hour: endMinutes ~/ 60,
        minute: endMinutes % 60,
      );
    }
    
    setState(() => _selectedEndTime = suggestedEndTime);
    
    // Show helpful message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('End time suggested: ${_formatTimeOfDay(suggestedEndTime)}'),
          backgroundColor: mediumSeaGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
