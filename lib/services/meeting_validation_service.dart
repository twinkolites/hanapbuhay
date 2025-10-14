import 'package:supabase_flutter/supabase_flutter.dart';

class MeetingValidationService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  // Validation constants
  static const int maxAdvanceDays = 90; // 90 days in advance
  static const int minStartDelayMinutes = 10; // Must start at least 10 minutes from now
  static const int minDurationMinutes = 5; // Minimum 5 minutes
  static const int maxDurationMinutes = 240; // Maximum 4 hours (240 minutes)
  
  /// Validates meeting date and time
  static ValidationResult validateMeetingDateTime({
    required DateTime startTime,
    required DateTime endTime,
    String? existingEventId,
  }) {
    final now = DateTime.now();
    
    // Rule 1: Disallow past dates or times
    if (startTime.isBefore(now)) {
      return ValidationResult(
        isValid: false,
        errorMessage: "You can't schedule a meeting in the past.",
      );
    }
    
    // Rule 2: Require end time to be after start time
    if (endTime.isBefore(startTime) || endTime.isAtSameMomentAs(startTime)) {
      return ValidationResult(
        isValid: false,
        errorMessage: "End time must be after start time.",
      );
    }
    
    // Rule 3: Enforce short-term cutoff (minimum 10 minutes from now)
    final minStartTime = now.add(const Duration(minutes: minStartDelayMinutes));
    if (startTime.isBefore(minStartTime)) {
      return ValidationResult(
        isValid: false,
        errorMessage: "Meetings must start at least $minStartDelayMinutes minutes from now.",
      );
    }
    
    // Rule 4: Limit advance scheduling (90 days max)
    final maxStartTime = now.add(const Duration(days: maxAdvanceDays));
    if (startTime.isAfter(maxStartTime)) {
      return ValidationResult(
        isValid: false,
        errorMessage: "Meetings can only be scheduled up to $maxAdvanceDays days in advance.",
      );
    }
    
    // Rule 5: Restrict meeting duration (5 minutes to 4 hours)
    final duration = endTime.difference(startTime);
    if (duration.inMinutes < minDurationMinutes) {
      return ValidationResult(
        isValid: false,
        errorMessage: "Meeting duration must be at least $minDurationMinutes minutes.",
      );
    }
    
    if (duration.inMinutes > maxDurationMinutes) {
      return ValidationResult(
        isValid: false,
        errorMessage: "Meeting duration must not exceed ${maxDurationMinutes ~/ 60} hours.",
      );
    }
    
    return ValidationResult(isValid: true);
  }
  
  /// Check for overlapping meetings
  static Future<ValidationResult> checkForOverlaps({
    required String userId,
    required DateTime startTime,
    required DateTime endTime,
    String? existingEventId,
  }) async {
    try {
      // Convert to UTC for database query
      final startUtc = startTime.toUtc();
      final endUtc = endTime.toUtc();
      
      // Query for overlapping events
      // An event overlaps if:
      // - It starts before this meeting ends AND
      // - It ends after this meeting starts
      var query = _supabase
          .from('calendar_events')
          .select('id, title, start_time, end_time')
          .eq('employer_id', userId)
          .neq('status', 'cancelled')
          .lt('start_time', endUtc.toIso8601String())
          .gt('end_time', startUtc.toIso8601String());
      
      // Exclude current event if editing
      if (existingEventId != null && existingEventId.isNotEmpty) {
        query = query.neq('id', existingEventId);
      }
      
      final overlappingEvents = await query;
      
      if (overlappingEvents.isNotEmpty) {
        final conflictEvent = overlappingEvents.first;
        final conflictStart = DateTime.parse(conflictEvent['start_time'] as String).toLocal();
        final conflictEnd = DateTime.parse(conflictEvent['end_time'] as String).toLocal();
        
        return ValidationResult(
          isValid: false,
          errorMessage: "This time slot overlaps with '${conflictEvent['title']}' "
              "(${_formatTime(conflictStart)} - ${_formatTime(conflictEnd)}). "
              "Please choose a different time.",
        );
      }
      
      return ValidationResult(isValid: true);
    } catch (e) {
      print('Error checking for overlaps: $e');
      // If we can't check, allow it (fail open for better UX)
      return ValidationResult(isValid: true);
    }
  }
  
  /// Comprehensive validation for creating/updating a meeting
  static Future<ValidationResult> validateMeeting({
    required DateTime startTime,
    required DateTime endTime,
    required String userId,
    String? existingEventId,
  }) async {
    // First, validate date/time rules
    final dateTimeValidation = validateMeetingDateTime(
      startTime: startTime,
      endTime: endTime,
      existingEventId: existingEventId,
    );
    
    if (!dateTimeValidation.isValid) {
      return dateTimeValidation;
    }
    
    // Then, check for overlapping meetings
    final overlapValidation = await checkForOverlaps(
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      existingEventId: existingEventId,
    );
    
    return overlapValidation;
  }
  
  /// Format time for display (handles timezone conversion)
  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
  
  /// Convert local time to UTC for storage
  static DateTime toUtc(DateTime localTime) {
    return localTime.toUtc();
  }
  
  /// Convert UTC time to local for display
  static DateTime toLocal(DateTime utcTime) {
    return utcTime.toLocal();
  }
  
  /// Format date and time consistently across the app
  static String formatDateTime(DateTime dateTime, {bool use24Hour = false}) {
    final localTime = dateTime.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final date = '${months[localTime.month - 1]} ${localTime.day}, ${localTime.year}';
    
    if (use24Hour) {
      final hour = localTime.hour.toString().padLeft(2, '0');
      final minute = localTime.minute.toString().padLeft(2, '0');
      return '$date at $hour:$minute';
    } else {
      final hour = localTime.hour > 12 ? localTime.hour - 12 : (localTime.hour == 0 ? 12 : localTime.hour);
      final minute = localTime.minute.toString().padLeft(2, '0');
      final period = localTime.hour >= 12 ? 'PM' : 'AM';
      return '$date at $hour:$minute $period';
    }
  }
  
  /// Check if a time is within business hours (optional)
  static bool isWithinBusinessHours(DateTime dateTime, {
    int startHour = 8,
    int endHour = 18,
  }) {
    final hour = dateTime.hour;
    return hour >= startHour && hour < endHour;
  }
  
  /// Validate recurring meeting parameters (for future implementation)
  static ValidationResult validateRecurringMeeting({
    required DateTime startDate,
    required String recurrencePattern, // 'daily', 'weekly', 'monthly'
    required int occurrences,
  }) {
    // Rule: Recurring meetings not beyond 1 year
    final maxOccurrences = {
      'daily': 365,
      'weekly': 52,
      'monthly': 12,
    };
    
    final maxAllowed = maxOccurrences[recurrencePattern.toLowerCase()] ?? 12;
    
    if (occurrences > maxAllowed) {
      return ValidationResult(
        isValid: false,
        errorMessage: "Recurring meetings cannot exceed 1 year (max $maxAllowed occurrences for $recurrencePattern).",
      );
    }
    
    // Check if end date is beyond 1 year
    DateTime endDate;
    switch (recurrencePattern.toLowerCase()) {
      case 'daily':
        endDate = startDate.add(Duration(days: occurrences));
        break;
      case 'weekly':
        endDate = startDate.add(Duration(days: occurrences * 7));
        break;
      case 'monthly':
        endDate = DateTime(
          startDate.year,
          startDate.month + occurrences,
          startDate.day,
        );
        break;
      default:
        return ValidationResult(
          isValid: false,
          errorMessage: "Invalid recurrence pattern. Use 'daily', 'weekly', or 'monthly'.",
        );
    }
    
    final oneYearFromNow = DateTime.now().add(const Duration(days: 365));
    if (endDate.isAfter(oneYearFromNow)) {
      return ValidationResult(
        isValid: false,
        errorMessage: "Recurring meetings cannot extend beyond 1 year from today.",
      );
    }
    
    return ValidationResult(isValid: true);
  }
}

/// Validation result model
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  
  ValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}

