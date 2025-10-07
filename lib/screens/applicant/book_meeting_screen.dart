import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/calendar_models.dart';
import '../../services/calendar_service.dart';

class BookMeetingScreen extends StatefulWidget {
  final DateTime? selectedDate;
  
  const BookMeetingScreen({super.key, this.selectedDate});

  @override
  State<BookMeetingScreen> createState() => _BookMeetingScreenState();
}

class _BookMeetingScreenState extends State<BookMeetingScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  String? _selectedEmployerId;
  String? _selectedJobId;
  
  bool _isLoading = false;
  bool _isSaving = false;
  
  List<Map<String, dynamic>> _employers = [];
  List<Map<String, dynamic>> _jobs = [];
  List<DateTime> _availableSlots = [];

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
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Load employers (from chat conversations)
        // For now, we'll load all employers
        final employersData = await _supabase
            .from('profiles')
            .select('id, full_name, email')
            .eq('role', 'employer');
        
        setState(() {
          _employers = List<Map<String, dynamic>>.from(employersData);
        });

        // Load jobs
        final jobsData = await _supabase
            .from('jobs')
            .select('id, title, employer_id');
        
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

  Future<void> _loadAvailableSlots() async {
    if (_selectedEmployerId == null || _selectedDate == null) return;

    try {
      setState(() => _isLoading = true);
      final slots = await CalendarService.getAvailableTimeSlots(
        _selectedEmployerId!,
        _selectedDate!,
        durationMinutes: 60,
      );
      
      setState(() {
        _availableSlots = slots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load available slots: $e');
    }
  }

  Future<void> _requestMeeting() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedStartTime == null || _selectedEndTime == null) {
      _showErrorSnackBar('Please select date and time');
      return;
    }
    if (_selectedEmployerId == null) {
      _showErrorSnackBar('Please select an employer');
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

      final request = MeetingRequest(
        id: '',
        applicantId: userId,
        employerId: _selectedEmployerId!,
        jobId: _selectedJobId ?? '',
        requestedStartTime: startDateTime,
        requestedEndTime: endDateTime,
        message: _messageController.text.trim(),
        status: MeetingRequestStatus.pending,
        createdAt: DateTime.now(),
      );

      final createdRequest = await CalendarService.createMeetingRequest(request);
      if (createdRequest != null) {
        // Send notification to employer
        final currentUserEmail = _supabase.auth.currentUser?.email ?? 'Unknown user';
        await CalendarService.sendCalendarNotification(
          userId: _selectedEmployerId!,
          title: 'New Meeting Request',
          message: '$currentUserEmail has requested a meeting for ${_formatDateTime(startDateTime)}',
          type: 'meeting_request',
        );
        
        _showSuccessSnackBar('Meeting request sent successfully!');
        Navigator.pop(context, createdRequest);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send meeting request: $e');
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
        'Book Meeting',
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
            _buildEmployerSelection(),
            const SizedBox(height: 24),
            _buildDateTimeSection(),
            const SizedBox(height: 24),
            _buildMessageSection(),
            const SizedBox(height: 32),
            _buildRequestButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployerSelection() {
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
                  Icons.business_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Select Employer',
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
            'Employer',
            _selectedEmployerId,
            _employers.map((emp) => DropdownMenuItem<String>(
              value: emp['id'] as String,
              child: Text(emp['full_name'] ?? emp['email']),
            )).toList(),
            (value) {
              setState(() {
                _selectedEmployerId = value;
                _selectedJobId = null; // Reset job selection
              });
              _loadAvailableSlots();
            },
            'Select an employer',
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            'Related Job (Optional)',
            _selectedJobId,
            _jobs
                .where((job) => job['employer_id'] == _selectedEmployerId)
                .map((job) => DropdownMenuItem<String>(
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
          if (_availableSlots.isNotEmpty) ...[
            const Text(
              'Available Time Slots',
              style: TextStyle(
                color: darkTeal,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildAvailableSlots(),
          ] else if (_selectedEmployerId != null) ...[
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
        ],
      ),
    );
  }

  Widget _buildAvailableSlots() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availableSlots.map((slot) {
        final isSelected = _selectedStartTime != null &&
            slot.hour == _selectedStartTime!.hour &&
            slot.minute == _selectedStartTime!.minute;
        
        return InkWell(
          onTap: () {
            setState(() {
              _selectedStartTime = TimeOfDay.fromDateTime(slot);
              _selectedEndTime = TimeOfDay.fromDateTime(
                slot.add(const Duration(hours: 1)),
              );
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? mediumSeaGreen : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? mediumSeaGreen : paleGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              _formatTimeOfDay(TimeOfDay.fromDateTime(slot)),
              style: TextStyle(
                color: isSelected ? Colors.white : darkTeal,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageSection() {
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
                  Icons.message_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Message',
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
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Message (Optional)',
              hintText: 'Add a message to your meeting request',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
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

  Widget _buildRequestButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _requestMeeting,
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
                'Request Meeting',
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
      _loadAvailableSlots();
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
