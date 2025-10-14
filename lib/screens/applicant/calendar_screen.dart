import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../models/calendar_models.dart';
import '../../services/calendar_service.dart';
import '../../services/meeting_status_updater.dart';
import '../../widgets/event_detail_sheet.dart';

class ApplicantCalendarScreen extends StatefulWidget {
  const ApplicantCalendarScreen({super.key});

  @override
  State<ApplicantCalendarScreen> createState() => _ApplicantCalendarScreenState();
}

class _ApplicantCalendarScreenState extends State<ApplicantCalendarScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<CalendarEvent> _events = [];
  List<MeetingRequest> _meetingRequests = [];
  bool _isLoading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<String, int> _stats = {};
  Timer? _realtimeTimer; // Timer for real-time updates
  Timer? _statusUpdateTimer; // Timer for auto-updating past meetings

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  // static const Color paleGreen = Color(0xFFC0E6BA); // not used in this screen
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadData();
    
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
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Auto-update past events first
        await MeetingStatusUpdater.updateAllUserEvents(userId);
        
        // Then load events and requests
        final events = await CalendarService.getUserEvents(userId);
        final requests = await CalendarService.getMeetingRequests(userId);
        setState(() {
          _events = events;
          _meetingRequests = requests;
          _isLoading = false;
          _stats = {
            'total': events.length,
            'pending': requests.where((r) => r.status == MeetingRequestStatus.pending).length,
            'upcoming': events.where((e) => e.endTime.isAfter(DateTime.now())).length,
          };
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load calendar data: $e');
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
        _loadData();
      }
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
          'My Meetings',
          style: TextStyle(
            color: darkTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkTeal),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: mediumSeaGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildStatsCards(),
                    _buildTodaysAgenda(),
                    _buildCalendar(),
                    if (_meetingRequests.where((r) => r.status == MeetingRequestStatus.pending).isNotEmpty)
                      _buildMeetingRequests(),
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
              'Total Meetings',
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: darkTeal,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 10,
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

  Widget _buildMeetingRequests() {
    final pendingRequests = _meetingRequests
        .where((r) => r.status == MeetingRequestStatus.pending)
        .toList();

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              'Pending Meeting Requests',
              style: TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...pendingRequests.map((request) => _buildMeetingRequestCard(request)).toList(),
        ],
      ),
    );
  }

  Widget _buildMeetingRequestCard(MeetingRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: darkTeal.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pending_actions_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Meeting Request',
                    style: const TextStyle(
                      color: darkTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_formatDate(request.requestedStartTime)} at ${_formatTime(request.requestedStartTime)}',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            if (request.message?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                request.message!,
                style: TextStyle(
                  color: darkTeal.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
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
              'No meetings scheduled',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your scheduled meetings will appear here',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.5),
                fontSize: 12,
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
              'Meetings on ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
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
    return Container(
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
              isEmployer: false,
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
            if (event.meetingLink?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.video_call_rounded,
                      size: 14,
                      color: mediumSeaGreen,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Video call link available',
                      style: TextStyle(
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

  String _formatDate(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
}
