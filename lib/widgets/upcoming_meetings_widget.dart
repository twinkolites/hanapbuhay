import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/calendar_models.dart';
import '../services/calendar_service.dart';
import '../services/video_call_service.dart';
import 'event_detail_sheet.dart';

class UpcomingMeetingsWidget extends StatefulWidget {
  final bool isEmployer;
  
  const UpcomingMeetingsWidget({
    super.key,
    required this.isEmployer,
  });

  @override
  State<UpcomingMeetingsWidget> createState() => _UpcomingMeetingsWidgetState();
}

class _UpcomingMeetingsWidgetState extends State<UpcomingMeetingsWidget> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<CalendarEvent> _upcomingMeetings = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  Timer? _countdownTimer;

  // Color palette
  static const Color lightMint = Color(0xFFEAF9E7);
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadUpcomingMeetings();
    
    // Refresh every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) _loadUpcomingMeetings();
    });
    
    // Update countdown every minute
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {}); // Rebuild to update countdown
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUpcomingMeetings() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get upcoming events (next 7 days)
      final now = DateTime.now();
      final nextWeek = now.add(const Duration(days: 7));
      
      final events = await CalendarService.getUserEvents(
        userId,
        startDate: now,
        endDate: nextWeek,
      );
      
      // Filter and sort: only upcoming or ongoing, not completed, sorted by start time
      // Exclude meetings that have already ended
      final upcoming = events
          .where((e) => 
              e.endTime.isAfter(now) &&  // Meeting hasn't ended yet
              e.status != CalendarEventStatus.completed &&
              e.status != CalendarEventStatus.cancelled)
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      
      if (mounted) {
        setState(() {
          _upcomingMeetings = upcoming.take(3).toList(); // Show max 3
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading upcoming meetings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTimeUntilMeeting(DateTime meetingTime) {
    final now = DateTime.now();
    final difference = meetingTime.difference(now);
    
    if (difference.inMinutes < 0) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return 'in ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'in ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7) {
      return 'in ${difference.inDays} days';
    } else {
      return '${meetingTime.month}/${meetingTime.day}';
    }
  }

  bool _canJoinNow(DateTime meetingStartTime, DateTime meetingEndTime) {
    final now = DateTime.now();
    final difference = meetingStartTime.difference(now);
    final hasEnded = meetingEndTime.isBefore(now);
    
    // Can join 15 minutes before, but not if meeting has ended
    return difference.inMinutes <= 15 && difference.inMinutes >= -5 && !hasEnded;
  }

  Color _getStatusColor(CalendarEventStatus status) {
    switch (status) {
      case CalendarEventStatus.confirmed:
        return mediumSeaGreen;
      case CalendarEventStatus.scheduled:
        return Colors.orange;
      case CalendarEventStatus.cancelled:
        return Colors.red;
      case CalendarEventStatus.completed:
        return Colors.grey;
      case CalendarEventStatus.rescheduled:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              lightMint.withValues(alpha: 0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: mediumSeaGreen.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: mediumSeaGreen,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_upcomingMeetings.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              lightMint.withValues(alpha: 0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: mediumSeaGreen.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: mediumSeaGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Upcoming Interviews',
                  style: TextStyle(
                    color: darkTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightMint.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    color: mediumSeaGreen.withValues(alpha: 0.4),
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isEmployer
                        ? 'No upcoming interviews scheduled'
                        : 'No upcoming interviews yet',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isEmployer
                        ? 'Schedule interviews from your applications'
                        : 'Keep applying to land your dream job!',
                    style: TextStyle(
                      color: darkTeal.withValues(alpha: 0.4),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            lightMint.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: mediumSeaGreen.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mediumSeaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: mediumSeaGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Upcoming Interviews',
                    style: TextStyle(
                      color: darkTeal,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to calendar screen
                    Navigator.pushNamed(
                      context,
                      widget.isEmployer ? '/employer-calendar' : '/applicant-calendar',
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: mediumSeaGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Meeting cards
          ...List.generate(_upcomingMeetings.length, (index) {
            final meeting = _upcomingMeetings[index];
            final canJoin = _canJoinNow(meeting.startTime, meeting.endTime);
            final timeUntil = _getTimeUntilMeeting(meeting.startTime);
            
            return Column(
              children: [
                if (index > 0) 
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      color: mediumSeaGreen.withValues(alpha: 0.1),
                    ),
                  ),
                _buildMeetingCard(meeting, canJoin, timeUntil),
              ],
            );
          }),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMeetingCard(CalendarEvent meeting, bool canJoin, String timeUntil) {
    return InkWell(
      onTap: () {
        // Show event details
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => EventDetailSheet(
            event: meeting,
            isEmployer: widget.isEmployer,
            pageContext: this.context,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Time indicator
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: canJoin
                    ? mediumSeaGreen.withValues(alpha: 0.1)
                    : lightMint.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: canJoin
                      ? mediumSeaGreen.withValues(alpha: 0.3)
                      : mediumSeaGreen.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${meeting.startTime.hour > 12 ? meeting.startTime.hour - 12 : (meeting.startTime.hour == 0 ? 12 : meeting.startTime.hour)}:${meeting.startTime.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: canJoin ? mediumSeaGreen : darkTeal,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    meeting.startTime.hour >= 12 ? 'PM' : 'AM',
                    style: TextStyle(
                      color: canJoin
                          ? mediumSeaGreen.withValues(alpha: 0.7)
                          : darkTeal.withValues(alpha: 0.5),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Meeting info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    style: const TextStyle(
                      color: darkTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (meeting.description != null && meeting.description!.isNotEmpty)
                    Text(
                      meeting.description!,
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _getStatusColor(meeting.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeUntil,
                        style: TextStyle(
                          color: canJoin ? mediumSeaGreen : darkTeal.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: canJoin ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Action button
            if (canJoin && meeting.meetingLink != null && meeting.meetingLink!.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: mediumSeaGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: mediumSeaGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      // Join video call
                      final userId = _supabase.auth.currentUser?.id ?? '';
                      final userName = _supabase.auth.currentUser?.userMetadata?['fullName'] as String? ?? 'User';
                      
                      await VideoCallService.joinVideoCall(
                        callID: meeting.meetingLink!,
                        userID: userId,
                        userName: userName,
                        context: context,
                        isHost: widget.isEmployer,
                        eventId: meeting.id, // For attendance tracking
                        userRole: widget.isEmployer ? 'employer' : 'applicant', // For attendance tracking
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.videocam_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Join',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: darkTeal.withValues(alpha: 0.3),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

