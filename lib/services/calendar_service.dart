import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/calendar_models.dart';

class CalendarService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get calendar events for a user
  static Future<List<CalendarEvent>> getUserEvents(String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase
          .from('calendar_events')
          .select()
          .or('applicant_id.eq.$userId,employer_id.eq.$userId');
      
      if (startDate != null) {
        query = query.gte('start_time', startDate.toIso8601String());
      }
      
      if (endDate != null) {
        query = query.lte('end_time', endDate.toIso8601String());
      }
      
      final response = await query.order('start_time', ascending: true);
      
      if (response.isNotEmpty) {
        return response.map((json) => CalendarEvent.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error fetching user events: $e');
      return [];
    }
  }

  /// Create a new calendar event
  static Future<CalendarEvent?> createEvent(CalendarEvent event) async {
    try {
      final response = await _supabase.from('calendar_events').insert(event.toJson()).select().single();
      
      return CalendarEvent.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error creating event: $e');
      return null;
    }
  }

  /// Update an existing calendar event
  static Future<CalendarEvent?> updateEvent(CalendarEvent event) async {
    try {
      final updatedEvent = event.copyWith(updatedAt: DateTime.now());
      final response = await _supabase
          .from('calendar_events')
          .update(updatedEvent.toJson())
          .eq('id', event.id)
          .select()
          .single();
      
      return CalendarEvent.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error updating event: $e');
      return null;
    }
  }

  /// Delete a calendar event
  static Future<bool> deleteEvent(String eventId) async {
    try {
      await _supabase.from('calendar_events').delete().eq('id', eventId);
      return true;
    } catch (e) {
      print('Error deleting event: $e');
      return false;
    }
  }

  /// Get availability settings for a user
  static Future<AvailabilitySettings?> getAvailabilitySettings(String userId) async {
    try {
      final response = await _supabase
          .from('availability_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      return AvailabilitySettings.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error fetching availability settings: $e');
      return null;
    }
  }

  /// Update availability settings for a user
  static Future<AvailabilitySettings?> updateAvailabilitySettings(AvailabilitySettings settings) async {
    try {
      final updatedSettings = AvailabilitySettings(
        userId: settings.userId,
        weeklyAvailability: settings.weeklyAvailability,
        advanceBookingDays: settings.advanceBookingDays,
        meetingDurationMinutes: settings.meetingDurationMinutes,
        blockedDates: settings.blockedDates,
        createdAt: settings.createdAt,
        updatedAt: DateTime.now(),
      );
      
      final response = await _supabase
          .from('availability_settings')
          .upsert(updatedSettings.toJson())
          .select()
          .single();
      
      return AvailabilitySettings.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error updating availability settings: $e');
      return null;
    }
  }

  /// Create a meeting request
  static Future<MeetingRequest?> createMeetingRequest(MeetingRequest request) async {
    try {
      final response = await _supabase
          .from('meeting_requests')
          .insert(request.toJson())
          .select()
          .single();
      
      return MeetingRequest.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error creating meeting request: $e');
      return null;
    }
  }

  /// Get meeting requests for a user
  static Future<List<MeetingRequest>> getMeetingRequests(String userId, {
    MeetingRequestStatus? status,
  }) async {
    try {
      var query = _supabase
          .from('meeting_requests')
          .select()
          .or('applicant_id.eq.$userId,employer_id.eq.$userId');
      
      if (status != null) {
        query = query.eq('status', status.toString());
      }
      
      final response = await query.order('created_at', ascending: false);
      
      if (response.isNotEmpty) {
        return response.map((json) => MeetingRequest.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error fetching meeting requests: $e');
      return [];
    }
  }

  /// Respond to a meeting request
  static Future<MeetingRequest?> respondToMeetingRequest(
    String requestId,
    MeetingRequestStatus status,
  ) async {
    try {
      final response = await _supabase
          .from('meeting_requests')
          .update({
            'status': status.toString(),
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .select()
          .single();
      
      return MeetingRequest.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error responding to meeting request: $e');
      return null;
    }
  }

  /// Get available time slots for booking
  static Future<List<DateTime>> getAvailableTimeSlots(
    String userId,
    DateTime date, {
    int durationMinutes = 60,
  }) async {
    try {
      final availabilitySettings = await getAvailabilitySettings(userId);
      if (availabilitySettings == null) {
        return [];
      }

      final dayOfWeek = date.weekday % 7; // Convert to 0-6 (Sunday = 0)
      final dayAvailability = availabilitySettings.weeklyAvailability
          .where((slot) => slot.dayOfWeek == dayOfWeek && slot.isAvailable)
          .toList();

      if (dayAvailability.isEmpty) {
        return [];
      }

      List<DateTime> availableSlots = [];
      
      for (final slot in dayAvailability) {
        final slotStart = DateTime(
          date.year,
          date.month,
          date.day,
          slot.startTime.hour,
          slot.startTime.minute,
        );
        
        final slotEnd = DateTime(
          date.year,
          date.month,
          date.day,
          slot.endTime.hour,
          slot.endTime.minute,
        );
        
        // Generate time slots within this availability window
        DateTime currentSlot = slotStart;
        while (currentSlot.add(Duration(minutes: durationMinutes)).isBefore(slotEnd) ||
               currentSlot.add(Duration(minutes: durationMinutes)) == slotEnd) {
          availableSlots.add(currentSlot);
          currentSlot = currentSlot.add(Duration(minutes: durationMinutes));
        }
      }

      // Filter out slots that conflict with existing events
      final existingEvents = await getUserEvents(userId, startDate: date, endDate: date.add(const Duration(days: 1)));
      final blockedSlots = existingEvents
          .where((event) => event.status != CalendarEventStatus.cancelled)
          .map((event) => event.startTime)
          .toSet();

      return availableSlots.where((slot) => !blockedSlots.contains(slot)).toList();
    } catch (e) {
      print('Error getting available time slots: $e');
      return [];
    }
  }

  /// Check if a time slot is available
  static Future<bool> isTimeSlotAvailable(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final availableSlots = await getAvailableTimeSlots(
        userId,
        startTime,
        durationMinutes: endTime.difference(startTime).inMinutes,
      );
      
      return availableSlots.contains(startTime);
    } catch (e) {
      print('Error checking time slot availability: $e');
      return false;
    }
  }

  /// Generate a unique meeting link
  static String generateMeetingLink() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'hanapbuhay-meeting-$timestamp-$random';
  }

  /// Send calendar notification
  static Future<void> sendCalendarNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error sending calendar notification: $e');
    }
  }

  /// Get calendar statistics for a user
  static Future<Map<String, int>> getCalendarStats(String userId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      
      final events = await getUserEvents(userId, startDate: startOfMonth, endDate: endOfMonth);
      
      return {
        'total_events': events.length,
        'meetings': events.where((e) => e.type == CalendarEventType.meeting).length,
        'interviews': events.where((e) => e.type == CalendarEventType.interview).length,
        'completed': events.where((e) => e.status == CalendarEventStatus.completed).length,
        'upcoming': events.where((e) => e.startTime.isAfter(now)).length,
      };
    } catch (e) {
      print('Error getting calendar stats: $e');
      return {
        'total_events': 0,
        'meetings': 0,
        'interviews': 0,
        'completed': 0,
        'upcoming': 0,
      };
    }
  }
}
