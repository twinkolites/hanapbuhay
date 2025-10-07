import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/calendar_models.dart';
import '../../services/calendar_service.dart';

class AvailabilitySettingsScreen extends StatefulWidget {
  const AvailabilitySettingsScreen({super.key});

  @override
  State<AvailabilitySettingsScreen> createState() => _AvailabilitySettingsScreenState();
}

class _AvailabilitySettingsScreenState extends State<AvailabilitySettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  AvailabilitySettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  // Default availability settings
  final List<AvailabilitySlot> _defaultSlots = [
    AvailabilitySlot(dayOfWeek: 1, startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 17, minute: 0)), // Monday
    AvailabilitySlot(dayOfWeek: 2, startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 17, minute: 0)), // Tuesday
    AvailabilitySlot(dayOfWeek: 3, startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 17, minute: 0)), // Wednesday
    AvailabilitySlot(dayOfWeek: 4, startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 17, minute: 0)), // Thursday
    AvailabilitySlot(dayOfWeek: 5, startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 17, minute: 0)), // Friday
  ];

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final settings = await CalendarService.getAvailabilitySettings(userId);
        setState(() {
          _settings = settings ?? AvailabilitySettings(
            userId: userId,
            weeklyAvailability: _defaultSlots,
            createdAt: DateTime.now(),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load availability settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    try {
      setState(() => _isSaving = true);
      final updatedSettings = await CalendarService.updateAvailabilitySettings(_settings!);
      if (updatedSettings != null) {
        setState(() => _settings = updatedSettings);
        _showSuccessSnackBar('Availability settings saved successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save availability settings: $e');
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
        'Availability Settings',
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
            'Loading availability settings...',
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
    if (_settings == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGeneralSettings(),
          const SizedBox(height: 24),
          _buildWeeklyAvailability(),
          const SizedBox(height: 24),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
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
                  Icons.settings_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'General Settings',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingRow(
            'Advance Booking Days',
            'How many days in advance can meetings be booked',
            _settings!.advanceBookingDays.toString(),
            Icons.calendar_today_rounded,
            () => _showAdvanceBookingDialog(),
          ),
          const SizedBox(height: 16),
          _buildSettingRow(
            'Meeting Duration',
            'Default duration for meetings',
            '${_settings!.meetingDurationMinutes} minutes',
            Icons.schedule_rounded,
            () => _showDurationDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String title, String subtitle, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
            Container(
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: darkTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: mediumSeaGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
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

  Widget _buildWeeklyAvailability() {
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
                  Icons.calendar_view_week_rounded,
                  color: mediumSeaGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Weekly Availability',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(7, (index) {
            final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
            final daySlots = _settings!.weeklyAvailability.where((slot) => slot.dayOfWeek == index).toList();
            return _buildDayAvailability(dayNames[index], index, daySlots);
          }),
        ],
      ),
    );
  }

  Widget _buildDayAvailability(String dayName, int dayIndex, List<AvailabilitySlot> slots) {
    final isAvailable = slots.isNotEmpty && slots.first.isAvailable;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightMint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dayName,
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: isAvailable,
                onChanged: (value) => _toggleDayAvailability(dayIndex, value),
                activeColor: mediumSeaGreen,
              ),
            ],
          ),
          if (isAvailable) ...[
            const SizedBox(height: 12),
            ...slots.map((slot) => _buildTimeSlot(dayIndex, slot)).toList(),
            const SizedBox(height: 8),
            _buildAddTimeSlotButton(dayIndex),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeSlot(int dayIndex, AvailabilitySlot slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: paleGreen.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_formatTimeOfDay(slot.startTime)} - ${_formatTimeOfDay(slot.endTime)}',
              style: const TextStyle(
                color: darkTeal,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _editTimeSlot(dayIndex, slot),
            icon: const Icon(
              Icons.edit_rounded,
              color: mediumSeaGreen,
              size: 16,
            ),
          ),
          IconButton(
            onPressed: () => _removeTimeSlot(dayIndex, slot),
            icon: const Icon(
              Icons.delete_rounded,
              color: Colors.red,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTimeSlotButton(int dayIndex) {
    return InkWell(
      onTap: () => _addTimeSlot(dayIndex),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mediumSeaGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: mediumSeaGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: mediumSeaGreen,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Add Time Slot',
              style: TextStyle(
                color: mediumSeaGreen,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSettings,
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
                'Save Availability Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _toggleDayAvailability(int dayIndex, bool isAvailable) {
    setState(() {
      if (isAvailable) {
        // Add default time slot if none exists
        final existingSlots = _settings!.weeklyAvailability.where((slot) => slot.dayOfWeek == dayIndex).toList();
        if (existingSlots.isEmpty) {
          _settings = AvailabilitySettings(
            userId: _settings!.userId,
            weeklyAvailability: [
              ..._settings!.weeklyAvailability,
              AvailabilitySlot(
                dayOfWeek: dayIndex,
                startTime: const TimeOfDay(hour: 9, minute: 0),
                endTime: const TimeOfDay(hour: 17, minute: 0),
                isAvailable: true,
              ),
            ],
            advanceBookingDays: _settings!.advanceBookingDays,
            meetingDurationMinutes: _settings!.meetingDurationMinutes,
            blockedDates: _settings!.blockedDates,
            createdAt: _settings!.createdAt,
            updatedAt: DateTime.now(),
          );
        } else {
          // Update existing slots
          final updatedSlots = _settings!.weeklyAvailability.map((slot) {
            if (slot.dayOfWeek == dayIndex) {
              return AvailabilitySlot(
                dayOfWeek: slot.dayOfWeek,
                startTime: slot.startTime,
                endTime: slot.endTime,
                isAvailable: true,
              );
            }
            return slot;
          }).toList();
          
          _settings = AvailabilitySettings(
            userId: _settings!.userId,
            weeklyAvailability: updatedSlots,
            advanceBookingDays: _settings!.advanceBookingDays,
            meetingDurationMinutes: _settings!.meetingDurationMinutes,
            blockedDates: _settings!.blockedDates,
            createdAt: _settings!.createdAt,
            updatedAt: DateTime.now(),
          );
        }
      } else {
        // Remove all slots for this day
        final updatedSlots = _settings!.weeklyAvailability.where((slot) => slot.dayOfWeek != dayIndex).toList();
        
        _settings = AvailabilitySettings(
          userId: _settings!.userId,
          weeklyAvailability: updatedSlots,
          advanceBookingDays: _settings!.advanceBookingDays,
          meetingDurationMinutes: _settings!.meetingDurationMinutes,
          blockedDates: _settings!.blockedDates,
          createdAt: _settings!.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    });
  }

  void _addTimeSlot(int dayIndex) {
    showDialog(
      context: context,
      builder: (context) => _TimeSlotDialog(
        onSave: (startTime, endTime) {
          setState(() {
            final newSlot = AvailabilitySlot(
              dayOfWeek: dayIndex,
              startTime: startTime,
              endTime: endTime,
              isAvailable: true,
            );
            
            _settings = AvailabilitySettings(
              userId: _settings!.userId,
              weeklyAvailability: [..._settings!.weeklyAvailability, newSlot],
              advanceBookingDays: _settings!.advanceBookingDays,
              meetingDurationMinutes: _settings!.meetingDurationMinutes,
              blockedDates: _settings!.blockedDates,
              createdAt: _settings!.createdAt,
              updatedAt: DateTime.now(),
            );
          });
        },
      ),
    );
  }

  void _editTimeSlot(int dayIndex, AvailabilitySlot slot) {
    showDialog(
      context: context,
      builder: (context) => _TimeSlotDialog(
        initialStartTime: slot.startTime,
        initialEndTime: slot.endTime,
        onSave: (startTime, endTime) {
          setState(() {
            final updatedSlots = _settings!.weeklyAvailability.map((s) {
              if (s.dayOfWeek == slot.dayOfWeek && 
                  s.startTime == slot.startTime && 
                  s.endTime == slot.endTime) {
                return AvailabilitySlot(
                  dayOfWeek: dayIndex,
                  startTime: startTime,
                  endTime: endTime,
                  isAvailable: true,
                );
              }
              return s;
            }).toList();
            
            _settings = AvailabilitySettings(
              userId: _settings!.userId,
              weeklyAvailability: updatedSlots,
              advanceBookingDays: _settings!.advanceBookingDays,
              meetingDurationMinutes: _settings!.meetingDurationMinutes,
              blockedDates: _settings!.blockedDates,
              createdAt: _settings!.createdAt,
              updatedAt: DateTime.now(),
            );
          });
        },
      ),
    );
  }

  void _removeTimeSlot(int dayIndex, AvailabilitySlot slot) {
    setState(() {
      final updatedSlots = _settings!.weeklyAvailability.where((s) => 
          !(s.dayOfWeek == slot.dayOfWeek && 
            s.startTime == slot.startTime && 
            s.endTime == slot.endTime)
      ).toList();
      
      _settings = AvailabilitySettings(
        userId: _settings!.userId,
        weeklyAvailability: updatedSlots,
        advanceBookingDays: _settings!.advanceBookingDays,
        meetingDurationMinutes: _settings!.meetingDurationMinutes,
        blockedDates: _settings!.blockedDates,
        createdAt: _settings!.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  void _showAdvanceBookingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Advance Booking Days'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How many days in advance can meetings be booked?'),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _settings!.advanceBookingDays.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Days',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final days = int.tryParse(value);
                if (days != null && days > 0) {
                  setState(() {
                    _settings = AvailabilitySettings(
                      userId: _settings!.userId,
                      weeklyAvailability: _settings!.weeklyAvailability,
                      advanceBookingDays: days,
                      meetingDurationMinutes: _settings!.meetingDurationMinutes,
                      blockedDates: _settings!.blockedDates,
                      createdAt: _settings!.createdAt,
                      updatedAt: DateTime.now(),
                    );
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDurationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meeting Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Default duration for meetings (in minutes):'),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _settings!.meetingDurationMinutes.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutes',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final minutes = int.tryParse(value);
                if (minutes != null && minutes > 0) {
                  setState(() {
                    _settings = AvailabilitySettings(
                      userId: _settings!.userId,
                      weeklyAvailability: _settings!.weeklyAvailability,
                      advanceBookingDays: _settings!.advanceBookingDays,
                      meetingDurationMinutes: minutes,
                      blockedDates: _settings!.blockedDates,
                      createdAt: _settings!.createdAt,
                      updatedAt: DateTime.now(),
                    );
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _TimeSlotDialog extends StatefulWidget {
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;
  final Function(TimeOfDay startTime, TimeOfDay endTime) onSave;

  const _TimeSlotDialog({
    this.initialStartTime,
    this.initialEndTime,
    required this.onSave,
  });

  @override
  State<_TimeSlotDialog> createState() => _TimeSlotDialogState();
}

class _TimeSlotDialogState extends State<_TimeSlotDialog> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime ?? const TimeOfDay(hour: 9, minute: 0);
    _endTime = widget.initialEndTime ?? const TimeOfDay(hour: 17, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Time Slot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Start Time'),
            subtitle: Text(_formatTimeOfDay(_startTime)),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _startTime,
              );
              if (time != null) {
                setState(() => _startTime = time);
              }
            },
          ),
          ListTile(
            title: const Text('End Time'),
            subtitle: Text(_formatTimeOfDay(_endTime)),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _endTime,
              );
              if (time != null) {
                setState(() => _endTime = time);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onSave(_startTime, _endTime);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
