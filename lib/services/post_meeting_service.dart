import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/calendar_models.dart';
import 'onesignal_notification_service.dart';

/// Post-meeting workflow service
/// Handles meeting summaries, notes, ratings, and follow-up actions
class PostMeetingService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Create meeting summary after interview/meeting ends
  static Future<String?> createMeetingSummary({
    required String eventId,
    required String createdBy,
    String? notes,
    int? rating, // 1-5 stars
    List<String>? actionItems,
    List<String>? attendees,
    String? nextSteps,
    String? decision, // 'proceed', 'reject', 'pending'
  }) async {
    try {
      final response = await _supabase
          .from('meeting_summaries')
          .insert({
            'event_id': eventId,
            'created_by': createdBy,
            'notes': notes,
            'rating': rating,
            'action_items': actionItems,
            'attendees': attendees,
            'next_steps': nextSteps,
            'decision': decision,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('id')
          .single();
      
      return response['id'] as String;
    } catch (e) {
      print('Error creating meeting summary: $e');
      return null;
    }
  }
  
  /// Get meeting summary
  static Future<Map<String, dynamic>?> getMeetingSummary(String eventId) async {
    try {
      // Don't join with profiles since foreign key is to auth.users
      // Just get the summary data
      final response = await _supabase
          .from('meeting_summaries')
          .select('*')
          .eq('event_id', eventId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('Error fetching meeting summary: $e');
      return null;
    }
  }
  
  /// Update application status after interview
  static Future<bool> updateApplicationAfterInterview({
    required String applicationId,
    required String newStatus,
    required String updatedBy,
    String? interviewNotes,
    int? rating,
  }) async {
    try {
      await _supabase.rpc('update_application_status', params: {
        'p_application_uuid': applicationId,
        'p_new_status': newStatus,
        'p_updated_by_uuid': updatedBy,
        'p_interview_notes': interviewNotes,
        'p_employer_rating': rating,
      });
      
      return true;
    } catch (e) {
      print('Error updating application after interview: $e');
      return false;
    }
  }
  
  /// Mark meeting as completed
  static Future<bool> markMeetingCompleted(
    String eventId, {
    String? summary,
    int? duration,
  }) async {
    try {
      await _supabase
          .from('calendar_events')
          .update({
            'status': CalendarEventStatus.completed.toString(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', eventId);
      
      return true;
    } catch (e) {
      print('Error marking meeting completed: $e');
      return false;
    }
  }
  
  /// Send follow-up email/notification
  static Future<bool> sendFollowUpNotification({
    required String recipientId,
    required String title,
    required String message,
    String? actionUrl,
  }) async {
    try {
      // Send OneSignal notification
      await OneSignalNotificationService.sendNotification(
        userId: recipientId,
        title: title,
        message: message,
        type: 'meeting_follow_up',
        actionUrl: actionUrl,
        priority: 'normal',
      );

      // Also create database notification for consistency
      await _supabase.from('notifications').insert({
        'user_id': recipientId,
        'title': title,
        'message': message,
        'type': 'meeting_follow_up',
        'action_url': actionUrl,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      print('Error sending follow-up notification: $e');
      return false;
    }
  }
  
  /// Get all summaries for a user
  static Future<List<Map<String, dynamic>>> getUserMeetingSummaries(
    String userId, {
    int limit = 10,
  }) async {
    try {
      // Don't join with profiles since foreign key is to auth.users, not profiles
      final response = await _supabase
          .from('meeting_summaries')
          .select('''
            *,
            calendar_events!event_id (
              title,
              start_time,
              end_time,
              type
            )
          ''')
          .eq('created_by', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching meeting summaries: $e');
      return [];
    }
  }
}

/// Meeting summary model
class MeetingSummary {
  final String id;
  final String eventId;
  final String createdBy;
  final String? notes;
  final int? rating;
  final List<String>? actionItems;
  final List<String>? attendees;
  final String? nextSteps;
  final String? decision;
  final DateTime createdAt;
  
  MeetingSummary({
    required this.id,
    required this.eventId,
    required this.createdBy,
    this.notes,
    this.rating,
    this.actionItems,
    this.attendees,
    this.nextSteps,
    this.decision,
    required this.createdAt,
  });
  
  factory MeetingSummary.fromJson(Map<String, dynamic> json) {
    return MeetingSummary(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      createdBy: json['created_by'] as String,
      notes: json['notes'] as String?,
      rating: json['rating'] as int?,
      actionItems: (json['action_items'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      attendees: (json['attendees'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      nextSteps: json['next_steps'] as String?,
      decision: json['decision'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'created_by': createdBy,
      'notes': notes,
      'rating': rating,
      'action_items': actionItems,
      'attendees': attendees,
      'next_steps': nextSteps,
      'decision': decision,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

