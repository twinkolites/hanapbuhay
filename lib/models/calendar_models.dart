import 'package:flutter/material.dart';

/// Calendar event model for meetings and availability
class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? description;
  final Color color;
  final bool isAllDay;
  final String? location;
  final String? meetingLink;
  final CalendarEventType type;
  final String? applicantId;
  final String? employerId;
  final String? jobId;
  final CalendarEventStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    this.color = Colors.blue,
    this.isAllDay = false,
    this.location,
    this.meetingLink,
    required this.type,
    this.applicantId,
    this.employerId,
    this.jobId,
    this.status = CalendarEventStatus.scheduled,
    required this.createdAt,
    this.updatedAt,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      description: json['description'] as String?,
      color: Color(json['color'] as int? ?? Colors.blue.value),
      isAllDay: json['is_all_day'] as bool? ?? false,
      location: json['location'] as String?,
      meetingLink: json['meeting_link'] as String?,
      type: CalendarEventType.fromString(json['type'] as String),
      applicantId: json['applicant_id'] as String?,
      employerId: json['employer_id'] as String?,
      jobId: json['job_id'] as String?,
      status: CalendarEventStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id, // Only include id if it's not empty
      'title': title,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'description': description,
      'color': color.value.toSigned(32), // Convert to signed 32-bit integer for PostgreSQL
      'is_all_day': isAllDay,
      'location': location,
      'meeting_link': meetingLink,
      'type': type.toString(),
      'applicant_id': applicantId,
      'employer_id': employerId,
      'job_id': jobId,
      'status': status.toString(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    Color? color,
    bool? isAllDay,
    String? location,
    String? meetingLink,
    CalendarEventType? type,
    String? applicantId,
    String? employerId,
    String? jobId,
    CalendarEventStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      color: color ?? this.color,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      meetingLink: meetingLink ?? this.meetingLink,
      type: type ?? this.type,
      applicantId: applicantId ?? this.applicantId,
      employerId: employerId ?? this.employerId,
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Types of calendar events
enum CalendarEventType {
  availability,
  meeting,
  interview,
  reminder,
  blocked;

  static CalendarEventType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'availability':
        return CalendarEventType.availability;
      case 'meeting':
        return CalendarEventType.meeting;
      case 'interview':
        return CalendarEventType.interview;
      case 'reminder':
        return CalendarEventType.reminder;
      case 'blocked':
        return CalendarEventType.blocked;
      default:
        return CalendarEventType.meeting;
    }
  }

  @override
  String toString() => name.toLowerCase();
}

/// Status of calendar events
enum CalendarEventStatus {
  scheduled,
  confirmed,
  completed,
  cancelled,
  rescheduled;

  static CalendarEventStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'scheduled':
        return CalendarEventStatus.scheduled;
      case 'confirmed':
        return CalendarEventStatus.confirmed;
      case 'completed':
        return CalendarEventStatus.completed;
      case 'cancelled':
        return CalendarEventStatus.cancelled;
      case 'rescheduled':
        return CalendarEventStatus.rescheduled;
      default:
        return CalendarEventStatus.scheduled;
    }
  }

  @override
  String toString() => name.toLowerCase();
}

/// Availability settings for users
class AvailabilitySettings {
  final String? id;
  final String userId;
  final List<AvailabilitySlot> weeklyAvailability;
  final int advanceBookingDays;
  final int meetingDurationMinutes;
  final List<String> blockedDates;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AvailabilitySettings({
    this.id,
    required this.userId,
    required this.weeklyAvailability,
    this.advanceBookingDays = 30,
    this.meetingDurationMinutes = 60,
    this.blockedDates = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory AvailabilitySettings.fromJson(Map<String, dynamic> json) {
    return AvailabilitySettings(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      weeklyAvailability: (json['weekly_availability'] as List<dynamic>)
          .map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      advanceBookingDays: json['advance_booking_days'] as int? ?? 30,
      meetingDurationMinutes: json['meeting_duration_minutes'] as int? ?? 60,
      blockedDates: (json['blocked_dates'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'weekly_availability': weeklyAvailability.map((e) => e.toJson()).toList(),
      'advance_booking_days': advanceBookingDays,
      'meeting_duration_minutes': meetingDurationMinutes,
      'blocked_dates': blockedDates,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Individual availability slot
class AvailabilitySlot {
  final int dayOfWeek; // 0 = Sunday, 1 = Monday, etc.
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isAvailable;

  AvailabilitySlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    final startHour = json['start_hour'] as int;
    final startMinute = json['start_minute'] as int;
    final endHour = json['end_hour'] as int;
    final endMinute = json['end_minute'] as int;

    return AvailabilitySlot(
      dayOfWeek: json['day_of_week'] as int,
      startTime: TimeOfDay(hour: startHour, minute: startMinute),
      endTime: TimeOfDay(hour: endHour, minute: endMinute),
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'start_hour': startTime.hour,
      'start_minute': startTime.minute,
      'end_hour': endTime.hour,
      'end_minute': endTime.minute,
      'is_available': isAvailable,
    };
  }
}

/// Meeting request model
class MeetingRequest {
  final String id;
  final String applicantId;
  final String employerId;
  final String jobId;
  final DateTime requestedStartTime;
  final DateTime requestedEndTime;
  final String? message;
  final MeetingRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  MeetingRequest({
    required this.id,
    required this.applicantId,
    required this.employerId,
    required this.jobId,
    required this.requestedStartTime,
    required this.requestedEndTime,
    this.message,
    this.status = MeetingRequestStatus.pending,
    required this.createdAt,
    this.respondedAt,
  });

  factory MeetingRequest.fromJson(Map<String, dynamic> json) {
    return MeetingRequest(
      id: json['id'] as String,
      applicantId: json['applicant_id'] as String,
      employerId: json['employer_id'] as String,
      jobId: json['job_id'] as String,
      requestedStartTime: DateTime.parse(json['requested_start_time'] as String),
      requestedEndTime: DateTime.parse(json['requested_end_time'] as String),
      message: json['message'] as String?,
      status: MeetingRequestStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null 
          ? DateTime.parse(json['responded_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'applicant_id': applicantId,
      'employer_id': employerId,
      'job_id': jobId,
      'requested_start_time': requestedStartTime.toIso8601String(),
      'requested_end_time': requestedEndTime.toIso8601String(),
      'message': message,
      'status': status.toString(),
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}

/// Meeting request status
enum MeetingRequestStatus {
  pending,
  accepted,
  rejected,
  expired;

  static MeetingRequestStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return MeetingRequestStatus.pending;
      case 'accepted':
        return MeetingRequestStatus.accepted;
      case 'rejected':
        return MeetingRequestStatus.rejected;
      case 'expired':
        return MeetingRequestStatus.expired;
      default:
        return MeetingRequestStatus.pending;
    }
  }

  @override
  String toString() => name.toLowerCase();
}
