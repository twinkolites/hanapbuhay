import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/calendar_models.dart';
import '../../services/calendar_service.dart';
import 'book_meeting_screen.dart';

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
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Load events
        final events = await CalendarService.getUserEvents(userId);
        
        // Load meeting requests
        final requests = await CalendarService.getMeetingRequests(userId);
        
        // Load stats
        final stats = await CalendarService.getCalendarStats(userId);
        
        setState(() {
          _events = events;
          _meetingRequests = requests;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load calendar data: $e');
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
          _buildMeetingRequests(),
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
            onPressed: _loadData,
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
              'Requests',
              _meetingRequests.where((r) => r.status == MeetingRequestStatus.pending).length.toString(),
              Icons.pending_rounded,
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

  Widget _buildMeetingRequests() {
    final pendingRequests = _meetingRequests.where((r) => r.status == MeetingRequestStatus.pending).toList();
    
    if (pendingRequests.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
                  Icons.pending_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Pending Meeting Requests',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...pendingRequests.take(3).map((request) => _buildMeetingRequestItem(request)).toList(),
          if (pendingRequests.length > 3) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showAllMeetingRequests(),
              child: Text(
                'View all ${pendingRequests.length} requests',
                style: const TextStyle(color: mediumSeaGreen),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeetingRequestItem(MeetingRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meeting Request',
                  style: const TextStyle(
                    color: darkTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDateTime(request.requestedStartTime)} - ${_formatDateTime(request.requestedEndTime)}',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => _respondToRequest(request.id, MeetingRequestStatus.accepted),
                child: const Text(
                  'Accept',
                  style: TextStyle(color: Colors.green),
                ),
              ),
              TextButton(
                onPressed: () => _respondToRequest(request.id, MeetingRequestStatus.rejected),
                child: const Text(
                  'Decline',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
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
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BookMeetingScreen(),
          ),
        ).then((_) => _loadData());
      },
      backgroundColor: mediumSeaGreen,
      child: const Icon(
        Icons.add_rounded,
        color: Colors.white,
      ),
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
              'Book Meeting',
              Icons.video_call_rounded,
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookMeetingScreen(selectedDate: date),
                  ),
                ).then((_) => _loadData());
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

  void _showAllMeetingRequests() {
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
            const Text(
              'Meeting Requests',
              style: TextStyle(
                color: darkTeal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _meetingRequests.length,
                itemBuilder: (context, index) {
                  final request = _meetingRequests[index];
                  return _buildMeetingRequestItem(request);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _respondToRequest(String requestId, MeetingRequestStatus status) async {
    try {
      await CalendarService.respondToMeetingRequest(requestId, status);
      _loadData();
      
      final message = status == MeetingRequestStatus.accepted 
          ? 'Meeting request accepted!'
          : 'Meeting request declined.';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: status == MeetingRequestStatus.accepted ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to respond to request: $e');
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    return '${weekdays[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.month}/${dateTime.day} $hour:$minute $period';
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
