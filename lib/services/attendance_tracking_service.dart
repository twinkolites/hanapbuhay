import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

/// Interview Attendance Tracking Service
/// 
/// Tracks interview attendance, detects no-shows, and provides analytics
/// Based on industry best practices from LinkedIn, Greenhouse, and HireVue
class AttendanceTrackingService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Record when a participant joins the video call
  static Future<bool> recordCallJoin({
    required String eventId,
    required String userId,
    required String userRole, // 'applicant' or 'employer'
  }) async {
    try {
      print('📊 [Attendance] Recording join: $userRole for event $eventId');
      
      final response = await _supabase
          .rpc('record_call_join', params: {
            'p_event_id': eventId,
            'p_user_id': userId,
            'p_user_role': userRole,
          });
      
      print('✅ [Attendance] Join recorded successfully');
      return response as bool? ?? true;
    } catch (e) {
      print('❌ [Attendance] Error recording join: $e');
      return false;
    }
  }
  
  /// Record when a participant leaves the video call
  static Future<bool> recordCallLeave({
    required String eventId,
    required String userId,
    required String userRole, // 'applicant' or 'employer'
  }) async {
    try {
      print('📊 [Attendance] Recording leave: $userRole for event $eventId');
      
      final response = await _supabase
          .rpc('record_call_leave', params: {
            'p_event_id': eventId,
            'p_user_id': userId,
            'p_user_role': userRole,
          });
      
      print('✅ [Attendance] Leave recorded successfully');
      return response as bool? ?? true;
    } catch (e) {
      print('❌ [Attendance] Error recording leave: $e');
      return false;
    }
  }
  
  /// Get attendance record for an event
  static Future<Map<String, dynamic>?> getAttendanceRecord(String eventId) async {
    try {
      final response = await _supabase
          .from('interview_attendance')
          .select()
          .eq('event_id', eventId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('❌ [Attendance] Error fetching attendance: $e');
      return null;
    }
  }
  
  /// Get attendance statistics for a user
  static Future<Map<String, dynamic>?> getAttendanceStats(String userId) async {
    try {
      final response = await _supabase
          .rpc('get_attendance_stats', params: {'p_user_id': userId});
      
      return response as Map<String, dynamic>?;
    } catch (e) {
      print('❌ [Attendance] Error fetching stats: $e');
      return null;
    }
  }
  
  /// Manually mark attendance status
  static Future<bool> updateAttendanceStatus({
    required String eventId,
    required String status,
    bool? isNoShow,
    String? noShowReason,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'attendance_status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (isNoShow != null) {
        updateData['is_no_show'] = isNoShow;
        if (isNoShow && noShowReason != null) {
          updateData['no_show_reason'] = noShowReason;
          updateData['no_show_detected_at'] = DateTime.now().toIso8601String();
        }
      }
      
      await _supabase
          .from('interview_attendance')
          .update(updateData)
          .eq('event_id', eventId);
      
      return true;
    } catch (e) {
      print('❌ [Attendance] Error updating status: $e');
      return false;
    }
  }
  
  /// Run no-show detection (checks for candidates who didn't join)
  static Future<int> detectNoShows() async {
    try {
      print('📊 [Attendance] Running no-show detection...');
      
      final response = await _supabase.rpc('detect_no_shows');
      final count = response as int? ?? 0;
      
      print('✅ [Attendance] Detected $count no-shows');
      return count;
    } catch (e) {
      print('❌ [Attendance] Error detecting no-shows: $e');
      return 0;
    }
  }
  
  /// Get no-show history for applicant (for employer to see)
  static Future<List<Map<String, dynamic>>> getApplicantNoShowHistory(
    String applicantId,
  ) async {
    try {
      final response = await _supabase
          .from('interview_attendance')
          .select('''
            *,
            calendar_events!event_id (
              title,
              start_time,
              type
            )
          ''')
          .eq('applicant_id', applicantId)
          .eq('is_no_show', true)
          .order('scheduled_start_time', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ [Attendance] Error fetching no-show history: $e');
      return [];
    }
  }
  
  /// Check if applicant has high no-show rate (>20% is concerning)
  static Future<bool> hasHighNoShowRate(String applicantId) async {
    try {
      final stats = await getAttendanceStats(applicantId);
      if (stats == null) return false;
      
      final noShowRate = stats['no_show_rate'] as num? ?? 0;
      return noShowRate > 20; // >20% is considered high
    } catch (e) {
      print('❌ [Attendance] Error checking no-show rate: $e');
      return false;
    }
  }
  
  /// Get attendance summary for display
  static String getAttendanceSummary(Map<String, dynamic> attendance) {
    final status = attendance['attendance_status'] as String;
    
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'joined':
        if (attendance['applicant_joined_at'] != null) {
          final late = attendance['is_late'] as bool? ?? false;
          if (late) {
            final mins = attendance['minutes_late'] as int? ?? 0;
            return 'Joined ($mins min late)';
          }
          return 'Joined on time';
        }
        return 'In progress';
      case 'no_show':
        final reason = attendance['no_show_reason'] as String? ?? 'unknown';
        return 'No-show ($reason)';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        final duration = attendance['applicant_duration_minutes'] as int? ?? 0;
        return 'Completed (${duration}min)';
      default:
        return status;
    }
  }
  
  /// Get color for attendance status
  static Color getAttendanceColor(String status) {
    switch (status) {
      case 'joined':
      case 'completed':
        return const Color(0xFF4CA771); // mediumSeaGreen
      case 'scheduled':
        return const Color(0xFF2196F3); // blue
      case 'no_show':
        return const Color(0xFFF44336); // red
      case 'cancelled':
        return const Color(0xFF9E9E9E); // grey
      default:
        return const Color(0xFF2196F3);
    }
  }
}

