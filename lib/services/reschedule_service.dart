import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'attendance_tracking_service.dart';
import 'onesignal_notification_service.dart';

/// Reschedule Service
/// 
/// Handles detection of no-show meetings and rescheduling workflows
/// Based on industry best practices from LinkedIn, Greenhouse, and Calendly
class RescheduleService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Detect meetings that ended with no attendance
  static Future<List<Map<String, dynamic>>> getNoShowMeetings(String userId) async {
    try {
      final now = DateTime.now();
      
      // Find meetings that ended in the last 7 days with no attendance
      final meetings = await _supabase
          .from('calendar_events')
          .select('''
            *,
            applicant:applicant_id(id, full_name, email),
            employer:employer_id(id, full_name, email),
            job:job_id(id, title, company_id)
          ''')
          .or('applicant_id.eq.$userId,employer_id.eq.$userId')
          .eq('type', 'interview')
          .eq('status', 'completed')
          .gte('end_time', now.subtract(const Duration(days: 7)).toIso8601String())
          .order('end_time', ascending: false);
      
      final noShowMeetings = <Map<String, dynamic>>[];
      
      for (final meeting in meetings) {
        // Check attendance record
        final attendance = await AttendanceTrackingService.getAttendanceRecord(meeting['id']);
        
        if (attendance != null) {
          final isNoShow = attendance['is_no_show'] as bool? ?? false;
          final hasAttendance = attendance['applicant_joined_at'] != null;
          
          if (isNoShow || !hasAttendance) {
            // Check if reschedule request already exists
            final existingRequest = await _supabase
                .from('reschedule_requests')
                .select('id, status')
                .eq('original_event_id', meeting['id'])
                .maybeSingle();
            
            // Send no-show notification if no existing request
            if (existingRequest == null) {
              try {
                final applicantId = meeting['applicant_id'];
                final employerId = meeting['employer_id'];
                final jobId = meeting['job']['id'];
                final jobTitle = meeting['job']['title'];
                final meetingTitle = meeting['title'];
                final applicantName = meeting['applicant']['full_name'] ?? 'Unknown';
                final missedTime = DateTime.parse(meeting['end_time']);

                await OneSignalNotificationService.sendMeetingNoShowNotification(
                  applicantId: applicantId,
                  employerId: employerId,
                  jobId: jobId,
                  jobTitle: jobTitle,
                  meetingTitle: meetingTitle,
                  applicantName: applicantName,
                  missedTime: missedTime,
                  eventId: meeting['id'],
                  canReschedule: true,
                );

                print('✅ Meeting no-show notification sent successfully');
              } catch (notificationError) {
                print('❌ Error sending meeting no-show notification: $notificationError');
                // Don't fail the detection if notifications fail
              }
            }
            
            noShowMeetings.add({
              ...meeting,
              'attendance': attendance,
              'has_reschedule_request': existingRequest != null,
              'reschedule_status': existingRequest?['status'],
            });
          }
        }
      }
      
      return noShowMeetings;
    } catch (e) {
      print('❌ [Reschedule] Error fetching no-show meetings: $e');
      return [];
    }
  }
  
  /// Create a reschedule request
  static Future<bool> createRescheduleRequest({
    required String originalEventId,
    required String requesterId,
    required String reason,
    DateTime? preferredDate,
    TimeOfDay? preferredStartTime,
    TimeOfDay? preferredEndTime,
  }) async {
    try {
      print('🔄 [Reschedule] Creating reschedule request for event $originalEventId');
      
      final requestData = {
        'original_event_id': originalEventId,
        'requester_id': requesterId,
        'reason': reason,
        'preferred_date': preferredDate?.toIso8601String(),
        'preferred_start_time': preferredStartTime != null 
            ? '${preferredStartTime.hour}:${preferredStartTime.minute.toString().padLeft(2, '0')}'
            : null,
        'preferred_end_time': preferredEndTime != null
            ? '${preferredEndTime.hour}:${preferredEndTime.minute.toString().padLeft(2, '0')}'
            : null,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final result = await _supabase
          .from('reschedule_requests')
          .insert(requestData)
          .select()
          .single();
      
      print('✅ [Reschedule] Reschedule request created: ${result['id']}');
      
      // Send notification to the other party
      await _sendRescheduleNotification(originalEventId, requesterId, result['id']);
      
      return true;
    } catch (e) {
      print('❌ [Reschedule] Error creating reschedule request: $e');
      return false;
    }
  }
  
  /// Get reschedule requests for a user
  static Future<List<Map<String, dynamic>>> getRescheduleRequests(String userId) async {
    try {
      final requests = await _supabase
          .from('reschedule_requests')
          .select('''
            *,
            original_event:original_event_id(
              id, title, start_time, end_time, description,
              applicant:applicant_id(id, full_name, email),
              employer:employer_id(id, full_name, email)
            ),
            requester:requester_id(id, full_name, email)
          ''')
          .or('requester_id.eq.$userId,original_event.applicant_id.eq.$userId,original_event.employer_id.eq.$userId')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(requests);
    } catch (e) {
      print('❌ [Reschedule] Error fetching reschedule requests: $e');
      return [];
    }
  }
  
  /// Approve a reschedule request
  static Future<bool> approveRescheduleRequest({
    required String requestId,
    required DateTime newStartTime,
    required DateTime newEndTime,
  }) async {
    try {
      print('🔄 [Reschedule] Approving request $requestId');
      
      // Get the original request
      final request = await _supabase
          .from('reschedule_requests')
          .select('original_event_id, requester_id')
          .eq('id', requestId)
          .single();
      
      final originalEventId = request['original_event_id'] as String;
      
      // Update the original event with new times
      await _supabase
          .from('calendar_events')
          .update({
            'start_time': newStartTime.toIso8601String(),
            'end_time': newEndTime.toIso8601String(),
            'status': 'scheduled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', originalEventId);
      
      // Update the reschedule request status
      await _supabase
          .from('reschedule_requests')
          .update({
            'status': 'approved',
            'new_start_time': newStartTime.toIso8601String(),
            'new_end_time': newEndTime.toIso8601String(),
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      
      // Send notification to requester
      await _sendRescheduleApprovalNotification(requestId);
      
      print('✅ [Reschedule] Request approved successfully');
      return true;
    } catch (e) {
      print('❌ [Reschedule] Error approving request: $e');
      return false;
    }
  }
  
  /// Reject a reschedule request
  static Future<bool> rejectRescheduleRequest({
    required String requestId,
    required String reason,
  }) async {
    try {
      print('🔄 [Reschedule] Rejecting request $requestId');
      
      await _supabase
          .from('reschedule_requests')
          .update({
            'status': 'rejected',
            'rejection_reason': reason,
            'rejected_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      
      // Send notification to requester
      await _sendRescheduleRejectionNotification(requestId, reason);
      
      print('✅ [Reschedule] Request rejected');
      return true;
    } catch (e) {
      print('❌ [Reschedule] Error rejecting request: $e');
      return false;
    }
  }
  
  /// Send reschedule notification
  static Future<void> _sendRescheduleNotification(
    String originalEventId,
    String requesterId,
    String requestId,
  ) async {
    try {
      // Get event details
      final event = await _supabase
          .from('calendar_events')
          .select('applicant_id, employer_id, title')
          .eq('id', originalEventId)
          .single();
      
      final applicantId = event['applicant_id'] as String?;
      final employerId = event['employer_id'] as String?;
      final eventTitle = event['title'] as String;
      
      // Determine who to notify (the other party)
      String? recipientId;
      if (requesterId == applicantId) {
        recipientId = employerId;
      } else {
        recipientId = applicantId;
      }
      
      if (recipientId != null) {
        // Send OneSignal notification
        try {
          // Get job details for notification
          final jobDetails = await _supabase
              .from('calendar_events')
              .select('job_id, jobs(title)')
              .eq('id', originalEventId)
              .single();

          final jobId = jobDetails['job_id'] ?? '';
          final jobTitle = jobDetails['jobs']['title'] ?? 'Unknown Job';

          // Get requester name
          final requesterProfile = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', requesterId)
              .single();

          final requesterName = requesterProfile['full_name'] ?? 'Unknown';

          // Get original event time
          final originalEvent = await _supabase
              .from('calendar_events')
              .select('start_time')
              .eq('id', originalEventId)
              .single();

          final originalTime = DateTime.parse(originalEvent['start_time']);

          // Get requested time from reschedule request
          final rescheduleRequest = await _supabase
              .from('reschedule_requests')
              .select('preferred_date, preferred_start_time, reason')
              .eq('id', requestId)
              .single();

          final requestedDate = rescheduleRequest['preferred_date'] != null 
              ? DateTime.parse(rescheduleRequest['preferred_date'])
              : originalTime;
          final requestedTimeStr = rescheduleRequest['preferred_start_time'] ?? '09:00';
          final reason = rescheduleRequest['reason'] ?? 'No reason provided';

          final requestedTime = DateTime(
            requestedDate.year,
            requestedDate.month,
            requestedDate.day,
            int.parse(requestedTimeStr.split(':')[0]),
            int.parse(requestedTimeStr.split(':')[1]),
          );

          await OneSignalNotificationService.sendMeetingRescheduleRequestNotification(
            applicantId: applicantId ?? '',
            employerId: employerId ?? '',
            jobId: jobId,
            jobTitle: jobTitle,
            meetingTitle: eventTitle,
            applicantName: requesterName,
            originalTime: originalTime,
            requestedTime: requestedTime,
            reason: reason,
            requestId: requestId,
          );

          print('✅ Reschedule request OneSignal notification sent successfully');
        } catch (notificationError) {
          print('❌ Error sending reschedule OneSignal notification: $notificationError');
          // Don't fail the reschedule request if notifications fail
        }

        // Also create database notification for consistency
        await _supabase.from('notifications').insert({
          'user_id': recipientId,
          'type': 'reschedule_request',
          'title': 'Reschedule Request',
          'message': 'A reschedule request has been made for "$eventTitle"',
          'data': {
            'event_id': originalEventId,
            'request_id': requestId,
            'requester_id': requesterId,
          },
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('❌ [Reschedule] Error sending notification: $e');
    }
  }
  
  /// Send reschedule approval notification
  static Future<void> _sendRescheduleApprovalNotification(String requestId) async {
    try {
      final request = await _supabase
          .from('reschedule_requests')
          .select('requester_id, original_event_id, new_start_time, new_end_time')
          .eq('id', requestId)
          .single();

      final event = await _supabase
          .from('calendar_events')
          .select('''
            id, title, job_id, applicant_id, employer_id,
            jobs(title)
          ''')
          .eq('id', request['original_event_id'])
          .single();

      await OneSignalNotificationService.sendRescheduleApprovalNotification(
        applicantId: event['applicant_id'],
        employerId: event['employer_id'],
        jobId: event['job_id'],
        jobTitle: event['jobs']['title'] ?? 'Unknown Job',
        meetingTitle: event['title'] ?? 'Interview',
        newStartTime: DateTime.parse(request['new_start_time']),
        newEndTime: DateTime.parse(request['new_end_time']),
        requestId: requestId,
        eventId: event['id'],
      );
    } catch (e) {
      print('❌ [Reschedule] Error sending approval notification: $e');
    }
  }
  
  /// Send reschedule rejection notification
  static Future<void> _sendRescheduleRejectionNotification(
    String requestId,
    String reason,
  ) async {
    try {
      final request = await _supabase
          .from('reschedule_requests')
          .select('requester_id, original_event_id')
          .eq('id', requestId)
          .single();

      final event = await _supabase
          .from('calendar_events')
          .select('''
            id, title, job_id, applicant_id, employer_id,
            jobs(title)
          ''')
          .eq('id', request['original_event_id'])
          .single();

      await OneSignalNotificationService.sendRescheduleRejectionNotification(
        applicantId: event['applicant_id'],
        employerId: event['employer_id'],
        jobId: event['job_id'],
        jobTitle: event['jobs']['title'] ?? 'Unknown Job',
        meetingTitle: event['title'] ?? 'Interview',
        reason: reason,
        requestId: requestId,
      );
    } catch (e) {
      print('❌ [Reschedule] Error sending rejection notification: $e');
    }
  }
  
  /// Get reschedule reasons (predefined options)
  static List<String> getRescheduleReasons() {
    return [
      'Technical difficulties',
      'Personal emergency',
      'Schedule conflict',
      'Transportation issues',
      'Family emergency',
      'Health issues',
      'Work commitment',
      'Other',
    ];
  }
}
