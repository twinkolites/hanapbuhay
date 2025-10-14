import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'dart:convert';

/// OneSignal Notification Service
/// 
/// Comprehensive notification service using OneSignal for push notifications
/// Handles device registration, sending notifications, and managing notification states
class OneSignalNotificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static bool _isInitialized = false;

  /// Initialize OneSignal SDK
  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🔔 OneSignal already initialized');
      return;
    }

    try {
      debugPrint('🔔 Initializing OneSignal...');
      
      // Initialize OneSignal with App ID
      final appId = dotenv.env['ONESIGNAL_APP_ID'] ?? 'f0656c3b-0519-4c3c-b017-de041455d61c';
      OneSignal.initialize(appId);
      
      // Request permission for notifications
      final permission = await OneSignal.Notifications.requestPermission(true);
      debugPrint('🔔 Notification permission granted: $permission');
      
      // Set up notification received handler (foreground)
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        debugPrint('🔔 Notification received in foreground: ${event.notification.title}');
        _handleNotificationReceived(event.notification);
        // Display the notification
        // Complete the notification display
        // Note: In OneSignal 5.3.4, the event handling is automatic
      });
      
      // Set up notification opened handler
      OneSignal.Notifications.addClickListener((event) {
        debugPrint('🔔 Notification clicked: ${event.notification.title}');
        _handleNotificationOpened(event);
      });
      
      _isInitialized = true;
      debugPrint('✅ OneSignal initialized successfully');
      
    } catch (e) {
      debugPrint('❌ Error initializing OneSignal: $e');
    }
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    try {
      final permission = await OneSignal.Notifications.requestPermission(true);
      debugPrint('🔔 Notification permission: $permission');
      return permission;
    } catch (e) {
      debugPrint('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Subscribe user and register device
  static Future<void> subscribeUser(String userId) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      // Login user to OneSignal (replaces externalId approach)
      await OneSignal.login(userId);

      // Get OneSignal player ID with retry (registration can be async)
      String? playerId;
      const int maxAttempts = 20; // ~10s total
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        playerId = await OneSignal.User.getOnesignalId();
        if (playerId != null && playerId.isNotEmpty) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (playerId != null && playerId.isNotEmpty) {
        debugPrint('🔔 OneSignal Player ID: $playerId');
        await _registerDevice(userId, playerId);
      } else {
        debugPrint('⚠️ OneSignal Player ID not available after retry');
      }
      
      debugPrint('✅ User subscribed to OneSignal: $userId');
      
    } catch (e) {
      debugPrint('❌ Error subscribing user to OneSignal: $e');
    }
  }

  /// Register device in database
  static Future<void> _registerDevice(String userId, String playerId) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      // Use playerId as push_token fallback to satisfy NOT NULL constraint
      // If you later surface the raw FCM/APNs token, replace this value
      final String pushToken = playerId;
      
      // Check if device already exists
      final existingDevice = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', userId)
          .eq('onesignal_player_id', playerId)
          .maybeSingle();
      
      if (existingDevice != null) {
        // Update existing device
        await _supabase
            .from('user_devices')
            .update({
              'updated_at': DateTime.now().toIso8601String(),
              'is_subscribed': true,
              'push_token': pushToken,
            })
            .eq('id', existingDevice['id']);
        
        debugPrint('✅ Device updated in database');
      } else {
        // Insert new device
        await _supabase
            .from('user_devices')
            .insert({
              'user_id': userId,
              'onesignal_player_id': playerId,
              'platform': platform,
              'is_subscribed': true,
              'push_token': pushToken,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
        
        debugPrint('✅ Device registered in database');
      }
      
    } catch (e) {
      debugPrint('❌ Error registering device: $e');
    }
  }

  /// Get OneSignal player ID
  static Future<String?> getPlayerId() async {
    try {
      return await OneSignal.User.getOnesignalId();
    } catch (e) {
      debugPrint('❌ Error getting OneSignal player ID: $e');
      return null;
    }
  }

  /// Send notification to specific user
  static Future<bool> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? payload,
    String? imageUrl,
    String? actionUrl,
    String priority = 'normal',
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Create notification in database first (via RPC to bypass client RLS write issues)
      final notificationId = await _supabase.rpc('insert_notification_for_user', params: {
        'p_user_id': userId,
        'p_title': title,
        'p_message': message,
        'p_type': type,
        'p_payload': payload ?? {},
        'p_image_url': imageUrl,
        'p_action_url': actionUrl,
        'p_priority': priority,
        'p_onesignal_id': null,
        'p_status': 'pending',
      }) as String;

      // Send via OneSignal REST API so it delivers when app is terminated
      final appId = dotenv.env['ONESIGNAL_APP_ID'];
      final restKey = dotenv.env['ONESIGNAL_REST_API_KEY'];

      if (appId == null || appId.isEmpty || restKey == null || restKey.isEmpty) {
        debugPrint('⚠️ OneSignal REST not configured. Skipping push delivery.');
        // Keep DB record as pending to avoid false sent state
        return true; // Do not fail app flow
      }

      final androidChannelId = dotenv.env['ONESIGNAL_ANDROID_CHANNEL_ID'];

      // Fallback targeting: fetch any registered OneSignal player IDs for this user
      // This helps when external_id isn't yet attached (e.g., identity verification enabled or login not completed)
      List<String> playerIds = [];
      try {
        final deviceRows = await _supabase
            .from('user_devices')
            .select('onesignal_player_id')
            .eq('user_id', userId)
            .eq('is_subscribed', true);
        playerIds = List<Map<String, dynamic>>.from(deviceRows)
            .map((r) => (r['onesignal_player_id'] as String?))
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
      } catch (_) {}

      final requestBody = {
        'app_id': appId,
        // Target user by external_id (we call OneSignal.login(userId))
        'include_aliases': {
          'external_id': [userId]
        },
        // When targeting by alias, OneSignal requires target_channel
        'target_channel': 'push',
        // Fallback direct device targeting when alias is missing/not ready
        if (playerIds.isNotEmpty) 'include_player_ids': playerIds,
        'headings': {'en': title},
        'contents': {'en': message},
        'data': {
          'type': type,
          'action_url': actionUrl,
          'notification_id': notificationId,
          ...?payload,
        },
        if (androidChannelId != null && androidChannelId.isNotEmpty)
          'android_channel_id': androidChannelId,
        // iOS badge increment and background delivery metadata
        'ios_badgeType': 'Increase',
        'ios_badgeCount': 1,
        // Priority hints
        'priority': priority == 'urgent' || priority == 'high' ? 10 : 5,
      };

      try {
        final client = HttpClient();
        final req = await client.postUrl(Uri.parse('https://onesignal.com/api/v1/notifications'));
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
        req.headers.set(HttpHeaders.authorizationHeader, 'Basic $restKey');
        final bodyStr = json.encode(requestBody);
        req.add(utf8.encode(bodyStr));

        final res = await req.close();
        final resBody = await res.transform(utf8.decoder).join();
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = json.decode(resBody) as Map<String, dynamic>;
          final onesignalId = decoded['id']?.toString();
          await _updateNotificationStatus(
            notificationId,
            onesignalId: onesignalId,
            status: 'sent',
          );
          debugPrint('✅ OneSignal REST sent: $onesignalId');
          return true;
        } else {
          debugPrint('❌ OneSignal REST error ${res.statusCode}: $resBody');
          await _updateNotificationStatus(notificationId, status: 'failed');
          return false;
        }
      } catch (e) {
        debugPrint('❌ OneSignal REST exception: $e');
        await _updateNotificationStatus(notificationId, status: 'failed');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
      return false;
    }
  }

  // ===========================================
  // APPLICANT-SPECIFIC NOTIFICATION METHODS
  // ===========================================

  /// Send notification when applicant applies for a job
  static Future<bool> sendApplicationSubmittedNotification({
    required String applicantId,
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String applicantName,
    required String applicationId,
  }) async {
    try {
      // Notify employer about new application
      await sendNotification(
        userId: employerId,
        title: 'New Application Received',
        message: '$applicantName applied for $jobTitle',
        type: 'new_application',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'applicant_name': applicantName,
          'application_id': applicationId,
          'applicant_id': applicantId,
        },
        actionUrl: '/applications/$applicationId',
        priority: 'high',
      );

      // Notify applicant about successful application
      await sendNotification(
        userId: applicantId,
        title: 'Application Submitted Successfully',
        message: 'Your application for $jobTitle has been submitted and is under review',
        type: 'application_submitted',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'application_id': applicationId,
          'status': 'applied',
        },
        actionUrl: '/applications/$applicationId',
        priority: 'normal',
      );

      debugPrint('✅ Application notifications sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending application notifications: $e');
      return false;
    }
  }

  /// Send notification when AI screening is completed
  static Future<bool> sendAIScreeningCompletedNotification({
    required String applicantId,
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String applicantName,
    required double score,
    required String recommendation,
    required String applicationId,
  }) async {
    try {
      // Notify employer about AI screening completion
      await sendNotification(
        userId: employerId,
        title: 'AI Screening Completed',
        message: 'AI analysis completed for $applicantName\'s application to $jobTitle (Score: ${score.toStringAsFixed(1)}/10)',
        type: 'ai_screening_complete',
        payload: {
          'score': score,
          'job_title': jobTitle,
          'applicant_name': applicantName,
          'recommendation': recommendation,
          'application_id': applicationId,
          'job_id': jobId,
        },
        actionUrl: '/applications/$applicationId',
        priority: 'high',
      );

      // Notify applicant about AI screening completion
      await sendNotification(
        userId: applicantId,
        title: 'Application Under Review',
        message: 'Your application for $jobTitle has been analyzed and is being reviewed by the employer',
        type: 'ai_screening_complete',
        payload: {
          'score': score,
          'job_title': jobTitle,
          'recommendation': recommendation,
          'application_id': applicationId,
          'job_id': jobId,
        },
        actionUrl: '/applications/$applicationId',
        priority: 'normal',
      );

      debugPrint('✅ AI screening notifications sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending AI screening notifications: $e');
      return false;
    }
  }

  /// Send notification when application status is updated
  static Future<bool> sendApplicationStatusUpdateNotification({
    required String applicantId,
    required String jobId,
    required String jobTitle,
    required String oldStatus,
    required String newStatus,
    required String applicationId,
    String? message,
    DateTime? interviewDate,
  }) async {
    try {
      String title;
      String notificationMessage;
      String priority = 'high';

      switch (newStatus) {
        case 'shortlisted':
          title = 'Application Shortlisted!';
          notificationMessage = message ?? 'Congratulations! Your application for $jobTitle has been shortlisted';
          break;
        case 'interview':
          title = 'Interview Scheduled';
          notificationMessage = message ?? 'You have been selected for an interview for $jobTitle';
          break;
        case 'hired':
          title = 'Congratulations! You\'re Hired!';
          notificationMessage = message ?? 'Great news! You have been selected for $jobTitle';
          priority = 'urgent';
          break;
        case 'rejected':
          title = 'Application Update';
          notificationMessage = message ?? 'Thank you for your interest in $jobTitle. Unfortunately, we have decided to move forward with other candidates';
          break;
        default:
          title = 'Application Status Updated';
          notificationMessage = message ?? 'Your application status for $jobTitle has been updated to ${newStatus.replaceAll('_', ' ')}';
      }

      await sendNotification(
        userId: applicantId,
        title: title,
        message: notificationMessage,
        type: 'application_status_update',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'old_status': oldStatus,
          'new_status': newStatus,
          'application_id': applicationId,
          'interview_date': interviewDate?.toIso8601String(),
        },
        actionUrl: '/applications/$applicationId',
        priority: priority,
      );

      debugPrint('✅ Application status update notification sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending application status update notification: $e');
      return false;
    }
  }

  /// Send notification when meeting is scheduled
  static Future<bool> sendMeetingScheduledNotification({
    required String applicantId,
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String meetingTitle,
    required DateTime startTime,
    required DateTime endTime,
    required String meetingLink,
    required String eventId,
  }) async {
    try {
      final formattedTime = _formatDateTime(startTime);
      
      // Notify applicant about scheduled meeting
      await sendNotification(
        userId: applicantId,
        title: 'Meeting Scheduled',
        message: '$meetingTitle has been scheduled for $formattedTime',
        type: 'meeting_scheduled',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'meeting_link': meetingLink,
          'event_id': eventId,
        },
        actionUrl: '/calendar/$eventId',
        priority: 'high',
      );

      // Notify employer about meeting creation
      await sendNotification(
        userId: employerId,
        title: 'Meeting Created',
        message: 'Meeting "$meetingTitle" has been scheduled for $formattedTime',
        type: 'meeting_created',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'meeting_link': meetingLink,
          'event_id': eventId,
        },
        actionUrl: '/calendar/$eventId',
        priority: 'normal',
      );

      debugPrint('✅ Meeting scheduled notifications sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending meeting scheduled notifications: $e');
      return false;
    }
  }

  /// Send notification when meeting request is made
  static Future<bool> sendMeetingRequestNotification({
    required String applicantId,
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String applicantName,
    required DateTime requestedTime,
    required String message,
    required String requestId,
  }) async {
    try {
      final formattedTime = _formatDateTime(requestedTime);
      
      // Notify employer about meeting request
      await sendNotification(
        userId: employerId,
        title: 'New Meeting Request',
        message: '$applicantName has requested a meeting for $formattedTime',
        type: 'meeting_request',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'applicant_name': applicantName,
          'applicant_id': applicantId,
          'requested_time': requestedTime.toIso8601String(),
          'message': message,
          'request_id': requestId,
        },
        actionUrl: '/meeting-requests/$requestId',
        priority: 'normal',
      );

      // Notify applicant about request submission
      await sendNotification(
        userId: applicantId,
        title: 'Meeting Request Sent',
        message: 'Your meeting request for $jobTitle has been sent to the employer',
        type: 'meeting_request_sent',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'requested_time': requestedTime.toIso8601String(),
          'request_id': requestId,
        },
        actionUrl: '/meeting-requests/$requestId',
        priority: 'normal',
      );

      debugPrint('✅ Meeting request notifications sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending meeting request notifications: $e');
      return false;
    }
  }

  /// Send notification when chat message is received
  static Future<bool> sendChatMessageNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String messagePreview,
    required String chatId,
    required String jobTitle,
  }) async {
    try {
      await sendNotification(
        userId: recipientId,
        title: 'New Message from $senderName',
        message: messagePreview,
        type: 'chat_message',
        payload: {
          'sender_id': senderId,
          'sender_name': senderName,
          'message_preview': messagePreview,
          'chat_id': chatId,
          'job_title': jobTitle,
        },
        actionUrl: '/chat/$chatId',
        priority: 'normal',
      );

      debugPrint('✅ Chat message notification sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending chat message notification: $e');
      return false;
    }
  }

  /// Send notification for job recommendations
  static Future<bool> sendJobRecommendationNotification({
    required String applicantId,
    required String jobId,
    required String jobTitle,
    required String companyName,
    required double matchScore,
  }) async {
    try {
      final matchPercentage = (matchScore * 100).toInt();
      
      await sendNotification(
        userId: applicantId,
        title: 'New Job Match Found',
        message: 'Found a $jobTitle position at $companyName (${matchPercentage}% match)',
        type: 'job_match',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'company_name': companyName,
          'match_score': matchScore,
          'match_percentage': matchPercentage,
        },
        actionUrl: '/jobs/$jobId',
        priority: 'normal',
      );

      debugPrint('✅ Job recommendation notification sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending job recommendation notification: $e');
      return false;
    }
  }

  /// Send a notification to all admins
  static Future<bool> sendAdminNotification({
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? payload,
    String? actionUrl,
    String priority = 'high',
  }) async {
    try {
      // Fetch all admin user IDs
      final admins = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin');
      final adminIds = List<Map<String, dynamic>>.from(admins)
          .map((r) => r['id'] as String?)
          .whereType<String>()
          .toList();

      if (adminIds.isEmpty) {
        debugPrint('⚠️ No admin users found to notify');
        return false;
      }

      return await sendBulkNotifications(
        userIds: adminIds,
        title: title,
        message: message,
        type: type,
        payload: payload,
        actionUrl: actionUrl,
        priority: priority,
      );
    } catch (e) {
      debugPrint('❌ Error sending admin notification: $e');
      return false;
    }
  }

  /// Convenience: notify admins when an employer submits verification
  static Future<bool> notifyAdminsEmployerVerificationSubmitted({
    required String verificationId,
    required String employerId,
    String? employerName,
    String? companyId,
    String? companyName,
  }) async {
    final title = 'New Employer Verification Submitted';
    final message = employerName != null && companyName != null
        ? '$employerName submitted verification for $companyName'
        : 'An employer submitted a new verification request';
    return sendAdminNotification(
      title: title,
      message: message,
      type: 'employer_verification_submitted',
      payload: {
        'verification_id': verificationId,
        'employer_id': employerId,
        if (employerName != null) 'employer_name': employerName,
        if (companyId != null) 'company_id': companyId,
        if (companyName != null) 'company_name': companyName,
      },
      actionUrl: '/admin/employer-approvals/$verificationId',
      priority: 'high',
    );
  }

  /// Convenience: notify admins when a new user registers (optional)
  static Future<bool> notifyAdminsNewUserRegistered({
    required String userId,
    String? fullName,
    String role = 'applicant',
  }) async {
    final title = 'New User Registered';
    final message = fullName != null
        ? '$fullName registered as $role'
        : 'A new $role has registered';
    return sendAdminNotification(
      title: title,
      message: message,
      type: 'user_registered',
      payload: {
        'user_id': userId,
        'role': role,
        if (fullName != null) 'full_name': fullName,
      },
      actionUrl: '/admin/users?filter=new',
      priority: 'normal',
    );
  }

  /// Notify an employer about their verification status change
  static Future<bool> sendEmployerVerificationStatusNotification({
    required String employerId,
    required String status, // approved | rejected | under_review
    String? reason,
    String? notes,
  }) async {
    try {
      String title;
      String message;
      String priority = 'high';

      switch (status) {
        case 'approved':
          title = 'Employer Verification Approved';
          message = 'Your company has been approved. You can now post jobs.';
          priority = 'urgent';
          break;
        case 'rejected':
          title = 'Employer Verification Rejected';
          message = reason != null && reason.trim().isNotEmpty
              ? 'Your verification was rejected. Reason: $reason'
              : 'Your verification was rejected.';
          break;
        case 'under_review':
        default:
          title = 'Verification Needs More Information';
          message = notes != null && notes.trim().isNotEmpty
              ? 'Please provide the requested information: $notes'
              : 'Your verification requires additional information.';
          break;
      }

      return await sendNotification(
        userId: employerId,
        title: title,
        message: message,
        type: 'employer_verification_status',
        payload: {
          'status': status,
          if (reason != null) 'reason': reason,
          if (notes != null) 'notes': notes,
        },
        actionUrl: '/employer/home',
        priority: priority,
      );
    } catch (e) {
      debugPrint('❌ Error sending employer verification status notification: $e');
      return false;
    }
  }

  /// Send meeting reminder notification
  static Future<bool> sendMeetingReminderNotification({
    required String userId,
    required String jobId,
    required String jobTitle,
    required String meetingTitle,
    required DateTime startTime,
    required String meetingLink,
    required String eventId,
    int reminderMinutes = 15,
  }) async {
    try {
      final formattedTime = _formatDateTime(startTime);
      
      await sendNotification(
        userId: userId,
        title: 'Meeting Reminder',
        message: 'Reminder: $meetingTitle starts in $reminderMinutes minutes ($formattedTime)',
        type: 'meeting_reminder',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'start_time': startTime.toIso8601String(),
          'meeting_link': meetingLink,
          'event_id': eventId,
          'reminder_minutes': reminderMinutes,
        },
        actionUrl: '/calendar/$eventId',
        priority: 'high',
      );

      debugPrint('✅ Meeting reminder notification sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending meeting reminder notification: $e');
      return false;
    }
  }

  /// Send post-meeting follow-up notification
  static Future<bool> sendPostMeetingFollowUpNotification({
    required String applicantId,
    required String jobId,
    required String jobTitle,
    required String meetingTitle,
    required String decision,
    required int rating,
    required String notes,
    required String eventId,
  }) async {
    try {
      String title;
      String message;
      String priority = 'normal';

      switch (decision) {
        case 'proceed':
          title = 'Interview Follow-up';
          message = 'Great news! The interview for $jobTitle went well. Check your updates for next steps.';
          priority = 'high';
          break;
        case 'hired':
          title = 'Congratulations! You\'re Hired!';
          message = 'Excellent news! You have been selected for $jobTitle. Check your updates for details.';
          priority = 'urgent';
          break;
        case 'reject':
          title = 'Interview Update';
          message = 'Thank you for your time. The interview for $jobTitle has been completed. Check your updates for feedback.';
          break;
        default:
          title = 'Interview Summary Available';
          message = 'The interview summary for $jobTitle is now available. Check your updates for details.';
      }

      await sendNotification(
        userId: applicantId,
        title: title,
        message: message,
        type: 'meeting_summary',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'decision': decision,
          'rating': rating,
          'notes': notes,
          'event_id': eventId,
        },
        actionUrl: '/meetings/$eventId/summary',
        priority: priority,
      );

      debugPrint('✅ Post-meeting follow-up notification sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending post-meeting follow-up notification: $e');
      return false;
    }
  }

  /// Send notification when applicant withdraws an application
  static Future<bool> sendApplicationWithdrawalNotification({
    required String applicantId,
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String applicantName,
    required String applicationId,
    required String withdrawalReason,
    String? withdrawalCategory,
  }) async {
    try {
      // Notify employer about application withdrawal
      await sendNotification(
        userId: employerId,
        title: 'Application Withdrawn',
        message: '$applicantName has withdrawn their application for $jobTitle',
        type: 'application_withdrawn',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'applicant_name': applicantName,
          'applicant_id': applicantId,
          'application_id': applicationId,
          'withdrawal_reason': withdrawalReason,
          'withdrawal_category': withdrawalCategory,
        },
        actionUrl: '/applications/$applicationId',
        priority: 'normal',
      );

      // Notify applicant about successful withdrawal
      await sendNotification(
        userId: applicantId,
        title: 'Application Withdrawn Successfully',
        message: 'Your application for $jobTitle has been withdrawn',
        type: 'application_withdrawal_confirmed',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'application_id': applicationId,
          'withdrawal_reason': withdrawalReason,
        },
        actionUrl: '/applications/$applicationId',
        priority: 'normal',
      );

      debugPrint('✅ Application withdrawal notifications sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending application withdrawal notifications: $e');
      return false;
    }
  }

  /// Send notification when applicant saves/unsaves a job
  static Future<bool> sendJobSaveNotification({
    required String applicantId,
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String applicantName,
    required bool isSaved,
  }) async {
    try {
      final title = isSaved ? 'Job Saved' : 'Job Removed from Saved';
      final message = isSaved 
          ? '$applicantName saved your job posting: $jobTitle'
          : '$applicantName removed $jobTitle from their saved jobs';

      await sendNotification(
        userId: employerId,
        title: title,
        message: message,
        type: isSaved ? 'job_saved' : 'job_unsaved',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'applicant_name': applicantName,
          'applicant_id': applicantId,
          'is_saved': isSaved,
        },
        actionUrl: '/jobs/$jobId',
        priority: 'low',
      );

      debugPrint('✅ Job save notification sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending job save notification: $e');
      return false;
    }
  }

  /// Send notification when applicant updates their profile
  static Future<bool> sendProfileUpdateNotification({
    required String applicantId,
    required String applicantName,
    required int profileCompleteness,
    required List<String> updatedFields,
  }) async {
    try {
      await sendNotification(
        userId: applicantId,
        title: 'Profile Updated Successfully',
        message: 'Your profile has been updated (${profileCompleteness}% complete)',
        type: 'profile_updated',
        payload: {
          'applicant_name': applicantName,
          'profile_completeness': profileCompleteness,
          'updated_fields': updatedFields,
        },
        actionUrl: '/profile',
        priority: 'normal',
      );

      debugPrint('✅ Profile update notification sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending profile update notification: $e');
      return false;
    }
  }

  /// Send notification when applicant requests meeting reschedule
  static Future<bool> sendMeetingRescheduleRequestNotification({
    required String applicantId,
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String meetingTitle,
    required String applicantName,
    required DateTime originalTime,
    required DateTime requestedTime,
    required String reason,
    required String requestId,
  }) async {
    try {
      final formattedOriginalTime = _formatDateTime(originalTime);
      final formattedRequestedTime = _formatDateTime(requestedTime);
      
      // Notify employer about reschedule request
      await sendNotification(
        userId: employerId,
        title: 'Meeting Reschedule Request',
        message: '$applicantName has requested to reschedule "$meetingTitle" from $formattedOriginalTime to $formattedRequestedTime',
        type: 'meeting_reschedule_request',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'applicant_name': applicantName,
          'applicant_id': applicantId,
          'original_time': originalTime.toIso8601String(),
          'requested_time': requestedTime.toIso8601String(),
          'reason': reason,
          'request_id': requestId,
        },
        actionUrl: '/reschedule-requests/$requestId',
        priority: 'high',
      );

      // Notify applicant about request submission
      await sendNotification(
        userId: applicantId,
        title: 'Reschedule Request Sent',
        message: 'Your reschedule request for "$meetingTitle" has been sent to the employer',
        type: 'reschedule_request_sent',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'original_time': originalTime.toIso8601String(),
          'requested_time': requestedTime.toIso8601String(),
          'reason': reason,
          'request_id': requestId,
        },
        actionUrl: '/reschedule-requests/$requestId',
        priority: 'normal',
      );

      debugPrint('✅ Meeting reschedule request notifications sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending meeting reschedule request notifications: $e');
      return false;
    }
  }

  /// Send notification when employer approves a reschedule request
  static Future<bool> sendRescheduleApprovalNotification({
    required String applicantId,
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String meetingTitle,
    required DateTime newStartTime,
    required DateTime newEndTime,
    required String requestId,
    required String eventId,
  }) async {
    try {
      final formattedTime = _formatDateTime(newStartTime);

      // Notify applicant that reschedule was approved
      await sendNotification(
        userId: applicantId,
        title: 'Reschedule Approved',
        message: 'Your meeting "$meetingTitle" was rescheduled to $formattedTime',
        type: 'reschedule_request_approved',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'new_start_time': newStartTime.toIso8601String(),
          'new_end_time': newEndTime.toIso8601String(),
          'request_id': requestId,
          'event_id': eventId,
        },
        actionUrl: '/calendar/$eventId',
        priority: 'high',
      );

      // Optional: notify employer confirmation
      await sendNotification(
        userId: employerId,
        title: 'Reschedule Confirmed',
        message: 'You approved the reschedule for "$meetingTitle" ($formattedTime)',
        type: 'reschedule_request_approved_admin_copy',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'new_start_time': newStartTime.toIso8601String(),
          'new_end_time': newEndTime.toIso8601String(),
          'request_id': requestId,
          'event_id': eventId,
        },
        actionUrl: '/calendar/$eventId',
        priority: 'normal',
      );

      debugPrint('✅ Reschedule approval notifications sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending reschedule approval notifications: $e');
      return false;
    }
  }

  /// Send notification when employer rejects a reschedule request
  static Future<bool> sendRescheduleRejectionNotification({
    required String applicantId,
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String meetingTitle,
    required String reason,
    required String requestId,
  }) async {
    try {
      // Notify applicant that reschedule was rejected
      await sendNotification(
        userId: applicantId,
        title: 'Reschedule Rejected',
        message: 'Your reschedule request for "$meetingTitle" was rejected. Reason: $reason',
        type: 'reschedule_request_rejected',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'reason': reason,
          'request_id': requestId,
        },
        actionUrl: '/reschedule-requests/$requestId',
        priority: 'normal',
      );

      // Optional: notify employer confirmation
      await sendNotification(
        userId: employerId,
        title: 'Reschedule Rejected',
        message: 'You rejected the reschedule request for "$meetingTitle"',
        type: 'reschedule_request_rejected_admin_copy',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'reason': reason,
          'request_id': requestId,
        },
        actionUrl: '/reschedule-requests/$requestId',
        priority: 'low',
      );

      debugPrint('✅ Reschedule rejection notifications sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending reschedule rejection notifications: $e');
      return false;
    }
  }

  /// Send notification when applicant joins a video call
  static Future<bool> sendVideoCallJoinNotification({
    required String applicantId,
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String meetingTitle,
    required String applicantName,
    required String callId,
    required String eventId,
  }) async {
    try {
      await sendNotification(
        userId: employerId,
        title: 'Applicant Joined Interview',
        message: '$applicantName has joined the interview for $jobTitle',
        type: 'video_call_joined',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'applicant_name': applicantName,
          'applicant_id': applicantId,
          'call_id': callId,
          'event_id': eventId,
        },
        actionUrl: '/video-call/$callId',
        priority: 'high',
      );

      debugPrint('✅ Video call join notification sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending video call join notification: $e');
      return false;
    }
  }

  /// Send notification for system announcements
  static Future<bool> sendSystemAnnouncementNotification({
    required List<String> userIds,
    required String title,
    required String message,
    String? actionUrl,
    String priority = 'normal',
  }) async {
    try {
      await sendBulkNotifications(
        userIds: userIds,
        title: title,
        message: message,
        type: 'system_announcement',
        actionUrl: actionUrl,
        priority: priority,
      );

      debugPrint('✅ System announcement notifications sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending system announcement notifications: $e');
      return false;
    }
  }

  /// Send notification when applicant doesn't show up for meeting
  static Future<bool> sendMeetingNoShowNotification({
    required String applicantId,
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String meetingTitle,
    required String applicantName,
    required DateTime missedTime,
    required String eventId,
    bool canReschedule = true,
  }) async {
    try {
      final formattedTime = _formatDateTime(missedTime);
      
      // Notify employer about no-show
      await sendNotification(
        userId: employerId,
        title: 'Interview No-Show',
        message: '$applicantName did not attend the interview for $jobTitle scheduled at $formattedTime',
        type: 'meeting_no_show',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'applicant_name': applicantName,
          'applicant_id': applicantId,
          'missed_time': missedTime.toIso8601String(),
          'event_id': eventId,
          'can_reschedule': canReschedule,
        },
        actionUrl: '/meetings/$eventId',
        priority: 'high',
      );

      // Notify applicant about no-show
      await sendNotification(
        userId: applicantId,
        title: 'Missed Interview',
        message: 'You missed the interview for $jobTitle scheduled at $formattedTime. ${canReschedule ? 'You can request a reschedule.' : 'Please contact the employer.'}',
        type: 'meeting_no_show',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'missed_time': missedTime.toIso8601String(),
          'event_id': eventId,
          'can_reschedule': canReschedule,
        },
        actionUrl: '/meetings/$eventId',
        priority: 'high',
      );

      debugPrint('✅ Meeting no-show notifications sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending meeting no-show notifications: $e');
      return false;
    }
  }

  /// Send notification for application deadline reminders
  static Future<bool> sendApplicationDeadlineReminderNotification({
    required String applicantId,
    required String jobId,
    required String jobTitle,
    required String companyName,
    required DateTime deadline,
    required int daysRemaining,
  }) async {
    try {
      final formattedDeadline = _formatDateTime(deadline);
      String title;
      String message;
      String priority = 'normal';

      if (daysRemaining == 0) {
        title = 'Application Deadline Today!';
        message = 'The application deadline for $jobTitle at $companyName is today at $formattedDeadline';
        priority = 'urgent';
      } else if (daysRemaining == 1) {
        title = 'Application Deadline Tomorrow';
        message = 'The application deadline for $jobTitle at $companyName is tomorrow at $formattedDeadline';
        priority = 'high';
      } else {
        title = 'Application Deadline Reminder';
        message = 'The application deadline for $jobTitle at $companyName is in $daysRemaining days ($formattedDeadline)';
      }

      await sendNotification(
        userId: applicantId,
        title: title,
        message: message,
        type: 'application_deadline_reminder',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'company_name': companyName,
          'deadline': deadline.toIso8601String(),
          'days_remaining': daysRemaining,
        },
        actionUrl: '/jobs/$jobId',
        priority: priority,
      );

      debugPrint('✅ Application deadline reminder notification sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending application deadline reminder notification: $e');
      return false;
    }
  }

  /// Send notification when a meeting is canceled
  static Future<bool> sendMeetingCanceledNotification({
    required String recipientId,
    required String jobId,
    required String jobTitle,
    required String meetingTitle,
    required String eventId,
    required String canceledBy, // 'employer' or 'applicant'
    String? reason,
  }) async {
    try {
      final message = '"$meetingTitle" was canceled by ${canceledBy == 'employer' ? 'the employer' : 'the applicant'}${reason != null && reason.isNotEmpty ? ': $reason' : ''}';

      await sendNotification(
        userId: recipientId,
        title: 'Meeting Canceled',
        message: message,
        type: 'meeting_canceled',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'canceled_by': canceledBy,
          'reason': reason,
          'event_id': eventId,
        },
        actionUrl: '/meetings/$eventId',
        priority: 'high',
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error sending meeting canceled notification: $e');
      return false;
    }
  }

  /// Send notification when a meeting time is updated (non-reschedule path)
  static Future<bool> sendMeetingUpdatedNotification({
    required String recipientId,
    required String jobId,
    required String jobTitle,
    required String meetingTitle,
    required DateTime newStartTime,
    required DateTime newEndTime,
    required String eventId,
  }) async {
    try {
      final formatted = _formatDateTime(newStartTime);
      await sendNotification(
        userId: recipientId,
        title: 'Meeting Updated',
        message: '"$meetingTitle" has a new time: $formatted',
        type: 'meeting_updated',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'new_start_time': newStartTime.toIso8601String(),
          'new_end_time': newEndTime.toIso8601String(),
          'event_id': eventId,
        },
        actionUrl: '/meetings/$eventId',
        priority: 'high',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error sending meeting updated notification: $e');
      return false;
    }
  }

  /// Send reminder to employer before a meeting (host reminder)
  static Future<bool> sendEmployerMeetingReminder({
    required String employerId,
    required String jobId,
    required String jobTitle,
    required String meetingTitle,
    required DateTime startTime,
    required String eventId,
    int reminderMinutes = 15,
  }) async {
    try {
      final formatted = _formatDateTime(startTime);
      await sendNotification(
        userId: employerId,
        title: 'Upcoming Interview',
        message: '"$meetingTitle" starts in $reminderMinutes minutes ($formatted)',
        type: 'employer_meeting_reminder',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'meeting_title': meetingTitle,
          'start_time': startTime.toIso8601String(),
          'event_id': eventId,
          'reminder_minutes': reminderMinutes,
        },
        actionUrl: '/calendar/$eventId',
        priority: 'high',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error sending employer meeting reminder: $e');
      return false;
    }
  }

  /// Notify employer when a job post is expiring soon
  static Future<bool> sendJobPostExpiringNotification({
    required String employerId,
    required String jobId,
    required String jobTitle,
    required DateTime expiresAt,
    int daysRemaining = 3,
  }) async {
    try {
      final formatted = _formatDateTime(expiresAt);
      await sendNotification(
        userId: employerId,
        title: 'Job Post Expiring Soon',
        message: 'Your job "$jobTitle" expires in $daysRemaining days ($formatted). Consider extending.',
        type: 'job_post_expiring',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'expires_at': expiresAt.toIso8601String(),
          'days_remaining': daysRemaining,
        },
        actionUrl: '/jobs/$jobId',
        priority: 'normal',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error sending job post expiring notification: $e');
      return false;
    }
  }

  /// Notify employer when a job post has expired
  static Future<bool> sendJobPostExpiredNotification({
    required String employerId,
    required String jobId,
    required String jobTitle,
    required DateTime expiredAt,
  }) async {
    try {
      final formatted = _formatDateTime(expiredAt);
      await sendNotification(
        userId: employerId,
        title: 'Job Post Expired',
        message: 'Your job "$jobTitle" expired on $formatted. Reopen or create a new post.',
        type: 'job_post_expired',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'expired_at': expiredAt.toIso8601String(),
        },
        actionUrl: '/jobs/$jobId',
        priority: 'normal',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error sending job post expired notification: $e');
      return false;
    }
  }

  /// Daily digest for employer: unread chats and notifications
  static Future<bool> sendEmployerDailyDigest({
    required String employerId,
    required int unreadChats,
    required int unreadNotifications,
  }) async {
    try {
      final message = 'You have $unreadChats unread chat(s) and $unreadNotifications notification(s).';
      await sendNotification(
        userId: employerId,
        title: 'Daily Summary',
        message: message,
        type: 'employer_daily_digest',
        payload: {
          'unread_chats': unreadChats,
          'unread_notifications': unreadNotifications,
        },
        actionUrl: '/notifications',
        priority: 'low',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error sending employer daily digest: $e');
      return false;
    }
  }

  /// Applications pending review nudges for employers
  static Future<bool> sendApplicationsPendingReviewNotification({
    required String employerId,
    required String jobId,
    required String jobTitle,
    required int pendingCount,
  }) async {
    try {
      final message = '$pendingCount application(s) are pending review for "$jobTitle".';
      await sendNotification(
        userId: employerId,
        title: 'Applications Pending Review',
        message: message,
        type: 'applications_pending_review',
        payload: {
          'job_id': jobId,
          'job_title': jobTitle,
          'pending_count': pendingCount,
        },
        actionUrl: '/applications?job=$jobId&filter=pending',
        priority: 'normal',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Error sending applications pending review: $e');
      return false;
    }
  }

  /// Helper method to format DateTime
  static String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    
    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return 'today at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return 'in ${difference.inMinutes} minutes';
    }
  }

  /// Send notification to multiple users
  static Future<bool> sendBulkNotifications({
    required List<String> userIds,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? payload,
    String? imageUrl,
    String? actionUrl,
    String priority = 'normal',
  }) async {
    try {
      if (userIds.isEmpty) return false;

      final appId = dotenv.env['ONESIGNAL_APP_ID'];
      final restKey = dotenv.env['ONESIGNAL_REST_API_KEY'];
      if (appId == null || appId.isEmpty || restKey == null || restKey.isEmpty) {
        debugPrint('⚠️ OneSignal REST not configured. Skipping push delivery.');
        // Fallback to DB-only records to keep UI consistent
        for (final userId in userIds) {
          await _saveNotificationToDatabase(
            userId: userId,
            title: title,
            message: message,
            type: type,
            payload: payload,
            imageUrl: imageUrl,
            actionUrl: actionUrl,
            priority: priority,
            status: 'pending',
          );
        }
        return true;
      }

      final androidChannelId = dotenv.env['ONESIGNAL_ANDROID_CHANNEL_ID'];

      final requestBody = {
        'app_id': appId,
        'include_aliases': {
          'external_id': userIds,
        },
        'target_channel': 'push',
        'headings': {'en': title},
        'contents': {'en': message},
        'data': {
          'type': type,
          'action_url': actionUrl,
          ...?payload,
        },
        if (androidChannelId != null && androidChannelId.isNotEmpty)
          'android_channel_id': androidChannelId,
        'ios_badgeType': 'Increase',
        'ios_badgeCount': 1,
      };

      try {
        final client = HttpClient();
        final req = await client.postUrl(Uri.parse('https://onesignal.com/api/v1/notifications'));
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
        req.headers.set(HttpHeaders.authorizationHeader, 'Basic $restKey');
        req.add(utf8.encode(json.encode(requestBody)));
        final res = await req.close();
        final resBody = await res.transform(utf8.decoder).join();
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = json.decode(resBody) as Map<String, dynamic>;
          final onesignalId = decoded['id']?.toString();
          for (final userId in userIds) {
            await _saveNotificationToDatabase(
              userId: userId,
              title: title,
              message: message,
              type: type,
              payload: payload,
              imageUrl: imageUrl,
              actionUrl: actionUrl,
              priority: priority,
              onesignalId: onesignalId,
              status: 'sent',
            );
          }
          debugPrint('✅ OneSignal REST bulk sent to ${userIds.length} users');
          return true;
        } else {
          debugPrint('❌ OneSignal REST bulk error ${res.statusCode}: $resBody');
          return false;
        }
      } catch (e) {
        debugPrint('❌ OneSignal REST bulk exception: $e');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Error sending bulk notification: $e');
      return false;
    }
  }

  /// Application Status Notification
  static Future<void> sendApplicationStatusNotification({
    required String userId,
    required String jobTitle,
    required String companyName,
    required String status,
    required String applicationId,
  }) async {
    final title = 'Application Status Update';
    final message = 'Your application for $jobTitle at $companyName has been updated to: $status';
    
    await sendNotification(
      userId: userId,
      title: title,
      message: message,
      type: 'application_status',
      payload: {
        'job_title': jobTitle,
        'company_name': companyName,
        'status': status,
        'application_id': applicationId,
      },
      actionUrl: '/applications/$applicationId',
      priority: 'high',
    );
  }


  /// Job Match Notification
  static Future<void> sendJobMatchNotification({
    required String userId,
    required String jobTitle,
    required String companyName,
    required String jobId,
    required double matchScore,
  }) async {
    final title = 'New Job Match Found!';
    final message = '$jobTitle at $companyName - ${(matchScore * 100).toInt()}% match with your profile';
    
    await sendNotification(
      userId: userId,
      title: title,
      message: message,
      type: 'job_match',
      payload: {
        'job_title': jobTitle,
        'company_name': companyName,
        'job_id': jobId,
        'match_score': matchScore,
      },
      actionUrl: '/jobs/$jobId',
      priority: 'normal',
    );
  }

  /// Handle notification received
  static void _handleNotificationReceived(OSNotification notification) {
    try {
      debugPrint('🔔 Notification received: ${notification.title}');
      
      // Update notification status in database
      final notificationId = notification.additionalData?['notification_id'];
      if (notificationId != null) {
        _updateNotificationStatus(
          notificationId,
          status: 'delivered',
          deliveredAt: DateTime.now(),
        );
      }
      
      // Handle app-specific logic
      final type = notification.additionalData?['type'];
      switch (type) {
        case 'chat_message':
          // Update unread count, etc.
          break;
        case 'application_status':
          // Refresh application status
          break;
        // Add more cases as needed
      }
      
    } catch (e) {
      debugPrint('❌ Error handling notification received: $e');
    }
  }

  /// Handle notification opened
  static void _handleNotificationOpened(dynamic result) {
    try {
      debugPrint('🔔 Notification opened: ${result.notification.title}');
      
      // Update notification status
      final notificationId = result.notification.additionalData?['notification_id'];
      if (notificationId != null) {
        _updateNotificationStatus(
          notificationId,
          status: 'clicked',
          clickedAt: DateTime.now(),
        );
      }
      
      // Navigate to appropriate screen
      final actionUrl = result.notification.additionalData?['action_url'];
      final type = result.notification.additionalData?['type'];
      
      if (actionUrl != null) {
        // Handle navigation based on action URL
        _handleNavigation(actionUrl, type);
      }
      
    } catch (e) {
      debugPrint('❌ Error handling notification opened: $e');
    }
  }

  /// Handle navigation based on action URL
  static void _handleNavigation(String actionUrl, String? type) {
    // This would integrate with your navigation system
    debugPrint('🔔 Navigate to: $actionUrl (type: $type)');
    
    // Example navigation logic:
    // if (actionUrl.startsWith('/chat/')) {
    //   Navigator.pushNamed(context, '/chat', arguments: {'chatId': actionUrl.split('/').last});
    // } else if (actionUrl.startsWith('/applications/')) {
    //   Navigator.pushNamed(context, '/application-details', arguments: {'applicationId': actionUrl.split('/').last});
    // }
  }

  /// Save notification to database
  static Future<String> _saveNotificationToDatabase({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? payload,
    String? imageUrl,
    String? actionUrl,
    String priority = 'normal',
    String? onesignalId,
    String status = 'pending',
  }) async {
    try {
      final result = await _supabase
          .from('notifications')
          .insert({
            'user_id': userId,
            'title': title,
            'message': message,
            'type': type,
            'payload': payload ?? {},
            'image_url': imageUrl,
            'action_url': actionUrl,
            'priority': priority,
            'onesignal_notification_id': onesignalId,
            'notification_status': status,
            'sent_at': status == 'sent' ? DateTime.now().toIso8601String() : null,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();
      
      return result['id'];
    } catch (e) {
      debugPrint('❌ Error saving notification to database: $e');
      rethrow;
    }
  }

  /// Update notification status
  static Future<void> _updateNotificationStatus(
    String notificationId, {
    String? onesignalId,
    String? status,
    DateTime? deliveredAt,
    DateTime? clickedAt,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (onesignalId != null) updates['onesignal_notification_id'] = onesignalId;
      if (status != null) updates['notification_status'] = status;
      if (deliveredAt != null) updates['delivered_at'] = deliveredAt.toIso8601String();
      if (clickedAt != null) updates['clicked_at'] = clickedAt.toIso8601String();
      
      if (updates.isNotEmpty) {
        await _supabase
            .from('notifications')
            .update(updates)
            .eq('id', notificationId);
      }
    } catch (e) {
      debugPrint('❌ Error updating notification status: $e');
    }
  }


  /// Get user notifications
  static Future<List<Map<String, dynamic>>> getUserNotifications(String userId) async {
    try {
      final result = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('❌ Error getting user notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for user
  static Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadCount(String userId) async {
    try {
      final result = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      
      return result.length;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Unsubscribe user from notifications
  static Future<void> unsubscribeUser(String userId) async {
    try {
      // Logout user from OneSignal (replaces removeExternalId approach)
      await OneSignal.logout();
      
      // Update device subscription status
      await _supabase
          .from('user_devices')
          .update({
            'is_subscribed': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      
      debugPrint('✅ User unsubscribed from notifications');
      
    } catch (e) {
      debugPrint('❌ Error unsubscribing user: $e');
    }
  }
}
