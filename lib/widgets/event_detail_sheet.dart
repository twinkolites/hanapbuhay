import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/calendar_models.dart';
import '../services/video_call_service.dart';
import '../services/post_meeting_service.dart';
import '../services/attendance_tracking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_meeting_summary_sheet.dart';
import 'reschedule_request_sheet.dart';

class EventDetailSheet extends StatefulWidget {
  final CalendarEvent event;
  final bool isEmployer;
  final BuildContext? pageContext; // stable parent context (optional)
  
  const EventDetailSheet({
    super.key,
    required this.event,
    required this.isEmployer,
    this.pageContext,
  });

  @override
  State<EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends State<EventDetailSheet> {
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _attendance;
  // Flags kept for potential future loading indicators; suppress lints by using them in build
  bool _isLoadingSummary = true;
  bool _isLoadingAttendance = true;
  bool _isJoining = false;

  // static const Color lightMint = Color(0xFFEAF9E7); // not used here
  static const Color paleGreen = Color(0xFFC0E6BA);
  static const Color mediumSeaGreen = Color(0xFF4CA771);
  static const Color darkTeal = Color(0xFF013237);

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadAttendance();
  }

  @override
  void dispose() {
    // Best-effort cleanup: ensure we are not holding any previous ZEGO room session
    // This helps when users close the sheet and immediately try to re-enter a room
    VideoCallService.logoutRoomIfAny(roomID: widget.event.meetingLink);
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await PostMeetingService.getMeetingSummary(widget.event.id);
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      print('Error loading summary: $e');
      if (mounted) {
        setState(() => _isLoadingSummary = false);
      }
    }
  }
  
  Future<void> _loadAttendance() async {
    try {
      final attendance = await AttendanceTrackingService.getAttendanceRecord(widget.event.id);
      if (mounted) {
        setState(() {
          _attendance = attendance;
          _isLoadingAttendance = false;
        });
      }
    } catch (e) {
      print('Error loading attendance: $e');
      if (mounted) {
        setState(() => _isLoadingAttendance = false);
      }
    }
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
            if (_isLoadingSummary || _isLoadingAttendance) const SizedBox.shrink(),
            
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.event.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getEventIcon(widget.event.type),
                    color: widget.event.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.event.title,
                        style: const TextStyle(
                          color: darkTeal,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getStatusColor(widget.event.status.name),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.event.status.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
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
            
            // Date & Time
            _buildInfoRow(
              Icons.calendar_today_rounded,
              'Date & Time',
              '${_formatDate(widget.event.startTime)}\n${_formatTime(widget.event.startTime)} - ${_formatTime(widget.event.endTime)}',
            ),
            
            if (widget.event.description != null && widget.event.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                Icons.description_rounded,
                'Description',
                widget.event.description!,
              ),
            ],
            
            if (widget.event.location != null && widget.event.location!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                Icons.location_on_rounded,
                'Location',
                widget.event.location!,
              ),
            ],
            
            // Attendance Tracking Section
            if (_attendance != null && widget.isEmployer) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),
              _buildAttendanceSection(),
            ],
            
            // Meeting Summary Section
            if (widget.event.status == CalendarEventStatus.completed) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),
              
              // Show summary if exists, otherwise show waiting message for applicant
              if (_summary != null)
                _buildSummarySection()
              else if (!widget.isEmployer)
                _buildWaitingSummaryMessage(),
            ],
            
            // Video Call Link Section
            // Check if meeting has ended (past scheduled end time)
            // For applicants: Only show video call if meeting is NOT completed AND not ended
            // For employers: Show unless completed
            if (widget.event.meetingLink != null && 
                widget.event.meetingLink!.isNotEmpty &&
                (widget.isEmployer || widget.event.status != CalendarEventStatus.completed)) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: mediumSeaGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: mediumSeaGreen.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: mediumSeaGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.video_call_rounded,
                            color: mediumSeaGreen,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Video Call Link Available',
                          style: TextStyle(
                            color: mediumSeaGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Meeting Link Display
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: paleGreen.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.event.meetingLink!,
                              style: TextStyle(
                                color: darkTeal.withValues(alpha: 0.7),
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: widget.event.meetingLink!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Link copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: mediumSeaGreen,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: mediumSeaGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.copy_rounded,
                                color: mediumSeaGreen,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Meeting Room Info
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.meeting_room_rounded,
                            color: Colors.blue,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Interview Room',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Room stays open until you leave',
                                  style: TextStyle(
                                    color: darkTeal.withValues(alpha: 0.6),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Join Video Call Button (Teams/Discord Style)
                    // Check if meeting has ended or is completed
                    Builder(
                      builder: (context) {
                        final now = DateTime.now();
                        final hasEnded = widget.event.endTime.isBefore(now);
                        final isCompleted = widget.event.status == CalendarEventStatus.completed;
                        final isCancelled = widget.event.status == CalendarEventStatus.cancelled;
                        final isOngoing = widget.event.startTime.isBefore(now) && !hasEnded && !isCompleted;
                        final isUpcoming = widget.event.startTime.isAfter(now) && !isCompleted && !isCancelled;
                        
                        // If meeting has ended or is completed, show appropriate message
                        if ((hasEnded || isCompleted) && !widget.isEmployer) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event_busy_rounded,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isCompleted 
                                        ? 'This interview has been completed'
                                        : 'This interview has ended',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (hasEnded)
                                  Text(
                                    'Ended ${_getTimeAgo(widget.event.endTime)}',
                                    style: TextStyle(
                                      color: Colors.grey.withValues(alpha: 0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }
                        
                        // If cancelled, show cancelled message
                        if (isCancelled) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.cancel_rounded,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This interview has been cancelled',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Show join button (disabled for completed/ended meetings)
                        final canJoinBase = !isCompleted && !hasEnded && !isCancelled;
                        final canJoin = canJoinBase && !_isJoining;
                        
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: canJoin ? () async {
                              final currentUser = Supabase.instance.client.auth.currentUser;
                              if (currentUser != null) {
                                try {
                                  if (mounted) setState(() => _isJoining = true);
                                  // Show loading overlay using the page context if available
                                  final loaderContext = widget.pageContext ?? context;
                                  showDialog(
                                    context: loaderContext,
                                    barrierDismissible: false,
                                    builder: (_) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );

                                  // Proactively logout any previous room session
                                  await VideoCallService.logoutRoomIfAny(
                                    roomID: widget.event.meetingLink,
                                  );

                                  // Close details sheet before pushing the call screen
                                  Navigator.pop(context);

                                  await VideoCallService.joinVideoCall(
                                    callID: widget.event.meetingLink ?? 'interview-${widget.event.id}',
                                    userID: currentUser.id,
                                    userName: currentUser.userMetadata?['full_name'] ?? 'User',
                                    context: widget.pageContext ?? loaderContext,
                                    isHost: widget.isEmployer,
                                    eventId: widget.event.id,
                                    userRole: widget.isEmployer ? 'employer' : 'applicant',
                                  );

                                  // Dismiss loader after returning from call
                                  Navigator.of(loaderContext, rootNavigator: true).pop();
                                } catch (_) {
                                  // Ensure loader is dismissed on error
                                  final loaderContext = widget.pageContext ?? context;
                                  Navigator.of(loaderContext, rootNavigator: true).maybePop();
                                } finally {
                                  if (mounted) setState(() => _isJoining = false);
                                }
                              }
                            } : null, // Disabled if can't join
                            icon: Icon(
                              isOngoing ? Icons.video_call_rounded : Icons.videocam_outlined,
                              size: 18,
                            ),
                            label: _isJoining
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isOngoing 
                                        ? 'Join Ongoing Interview' 
                                        : isUpcoming 
                                            ? 'Enter Interview Room'
                                            : 'Interview Room',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: !canJoin
                                  ? Colors.grey 
                                  : isOngoing 
                                      ? const Color(0xFF2E7D32) // Darker green for ongoing
                                      : mediumSeaGreen,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade400,
                              disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: isOngoing ? 4 : 0,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Info text
                    Text(
                      '💡 ${widget.isEmployer ? 'You\'ll be the host' : 'Wait for host to let you in'}',
                      style: TextStyle(
                        color: darkTeal.withValues(alpha: 0.6),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Action Buttons
            Column(
              children: [
                // Reschedule button for no-show meetings
                if (_shouldShowRescheduleButton()) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRescheduleRequest(),
                      icon: const Icon(Icons.schedule_rounded, size: 16),
                      label: const Text(
                        'Request Reschedule',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Main action buttons
                Row(
                  children: [
                    if (widget.isEmployer && widget.event.status != CalendarEventStatus.completed) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            // Show post-meeting summary sheet
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => PostMeetingSummarySheet(
                                event: widget.event,
                                applicationId: widget.event.jobId, // Pass if this is an interview
                              ),
                            ).then((saved) {
                              if (saved == true) {
                                // Reload summary after saving
                                _loadSummary();
                              }
                            });
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text(
                            'Complete Meeting',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mediumSeaGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text(
                          'Close',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: darkTeal.withValues(alpha: 0.7),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: BorderSide(
                            color: darkTeal.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
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

  IconData _getEventIcon(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.meeting:
        return Icons.people_rounded;
      case CalendarEventType.interview:
        return Icons.work_rounded;
      case CalendarEventType.availability:
        return Icons.event_available_rounded;
      case CalendarEventType.reminder:
        return Icons.notifications_rounded;
      case CalendarEventType.blocked:
        return Icons.block_rounded;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    
    return '${weekdays[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
  
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return 'on ${_formatDate(dateTime)}';
    }
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.summarize_rounded,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Meeting Summary',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_summary?['rating'] != null) ...[
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < (_summary!['rating'] as int)
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          if (_summary?['notes'] != null) ...[
            const SizedBox(height: 12),
            Text(
              'Notes:',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _summary!['notes'] as String,
              style: const TextStyle(
                color: darkTeal,
                fontSize: 11,
              ),
            ),
          ],
          
          if (_summary?['decision'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _getDecisionColor(_summary!['decision'] as String),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Decision: ${_getDecisionLabel(_summary!['decision'] as String)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          
          if (_summary?['action_items'] != null &&
              (_summary!['action_items'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Action Items:',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...(_summary!['action_items'] as List).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: mediumSeaGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item as String,
                        style: const TextStyle(
                          color: darkTeal,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          
          if (_summary?['next_steps'] != null) ...[
            const SizedBox(height: 12),
            Text(
              'Next Steps:',
              style: TextStyle(
                color: darkTeal.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _summary!['next_steps'] as String,
              style: const TextStyle(
                color: darkTeal,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getDecisionColor(String decision) {
    switch (decision) {
      case 'proceed':
        return Colors.green;
      case 'hired':
        return mediumSeaGreen;
      case 'on_hold':
        return Colors.orange;
      case 'reject':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getDecisionLabel(String decision) {
    switch (decision) {
      case 'proceed':
        return 'Next Interview';
      case 'hired':
        return 'Hired';
      case 'on_hold':
        return 'Needs Review';
      case 'reject':
        return 'Rejected';
      case 'pending':
        return 'Pending Review';
      case 'needs_review':
        return 'Needs Review';
      default:
        return decision.toUpperCase();
    }
  }

  Widget _buildWaitingSummaryMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty_rounded,
              color: Colors.blue,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Interview Completed',
            style: TextStyle(
              color: darkTeal,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The employer is preparing the interview summary.\nYou will be notified once it\'s ready.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkTeal.withValues(alpha: 0.6),
              fontSize: 10,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.blue,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Text(
                  'We\'ll notify you',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAttendanceSection() {
    if (_attendance == null) return const SizedBox.shrink();
    
    final status = _attendance!['attendance_status'] as String? ?? 'scheduled';
    final isNoShow = _attendance!['is_no_show'] as bool? ?? false;
    final isLate = _attendance!['is_late'] as bool? ?? false;
    final minutesLate = _attendance!['minutes_late'] as int? ?? 0;
    final applicantJoinedAt = _attendance!['applicant_joined_at'] as String?;
    final applicantDuration = _attendance!['applicant_duration_minutes'] as int? ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AttendanceTrackingService.getAttendanceColor(status).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AttendanceTrackingService.getAttendanceColor(status).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AttendanceTrackingService.getAttendanceColor(status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isNoShow ? Icons.person_off_rounded : Icons.how_to_reg_rounded,
                  color: AttendanceTrackingService.getAttendanceColor(status),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Attendance Tracking',
                  style: TextStyle(
                    color: AttendanceTrackingService.getAttendanceColor(status),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AttendanceTrackingService.getAttendanceColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AttendanceTrackingService.getAttendanceSummary(_attendance!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          if (isNoShow) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Applicant did not attend the interview',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          if (isLate && minutesLate > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: Colors.orange,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Arrived $minutesLate ${minutesLate == 1 ? 'minute' : 'minutes'} late',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          
          if (applicantJoinedAt != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.login_rounded,
                  color: mediumSeaGreen,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Joined at ${_formatTime(DateTime.parse(applicantJoinedAt).toLocal())}',
                  style: const TextStyle(
                    color: mediumSeaGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          
          if (applicantDuration > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer_rounded,
                  color: darkTeal.withValues(alpha: 0.7),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Interview duration: $applicantDuration ${applicantDuration == 1 ? 'minute' : 'minutes'}',
                  style: TextStyle(
                    color: darkTeal.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  /// Check if reschedule button should be shown
  bool _shouldShowRescheduleButton() {
    final now = DateTime.now();
    final hasEnded = widget.event.endTime.isBefore(now);
    final isCompleted = widget.event.status == CalendarEventStatus.completed;
    
    // Show for completed meetings that ended in the last 7 days
    if (!isCompleted || !hasEnded) return false;
    
    final endedRecently = widget.event.endTime.isAfter(
      now.subtract(const Duration(days: 7))
    );
    
    if (!endedRecently) return false;
    
    // Check if there's attendance data showing no-show
    if (_attendance != null) {
      final isNoShow = _attendance!['is_no_show'] as bool? ?? false;
      final hasAttendance = _attendance!['applicant_joined_at'] != null;
      return isNoShow || !hasAttendance;
    }
    
    return true; // Show by default for completed meetings
  }
  
  /// Show reschedule request sheet
  void _showRescheduleRequest() {
    Navigator.pop(context); // Close current sheet first
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RescheduleRequestSheet(
        eventId: widget.event.id,
        eventTitle: widget.event.title,
        originalStartTime: widget.event.startTime,
        originalEndTime: widget.event.endTime,
      ),
    ).then((success) {
      if (success == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reschedule request submitted successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }
}

