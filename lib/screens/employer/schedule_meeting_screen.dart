import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/calendar_models.dart';
import '../../services/calendar_service.dart';
import '../../services/chat_service.dart';

class ScheduleMeetingScreen extends StatefulWidget {
  final DateTime? selectedDate;
  
  const ScheduleMeetingScreen({super.key, this.selectedDate});

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
  List<Map<String, dynamic>> _jobs = [];

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();
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
        // Load applicants (from chat conversations)
        final chats = await ChatService.getUserChats(userId);
        final applicantIds = chats.map((chat) => chat.id).toSet();
        
        final applicantsData = await _supabase
            .from('profiles')
            .select('id, full_name, email')
            .inFilter('id', applicantIds.toList())
            .eq('role', 'applicant');
        
        setState(() {
          _applicants = List<Map<String, dynamic>>.from(applicantsData);
        });

        // Load jobs
        final jobsData = await _supabase
            .from('jobs')
            .select('id, title, company_id')
            .eq('employer_id', userId);
        
        setState(() {
          _jobs = List<Map<String, dynamic>>.from(jobsData);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMeeting() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedStartTime == null || _selectedEndTime == null) {
      _showErrorSnackBar('Please select date and time');
      return;
    }

    try {
      setState(() => _isSaving = true);
      
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

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
          fontSize: 20,
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
          const SizedBox(height: 16),
          Text(
            'Loading data...',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
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
            const SizedBox(height: 24),
            _buildDateTimeSection(),
            const SizedBox(height: 24),
            _buildParticipantsSection(),
            const SizedBox(height: 24),
            _buildTypeSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Basic Information',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Meeting Title',
              hintText: 'Enter meeting title',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a meeting title';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Enter meeting description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Location (Optional)',
              hintText: 'Enter meeting location or video call link',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Date & Time',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDateTimeField(
            'Date',
            _selectedDate != null ? _formatDate(_selectedDate!) : 'Select Date',
            Icons.calendar_month_rounded,
            () => _selectDate(),
          ),
          const SizedBox(height: 16),
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
              const SizedBox(width: 16),
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
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Participants',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDropdownField(
            'Applicant (Optional)',
            _selectedApplicantId,
            _applicants.map((app) => DropdownMenuItem<String>(
              value: app['id'] as String,
              child: Text(app['full_name'] ?? app['email']),
            )).toList(),
            (value) => setState(() => _selectedApplicantId = value),
            'Select an applicant',
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            'Related Job (Optional)',
            _selectedJobId,
            _jobs.map((job) => DropdownMenuItem<String>(
              value: job['id'] as String,
              child: Text(job['title']),
            )).toList(),
            (value) => setState(() => _selectedJobId = value),
            'Select a job',
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Event Type',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontSize: 12,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lightMint,
          borderRadius: BorderRadius.circular(12),
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
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: darkTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: darkTeal.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: darkTeal.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                hint,
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.5),
                ),
              ),
            ),
            ...items,
          ],
          onChanged: onChanged,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Schedule Meeting',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) {
      setState(() => _selectedStartTime = time);
    }
  }

  Future<void> _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (time != null) {
      setState(() => _selectedEndTime = time);
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
}
