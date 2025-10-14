import 'package:flutter/material.dart';
import '../services/onesignal_notification_service.dart';
import '../main.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;
  Set<String> _selectedNotifications = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      // Get notifications from database
      final notifications = await OneSignalNotificationService.getUserNotifications(user.id);
      // Ensure descending order by created_at (newest first)
      notifications.sort((a, b) {
        final ad = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      
      // Get unread count
      final unreadCount = await OneSignalNotificationService.getUnreadCount(user.id);

      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await OneSignalNotificationService.markAsRead(notificationId);
      _loadNotifications(); // Refresh the list
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await OneSignalNotificationService.markAllAsRead(user.id);
      _loadNotifications(); // Refresh the list
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      
      _loadNotifications(); // Refresh the list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: Color(0xFF4CA771),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete notification'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedNotifications() async {
    if (_selectedNotifications.isEmpty) return;

    try {
      await supabase
          .from('notifications')
          .delete()
          .inFilter('id', _selectedNotifications.toList());
      
      _selectedNotifications.clear();
      _isSelectionMode = false;
      _loadNotifications(); // Refresh the list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedNotifications.length} notifications deleted'),
            backgroundColor: const Color(0xFF4CA771),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting selected notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete notifications'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _toggleSelection(String notificationId) {
    setState(() {
      if (_selectedNotifications.contains(notificationId)) {
        _selectedNotifications.remove(notificationId);
      } else {
        _selectedNotifications.add(notificationId);
      }
      
      if (_selectedNotifications.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedNotifications.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedNotifications.clear();
    });
  }

  String _getNotificationIcon(String type) {
    switch (type) {
      case 'application_status':
        return '📋';
      case 'meeting_reminder':
      case 'meeting_scheduled':
        return '📅';
      case 'ai_screening_completed':
        return '🤖';
      case 'chat_message':
        return '💬';
      case 'job_match':
      case 'job_recommendation':
        return '💼';
      case 'system_announcement':
        return '📢';
      default:
        return '🔔';
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'application_status':
      case 'ai_screening_completed':
        return const Color(0xFF4CA771);
      case 'meeting_reminder':
      case 'meeting_scheduled':
        return const Color(0xFF2196F3);
      case 'chat_message':
        return const Color(0xFFFF9800);
      case 'job_match':
      case 'job_recommendation':
        return const Color(0xFF9C27B0);
      case 'system_announcement':
        return const Color(0xFF607D8B);
      default:
        return const Color(0xFF4CA771);
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _generateTitleFromPayload(String type, Map<String, dynamic> payload) {
    switch (type) {
      case 'ai_screening_complete':
        return 'AI Screening Completed';
      case 'new_application':
        return 'New Application Received';
      case 'application_status_update':
        return 'Application Status Updated';
      case 'meeting_reminder':
        return 'Meeting Reminder';
      case 'meeting_scheduled':
        return 'Meeting Scheduled';
      case 'chat_message':
        return 'New Message';
      case 'job_match':
        return 'Job Match Found';
      case 'system_announcement':
        return 'System Announcement';
      case 'application_withdrawn':
        return 'Application Withdrawn';
      case 'application_withdrawal_confirmed':
        return 'Application Withdrawal Confirmed';
      case 'job_saved':
        return 'Job Saved';
      case 'job_unsaved':
        return 'Job Removed from Saved';
      case 'profile_updated':
        return 'Profile Updated';
      case 'meeting_reschedule_request':
        return 'Meeting Reschedule Request';
      case 'reschedule_request_sent':
        return 'Reschedule Request Sent';
      case 'video_call_joined':
        return 'Video Call Joined';
      case 'meeting_no_show':
        return 'Meeting No-Show';
      case 'application_deadline_reminder':
        return 'Application Deadline Reminder';
      case 'reschedule_request_approved':
        return 'Reschedule Approved';
      case 'reschedule_request_rejected':
        return 'Reschedule Rejected';
default:
        return 'Notification';
    }
  }

  String _generateMessageFromPayload(String type, Map<String, dynamic> payload) {
    switch (type) {
      case 'ai_screening_complete':
        final score = payload['score']?.toString() ?? 'N/A';
        final jobTitle = payload['job_title'] ?? 'the job';
        final applicantName = payload['applicant_name'] ?? 'an applicant';
        return 'AI analysis completed for $applicantName\'s application to $jobTitle (Score: $score/10)';
      
      case 'new_application':
        final jobTitle = payload['job_title'] ?? 'a job';
        final applicantName = payload['applicant_name'] ?? 'an applicant';
        return '$applicantName applied for $jobTitle';
      
      case 'application_status_update':
        final message = payload['message'] ?? 'Application status has been updated';
        return message;
      
      case 'meeting_reminder':
        final jobTitle = payload['job_title'] ?? 'a meeting';
        return 'Reminder: You have a meeting for $jobTitle';
      
      case 'meeting_scheduled':
        final jobTitle = payload['job_title'] ?? 'a meeting';
        return 'A meeting has been scheduled for $jobTitle';
      
      case 'chat_message':
        final senderName = payload['sender_name'] ?? 'Someone';
        final messagePreview = payload['message_preview'] ?? 'sent you a message';
        return '$senderName $messagePreview';
      
      case 'job_match':
        final jobTitle = payload['job_title'] ?? 'a job';
        final companyName = payload['company_name'] ?? 'a company';
        final matchScore = payload['match_score']?.toString() ?? '0';
        return 'Found a $jobTitle position at $companyName (${(double.tryParse(matchScore) ?? 0 * 100).toInt()}% match)';
      
      case 'system_announcement':
        return payload['message'] ?? 'System announcement';
      
      case 'application_withdrawn':
        final jobTitle = payload['job_title'] ?? 'a job';
        final applicantName = payload['applicant_name'] ?? 'an applicant';
        return '$applicantName has withdrawn their application for $jobTitle';
      
      case 'application_withdrawal_confirmed':
        final jobTitle = payload['job_title'] ?? 'a job';
        return 'Your application for $jobTitle has been withdrawn';
      
      case 'job_saved':
        final jobTitle = payload['job_title'] ?? 'a job';
        final applicantName = payload['applicant_name'] ?? 'an applicant';
        return '$applicantName saved your job posting: $jobTitle';
      
      case 'job_unsaved':
        final jobTitle = payload['job_title'] ?? 'a job';
        final applicantName = payload['applicant_name'] ?? 'an applicant';
        return '$applicantName removed $jobTitle from their saved jobs';
      
      case 'profile_updated':
        final completeness = payload['profile_completeness']?.toString() ?? '0';
        return 'Your profile has been updated ($completeness% complete)';
      
      case 'meeting_reschedule_request':
        final meetingTitle = payload['meeting_title'] ?? 'a meeting';
        final applicantName = payload['applicant_name'] ?? 'an applicant';
        return '$applicantName has requested to reschedule "$meetingTitle"';
      
      case 'reschedule_request_sent':
        final meetingTitle = payload['meeting_title'] ?? 'a meeting';
        return 'Your reschedule request for "$meetingTitle" has been sent to the employer';
      
      case 'video_call_joined':
        final jobTitle = payload['job_title'] ?? 'a job';
        final applicantName = payload['applicant_name'] ?? 'an applicant';
        return '$applicantName has joined the interview for $jobTitle';
      
      case 'meeting_no_show':
        final jobTitle = payload['job_title'] ?? 'a job';
        final applicantName = payload['applicant_name'] ?? 'an applicant';
        return '$applicantName did not attend the interview for $jobTitle';
      
      case 'application_deadline_reminder':
        final jobTitle = payload['job_title'] ?? 'a job';
        final companyName = payload['company_name'] ?? 'a company';
        final daysRemaining = payload['days_remaining']?.toString() ?? '0';
        if (daysRemaining == '0') {
          return 'The application deadline for $jobTitle at $companyName is today!';
        } else if (daysRemaining == '1') {
          return 'The application deadline for $jobTitle at $companyName is tomorrow';
        } else {
          return 'The application deadline for $jobTitle at $companyName is in $daysRemaining days';
        }
      
      case 'reschedule_request_approved':
        final meetingTitle = payload['meeting_title'] ?? 'a meeting';
        return 'Your meeting "$meetingTitle" was rescheduled';
      
      case 'reschedule_request_rejected':
        final meetingTitle = payload['meeting_title'] ?? 'a meeting';
        return 'Your reschedule request for "$meetingTitle" was rejected';
      
      default:
        return payload['message'] ?? 'You have a new notification';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF9E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CA771),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isSelectionMode 
            ? '${_selectedNotifications.length} selected'
            : 'Notifications',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
            )
          : null,
        actions: _isSelectionMode
          ? [
              if (_selectedNotifications.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelectedNotifications,
                ),
            ]
          : [
              if (_unreadCount > 0)
                TextButton(
                  onPressed: _markAllAsRead,
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.checklist),
                onPressed: _enterSelectionMode,
                tooltip: 'Select notifications',
              ),
            ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4CA771),
              ),
            )
          : _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF4CA771).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.notifications_none,
              size: 60,
              color: Color(0xFF4CA771),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF013237),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see important updates here',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF013237).withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: const Color(0xFF4CA771),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          final isRead = notification['is_read'] == true;
          final createdAt = DateTime.parse(notification['created_at']);
          final type = notification['type'] ?? '';
          final payload = notification['payload'] as Map<String, dynamic>? ?? {};
          
          // Generate title and message from payload if not set
          final title = notification['title'] ?? _generateTitleFromPayload(type, payload);
          final message = notification['message'] ?? _generateMessageFromPayload(type, payload);
          final notificationId = notification['id'];
          final isSelected = _selectedNotifications.contains(notificationId);

          return Dismissible(
            key: Key(notificationId),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
                size: 24,
              ),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Notification'),
                  content: const Text('Are you sure you want to delete this notification?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ) ?? false;
            },
            onDismissed: (direction) {
              _deleteNotification(notificationId);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF013237).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isRead 
                    ? null 
                    : Border.all(
                        color: const Color(0xFF4CA771).withValues(alpha: 0.3),
                        width: 1,
                      ),
              ),
            child: InkWell(
              onTap: _isSelectionMode 
                ? () => _toggleSelection(notificationId)
                : () => _markAsRead(notificationId),
              onLongPress: () {
                if (!_isSelectionMode) {
                  _enterSelectionMode();
                  _toggleSelection(notificationId);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selection checkbox
                    if (_isSelectionMode)
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (value) => _toggleSelection(notificationId),
                          activeColor: const Color(0xFF4CA771),
                        ),
                      ),
                    // Notification icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getNotificationColor(type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          _getNotificationIcon(type),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Notification content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                    color: const Color(0xFF013237),
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CA771),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF013237).withValues(alpha: 0.7),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatTimeAgo(createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: const Color(0xFF013237).withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}
