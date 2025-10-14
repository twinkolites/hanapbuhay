import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/reschedule_service.dart';

class RescheduleRequestSheet extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final DateTime originalStartTime;
  final DateTime originalEndTime;
  
  const RescheduleRequestSheet({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.originalStartTime,
    required this.originalEndTime,
  });

  @override
  State<RescheduleRequestSheet> createState() => _RescheduleRequestSheetState();
}

class _RescheduleRequestSheetState extends State<RescheduleRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  
  String _selectedReason = '';
  DateTime? _preferredDate;
  TimeOfDay? _preferredStartTime;
  TimeOfDay? _preferredEndTime;
  
  bool _isLoading = false;
  
  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: darkTeal.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Request Reschedule',
                          style: TextStyle(
                            color: darkTeal,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.eventTitle,
                          style: TextStyle(
                            color: darkTeal.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),
              
              // Original time
              _buildInfoRow(
                Icons.access_time_rounded,
                'Original Time',
                '${_formatDate(widget.originalStartTime)} • ${_formatTime(widget.originalStartTime)} - ${_formatTime(widget.originalEndTime)}',
              ),
              
              const SizedBox(height: 20),
              
              // Reason selection
              _buildReasonSection(),
              
              const SizedBox(height: 20),
              
              // Preferred date
              _buildDateSection(),
              
              const SizedBox(height: 20),
              
              // Preferred time
              _buildTimeSection(),
              
              const SizedBox(height: 30),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: darkTeal.withValues(alpha: 0.7),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: darkTeal.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mediumSeaGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Submit Request',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
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
      ],
    );
  }
  
  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reason for Reschedule',
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Predefined reasons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: RescheduleService.getRescheduleReasons().map((reason) {
            final isSelected = _selectedReason == reason;
            return InkWell(
              onTap: () => setState(() => _selectedReason = reason),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? mediumSeaGreen : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? mediumSeaGreen : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  reason,
                  style: TextStyle(
                    color: isSelected ? Colors.white : darkTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 12),
        
        // Custom reason field
        if (_selectedReason == 'Other') ...[
          TextFormField(
            controller: _reasonController,
            decoration: InputDecoration(
              hintText: 'Please specify the reason...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: mediumSeaGreen, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 3,
            validator: (value) {
              if (_selectedReason == 'Other' && (value == null || value.trim().isEmpty)) {
                return 'Please provide a reason';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }
  
  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferred Date (Optional)',
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _preferredDate != null 
                      ? _formatDate(_preferredDate!)
                      : 'Select preferred date',
                  style: TextStyle(
                    color: _preferredDate != null ? darkTeal : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferred Time (Optional)',
          style: TextStyle(
            color: darkTeal,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _buildTimeField(
                'Start Time',
                _preferredStartTime,
                () => _selectStartTime(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimeField(
                'End Time',
                _preferredEndTime,
                () => _selectEndTime(),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTimeField(String label, TimeOfDay? time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: mediumSeaGreen,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  time != null ? _formatTimeOfDay(time) : 'Select time',
                  style: TextStyle(
                    color: time != null ? darkTeal : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (date != null) {
      setState(() => _preferredDate = date);
    }
  }
  
  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _preferredStartTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    
    if (time != null) {
      setState(() => _preferredStartTime = time);
    }
  }
  
  Future<void> _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _preferredEndTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    
    if (time != null) {
      setState(() => _preferredEndTime = time);
    }
  }
  
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason for rescheduling'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      
      final reason = _selectedReason == 'Other' 
          ? _reasonController.text.trim()
          : _selectedReason;
      
      final success = await RescheduleService.createRescheduleRequest(
        originalEventId: widget.eventId,
        requesterId: currentUser.id,
        reason: reason,
        preferredDate: _preferredDate,
        preferredStartTime: _preferredStartTime,
        preferredEndTime: _preferredEndTime,
      );
      
      if (success) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reschedule request submitted successfully'),
              backgroundColor: mediumSeaGreen,
            ),
          );
        }
      } else {
        throw Exception('Failed to submit request');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    
    return '${weekdays[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  
  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
  
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
