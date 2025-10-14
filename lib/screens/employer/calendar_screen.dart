import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../models/calendar_models.dart';
import '../../services/calendar_service.dart';
import '../../services/attendance_tracking_service.dart';
import '../../services/meeting_status_updater.dart';
import '../../widgets/event_detail_sheet.dart';

class EmployerCalendarScreen extends StatefulWidget {
  const EmployerCalendarScreen({super.key});

  @override
  State<EmployerCalendarScreen> createState() => _EmployerCalendarScreenState();
}

class _EmployerCalendarScreenState extends State<EmployerCalendarScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<CalendarEvent> _events = [];
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<String, int> _stats = {};
  Timer? _realtimeTimer; // Timer for real-time updates
  Timer? _statusUpdateTimer; // Timer for auto-updating past meetings
  RealtimeChannel? _calendarEventsChannel; // realtime subscription

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  // keep palette consistent; paleGreen used in other calendar widgets
  // Note: paleGreen defined for consistency but not used directly in this file
  // ignore: unused_field
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
    _loadStats();
    
    // Update UI every minute to keep "ongoing" status accurate
    _realtimeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _checkAndUpdateMeetingStatuses();
        setState(() {
          // Force rebuild to update ongoing/past/upcoming status
        });
      }
    });
    
    // Auto-update meeting statuses every 5 minutes
    _statusUpdateTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (mounted) {
        await _updateAllEventStatuses();
      }
    });
  }
  
  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _statusUpdateTimer?.cancel();
    try { _calendarEventsChannel?.unsubscribe(); } catch (_) {}
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Auto-update past events first
        await MeetingStatusUpdater.updateAllUserEvents(userId);
        
        // Then load events
        final events = await CalendarService.getUserEvents(userId);
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load calendar events: $e');
    }
  }
  
  /// Check and update meeting statuses in real-time
  void _checkAndUpdateMeetingStatuses() {
    // Update local state to reflect accurate status
    for (var event in _events) {
      final accurateStatus = MeetingStatusUpdater.getAccurateStatus(event);
      if (accurateStatus != event.status) {
        print('🔄 Event "${event.title}" status changed: ${event.status} → $accurateStatus');
      }
    }
  }
  
  /// Update all event statuses in database
  Future<void> _updateAllEventStatuses() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      final updated = await MeetingStatusUpdater.updateAllUserEvents(userId);
      if (updated > 0 && mounted) {
        print('✅ Auto-updated $updated meetings to completed');
        // Reload events to reflect changes
        _loadEvents();
        _loadStats();
    _subscribeToRealtime();
      }
    }
  }

  void _subscribeToRealtime() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    // Listen for new calendar events for this employer
    _calendarEventsChannel = _supabase
        .channel('calendar_events_employer_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calendar_events',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'employer_id', value: userId),
          callback: (payload) async {
            await _loadEvents();
            await _loadStats();
          },
        )
        .subscribe();
  }

  Future<void> _loadStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final requests = await CalendarService.getMeetingRequests(userId);
        setState(() {
          _stats = {
            'total': _events.length,
            'pending': requests.where((r) => r.status == MeetingRequestStatus.pending).length,
            'upcoming': _events.where((e) => e.startTime.isAfter(DateTime.now())).length,
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return _events.where((event) {
      return isSameDay(event.startTime, day);
    }).toList();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: AppBar(
        title: const Text(
          'My Calendar',
          style: TextStyle(
            color: darkTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkTeal),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_rounded),
            onPressed: () {
              Navigator.pushNamed(context, '/availability-settings');
            },
            tooltip: 'Availability Settings',
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              Navigator.pushNamed(context, '/schedule-meeting');
            },
            tooltip: 'Schedule Meeting',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEvents,
              color: mediumSeaGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildStatsCards(),
                    _buildTodaysAgenda(),
                    _buildCalendar(),
                    _buildEventsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTodaysAgenda() {
    // Get today's events
    final today = DateTime.now();
    final now = DateTime.now();
    final todaysEvents = _getEventsForDay(today)
        .where((e) => e.endTime.isAfter(now)) // Only show events that haven't ended
        .toList();
    
    if (todaysEvents.isEmpty) {
      return const SizedBox.shrink(); // Hide if no events today
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            mediumSeaGreen.withValues(alpha: 0.1),
            lightMint.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mediumSeaGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.today_rounded,
                  color: mediumSeaGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Today\'s Agenda',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: mediumSeaGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${todaysEvents.length} ${todaysEvents.length == 1 ? 'event' : 'events'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...todaysEvents.map((event) => _buildAgendaItem(event)).toList(),
        ],
      ),
    );
  }

  Widget _buildAgendaItem(CalendarEvent event) {
    final now = DateTime.now();
    final isUpcoming = event.startTime.isAfter(now);
    final isPast = event.endTime.isBefore(now);
    final isOngoing = !isUpcoming && !isPast;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOngoing
              ? mediumSeaGreen
              : mediumSeaGreen.withValues(alpha: 0.2),
          width: isOngoing ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Time
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isOngoing
                  ? mediumSeaGreen.withValues(alpha: 0.15)
                  : lightMint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${event.startTime.hour > 12 ? event.startTime.hour - 12 : (event.startTime.hour == 0 ? 12 : event.startTime.hour)}:${event.startTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: isOngoing ? mediumSeaGreen : darkTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  event.startTime.hour >= 12 ? 'PM' : 'AM',
                  style: TextStyle(
                    color: isOngoing
                        ? mediumSeaGreen.withValues(alpha: 0.7)
                        : darkTeal.withValues(alpha: 0.5),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Event info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          color: darkTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOngoing)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: mediumSeaGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 6,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (event.description != null && event.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description!,
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Events',
              '${_stats['total'] ?? 0}',
              Icons.event_rounded,
              mediumSeaGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Pending',
              '${_stats['pending'] ?? 0}',
              Icons.pending_rounded,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Upcoming',
              '${_stats['upcoming'] ?? 0}',
              Icons.upcoming_rounded,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: darkTeal,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: _calendarFormat,
        eventLoader: _getEventsForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        // Enable only today and future dates for selection
        enabledDayPredicate: (day) {
          final today = DateTime.now();
          final isToday = day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;
          return !day.isBefore(today) || isToday;
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: mediumSeaGreen.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: mediumSeaGreen,
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: mediumSeaGreen,
            shape: BoxShape.circle,
          ),
          weekendTextStyle: const TextStyle(color: Colors.red),
          // Style past dates as disabled
          disabledTextStyle: TextStyle(
            color: Colors.grey.shade300,
          ),
          outsideTextStyle: TextStyle(
            color: Colors.grey.shade400,
          ),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonDecoration: BoxDecoration(
            color: mediumSeaGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          formatButtonTextStyle: const TextStyle(
            color: mediumSeaGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          // Only allow selecting today or future dates
          final today = DateTime.now();
          final isToday = selectedDay.year == today.year &&
              selectedDay.month == today.month &&
              selectedDay.day == today.day;
          
          if (selectedDay.isBefore(today) && !isToday) {
            // Show message for past dates
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Cannot select past dates'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            return;
          }
          
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }

  Widget _buildEventsList() {
    final selectedEvents = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];
    
    if (selectedEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 64,
              color: mediumSeaGreen.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No events scheduled',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              'Events on ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
              style: const TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...selectedEvents.map((event) => _buildEventCard(event)).toList(),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    return Dismissible(
      key: ValueKey('event_${event.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Delete Event', style: TextStyle(color: darkTeal, fontWeight: FontWeight.bold, fontSize: 16)),
            content: Text(
              'Delete "${event.title}"? This action cannot be undone.',
              style: TextStyle(color: darkTeal.withValues(alpha: 0.8), fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: TextStyle(color: darkTeal.withValues(alpha: 0.7))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return false;
        }
        final ok = await CalendarService.deleteEvent(event.id);
        if (ok) {
          await _loadEvents();
          await _loadStats();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event deleted'), backgroundColor: Colors.grey),
            );
          }
          return true;
        }
        if (mounted) _showErrorSnackBar('Failed to delete event');
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        onTap: () {
          // Show event details bottom sheet
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => EventDetailSheet(
              event: event,
              isEmployer: true,
              pageContext: this.context,
            ),
          );
        },
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mediumSeaGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            event.type == CalendarEventType.meeting ? Icons.video_call_rounded : Icons.event_rounded,
            color: mediumSeaGreen,
          ),
        ),
        title: Text(
          event.title,
          style: const TextStyle(
            color: darkTeal,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            if (event.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                event.description!,
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            _buildAttendancePreview(event),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(event.status.name).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            event.status.name.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(event.status.name),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'scheduled':
        return mediumSeaGreen;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Compact attendance preview chip similar to EventDetailSheet section
  Widget _buildAttendancePreview(CalendarEvent event) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AttendanceTrackingService.getAttendanceRecord(event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final attendance = snapshot.data;
        if (attendance == null) return const SizedBox.shrink();

        final status = attendance['attendance_status'] as String? ?? 'scheduled';
        final isNoShow = attendance['is_no_show'] as bool? ?? false;
        final color = AttendanceTrackingService.getAttendanceColor(status);
        final summary = AttendanceTrackingService.getAttendanceSummary(attendance);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNoShow ? Icons.person_off_rounded : Icons.how_to_reg_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                summary,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // (old delete helper removed; Dismissible handles confirmation)
}
