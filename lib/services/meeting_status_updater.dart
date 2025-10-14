import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/calendar_models.dart';

/// Meeting Status Updater Service
/// 
/// Automatically updates meeting status based on current time
/// Industry best practice: Real-time status management
class MeetingStatusUpdater {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Check and update status of a single event based on current time
  static CalendarEventStatus getAccurateStatus(CalendarEvent event) {
    final now = DateTime.now();
    
    // If already manually completed or cancelled, keep that status
    if (event.status == CalendarEventStatus.completed || 
        event.status == CalendarEventStatus.cancelled) {
      return event.status;
    }
    
    // Auto-determine status based on time
    if (event.endTime.isBefore(now)) {
      // Meeting has ended - should be completed
      return CalendarEventStatus.completed;
    } else if (event.startTime.isBefore(now) && event.endTime.isAfter(now)) {
      // Meeting is ongoing - confirm it
      return CalendarEventStatus.confirmed;
    } else {
      // Meeting is upcoming - keep scheduled/confirmed
      return event.status == CalendarEventStatus.confirmed 
          ? CalendarEventStatus.confirmed 
          : CalendarEventStatus.scheduled;
    }
  }
  
  /// Update event status in database if needed
  static Future<bool> updateEventStatusIfNeeded(CalendarEvent event) async {
    final accurateStatus = getAccurateStatus(event);
    
    // Only update if status has changed
    if (accurateStatus != event.status) {
      try {
        print('🔄 [StatusUpdater] Updating event ${event.id} from ${event.status} to $accurateStatus');
        
        await _supabase
            .from('calendar_events')
            .update({
              'status': accurateStatus.name,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', event.id);
        
        print('✅ [StatusUpdater] Event status updated successfully');
        return true;
      } catch (e) {
        print('❌ [StatusUpdater] Error updating event status: $e');
        return false;
      }
    }
    
    return false; // No update needed
  }
  
  /// Batch update all events for a user
  static Future<int> updateAllUserEvents(String userId) async {
    try {
      print('🔄 [StatusUpdater] Checking all events for user $userId');
      
      final now = DateTime.now();
      
      // Update all events that have ended but are not marked as completed
      final result = await _supabase
          .from('calendar_events')
          .update({
            'status': CalendarEventStatus.completed.name,
            'updated_at': now.toIso8601String(),
          })
          .or('applicant_id.eq.$userId,employer_id.eq.$userId')
          .lt('end_time', now.toIso8601String())
          .neq('status', CalendarEventStatus.completed.name)
          .neq('status', CalendarEventStatus.cancelled.name)
          .select();
      
      print('✅ [StatusUpdater] Updated ${result.length} events to completed');
      return result.length;
    } catch (e) {
      print('❌ [StatusUpdater] Error batch updating events: $e');
      return 0;
    }
  }
  
  /// Check if event should be shown in "upcoming" lists
  static bool shouldShowInUpcoming(CalendarEvent event) {
    final now = DateTime.now();
    return event.endTime.isAfter(now) && 
           event.status != CalendarEventStatus.completed &&
           event.status != CalendarEventStatus.cancelled;
  }
  
  /// Check if event should be shown in "today's agenda"
  static bool shouldShowInTodaysAgenda(CalendarEvent event, DateTime today) {
    final now = DateTime.now();
    final isToday = event.startTime.year == today.year &&
                    event.startTime.month == today.month &&
                    event.startTime.day == today.day;
    
    return isToday && 
           event.endTime.isAfter(now) && // Not ended yet
           event.status != CalendarEventStatus.cancelled;
  }
  
  /// Get time-based display status for UI
  static String getDisplayStatus(CalendarEvent event) {
    final now = DateTime.now();
    
    if (event.status == CalendarEventStatus.cancelled) {
      return 'Cancelled';
    }
    
    if (event.status == CalendarEventStatus.completed) {
      return 'Completed';
    }
    
    if (event.endTime.isBefore(now)) {
      return 'Ended';
    }
    
    if (event.startTime.isBefore(now) && event.endTime.isAfter(now)) {
      return 'Ongoing';
    }
    
    // Calculate time until meeting
    final difference = event.startTime.difference(now);
    if (difference.inMinutes < 60) {
      return 'Starts in ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Starts in ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else {
      return 'Upcoming';
    }
  }
}

