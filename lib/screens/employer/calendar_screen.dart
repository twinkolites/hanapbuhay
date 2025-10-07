import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/calendar_models.dart';
import '../../services/calendar_service.dart';
import 'availability_settings_screen.dart';
import 'schedule_meeting_screen.dart';

class EmployerCalendarScreen extends StatefulWidget {
  const EmployerCalendarScreen({super.key});

  @override
  State<EmployerCalendarScreen> createState() => _EmployerCalendarScreenState();
}

class _EmployerCalendarScreenState extends State<EmployerCalendarScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<CalendarEvent> _events = [];
  bool _isLoading = true;
  CalendarView _currentView = CalendarView.week;
  Map<String, int> _stats = {};

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadStats();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
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

  Future<void> _loadStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final stats = await CalendarService.getCalendarStats(userId);
        setState(() => _stats = stats);
      }
    } catch (e) {
      print('Error loading stats: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightMint,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatsCards(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _buildCalendar(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
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
        'My Calendar',
        style: TextStyle(
          color: darkTeal,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: lightMint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: _loadEvents,
            icon: const Icon(
              Icons.refresh_rounded,
              color: darkTeal,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Upcoming',
              _stats['upcoming']?.toString() ?? '0',
              Icons.schedule_rounded,
              mediumSeaGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Meetings',
              _stats['meetings']?.toString() ?? '0',
              Icons.video_call_rounded,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Interviews',
              _stats['interviews']?.toString() ?? '0',
              Icons.person_rounded,
              Colors.orange,
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
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: darkTeal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
            'Loading calendar...',
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: SfCalendar(
        view: _currentView,
        dataSource: MeetingDataSource(_events),
        onViewChanged: (ViewChangedDetails details) {
          // Handle view changes if needed
        },
        onTap: (CalendarTapDetails details) {
          if (details.targetElement == CalendarElement.calendarCell) {
            _showDateOptions(details.date!);
          }
        },
        monthViewSettings: const MonthViewSettings(
          appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
        ),
        headerStyle: const CalendarHeaderStyle(
          textAlign: TextAlign.center,
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        viewHeaderStyle: const ViewHeaderStyle(
          dayTextStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          dateTextStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        appointmentBuilder: (context, calendarAppointmentDetails) {
          final event = calendarAppointmentDetails.appointments.first as CalendarEvent;
          return _buildAppointmentWidget(event);
        },
      ),
    );
  }

  Widget _buildAppointmentWidget(CalendarEvent event) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: event.color.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: event.color,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (event.location != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 10,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.location!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ScheduleMeetingScreen(),
              ),
            ).then((_) => _loadEvents());
          },
          backgroundColor: mediumSeaGreen,
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AvailabilitySettingsScreen(),
              ),
            );
          },
          backgroundColor: Colors.white,
          child: const Icon(
            Icons.settings_rounded,
            color: mediumSeaGreen,
          ),
        ),
      ],
    );
  }

  void _showDateOptions(DateTime date) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: darkTeal.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Options for ${_formatDate(date)}',
              style: const TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildDateOption(
              'Schedule Meeting',
              Icons.video_call_rounded,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScheduleMeetingScreen(selectedDate: date),
                  ),
                ).then((_) => _loadEvents());
              },
            ),
            _buildDateOption(
              'Set Availability',
              Icons.schedule_rounded,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AvailabilitySettingsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDateOption(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: mediumSeaGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: mediumSeaGreen,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: darkTeal,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    return '${weekdays[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }
}

class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<CalendarEvent> source) {
    appointments = source;
  }

  @override
  DateTime getStartTime(int index) {
    return appointments![index].startTime;
  }

  @override
  DateTime getEndTime(int index) {
    return appointments![index].endTime;
  }

  @override
  String getSubject(int index) {
    return appointments![index].title;
  }

  @override
  Color getColor(int index) {
    return appointments![index].color;
  }

  @override
  bool isAllDay(int index) {
    return appointments![index].isAllDay;
  }

  CalendarEvent getAppointment(int index) {
    return appointments![index];
  }
}
