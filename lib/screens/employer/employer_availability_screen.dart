import 'package:flutter/material.dart';
import '../../services/calendar_service.dart';
import '../../models/calendar_models.dart';

class EmployerAvailabilityScreen extends StatefulWidget {
  final String employerId;

  const EmployerAvailabilityScreen({super.key, required this.employerId});

  @override
  State<EmployerAvailabilityScreen> createState() => _EmployerAvailabilityScreenState();
}

class _EmployerAvailabilityScreenState extends State<EmployerAvailabilityScreen> {
  AvailabilitySettings? _settings;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  List<DateTime> _availableSlots = [];

  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() => _isLoading = true);
      final settings = await CalendarService.getAvailabilitySettings(widget.employerId);
      _settings = settings;
      await _loadSlotsForDate(_selectedDate);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSlotsForDate(DateTime date) async {
    if (_settings == null) return;
    final duration = _settings!.meetingDurationMinutes;
    final slots = await CalendarService.getAvailableTimeSlots(
      widget.employerId,
      DateTime(date.year, date.month, date.day),
      durationMinutes: duration,
    );
    if (mounted) setState(() => _availableSlots = slots);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Employer Availability', style: TextStyle(color: darkTeal)),
        iconTheme: const IconThemeData(color: darkTeal),
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading ? _buildLoading() : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: mediumSeaGreen),
    );
  }

  Widget _buildContent() {
    if (_settings == null) {
      return const Center(
        child: Text('No availability configured', style: TextStyle(color: darkTeal)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeeklyGrid(),
          const SizedBox(height: 16),
          _buildDatePicker(),
          const SizedBox(height: 12),
          _buildSlotsList(),
        ],
      ),
    );
  }

  Widget _buildWeeklyGrid() {
    final dayNames = const ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    final Map<int, List<AvailabilitySlot>> byDay = {};
    for (final slot in _settings!.weeklyAvailability) {
      byDay.putIfAbsent(slot.dayOfWeek, () => []).add(slot);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Availability', style: TextStyle(color: darkTeal, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...List.generate(7, (i) {
            final slots = byDay[i] ?? [];
            final isAvailable = slots.any((s) => s.isAvailable);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text(dayNames[i], style: const TextStyle(color: darkTeal, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  if (!isAvailable)
                    Text('Unavailable', style: TextStyle(color: darkTeal.withValues(alpha: 0.6)))
                  else
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: slots.where((s) => s.isAvailable).map((s) => _chip('${_fmt(s.startTime)}–${_fmt(s.endTime)}')).toList(),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event, color: mediumSeaGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_selectedDate.year}-${_two(_selectedDate.month)}-${_two(_selectedDate.day)}',
              style: const TextStyle(color: darkTeal, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(Duration(days: _settings!.advanceBookingDays)),
                initialDate: _selectedDate,
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                await _loadSlotsForDate(picked);
              }
            },
            child: const Text('Change', style: TextStyle(color: mediumSeaGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paleGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bookable Slots', style: TextStyle(color: darkTeal, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_availableSlots.isEmpty)
            Text('No slots available for the selected date', style: TextStyle(color: darkTeal.withValues(alpha: 0.6)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSlots.map((dt) => _chip(_fmtDT(dt))).toList(),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: mediumSeaGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: mediumSeaGreen.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: const TextStyle(color: darkTeal, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _fmt(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';
  String _fmtDT(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
  String _two(int v) => v.toString().padLeft(2, '0');
}


