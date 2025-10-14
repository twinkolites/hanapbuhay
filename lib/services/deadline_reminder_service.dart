import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'onesignal_notification_service.dart';

/// Deadline Reminder Service
/// 
/// Handles application deadline reminders and notifications
/// Based on industry best practices from LinkedIn, Indeed, and Glassdoor
class DeadlineReminderService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Send deadline reminders for jobs with upcoming deadlines
  static Future<bool> sendDeadlineReminders() async {
    try {
      debugPrint('🕐 [Deadline] Starting deadline reminder process...');

      // Get jobs with deadlines in the next 7 days
      final now = DateTime.now();
      final sevenDaysFromNow = now.add(const Duration(days: 7));

      final jobsWithDeadlines = await _supabase
          .from('jobs')
          .select('''
            id,
            title,
            application_deadline,
            companies (
              name
            )
          ''')
          .not('application_deadline', 'is', null)
          .gte('application_deadline', now.toIso8601String())
          .lte('application_deadline', sevenDaysFromNow.toIso8601String())
          .eq('status', 'open');

      debugPrint('📅 [Deadline] Found ${jobsWithDeadlines.length} jobs with upcoming deadlines');

      // Get all active applicants (users who have applied to jobs recently)
      final activeApplicants = await _supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'applicant')
          .eq('is_active', true);

      debugPrint('👥 [Deadline] Found ${activeApplicants.length} active applicants');

      int notificationsSent = 0;

      for (final job in jobsWithDeadlines) {
        final jobId = job['id'];
        final jobTitle = job['title'];
        final companyName = job['companies']['name'] ?? 'Unknown Company';
        final deadline = DateTime.parse(job['application_deadline']);
        
        // Calculate days remaining
        final daysRemaining = deadline.difference(now).inDays;

        // Only send reminders for deadlines in 0, 1, 3, or 7 days
        if ([0, 1, 3, 7].contains(daysRemaining)) {
          for (final applicant in activeApplicants) {
            final applicantId = applicant['id'];
            final applicantName = applicant['full_name'] ?? 'Unknown';

            // Check if applicant has already applied to this job
            final hasApplied = await _supabase
                .from('job_applications')
                .select('id')
                .eq('applicant_id', applicantId)
                .eq('job_id', jobId)
                .maybeSingle();

            // Only send reminder if applicant hasn't applied yet
            if (hasApplied == null) {
              try {
                await OneSignalNotificationService.sendApplicationDeadlineReminderNotification(
                  applicantId: applicantId,
                  jobId: jobId,
                  jobTitle: jobTitle,
                  companyName: companyName,
                  deadline: deadline,
                  daysRemaining: daysRemaining,
                );

                notificationsSent++;
                debugPrint('✅ [Deadline] Reminder sent to $applicantName for $jobTitle (${daysRemaining} days remaining)');
              } catch (notificationError) {
                debugPrint('❌ [Deadline] Error sending reminder to $applicantName: $notificationError');
              }
            }
          }
        }
      }

      debugPrint('📧 [Deadline] Deadline reminder process completed. Sent $notificationsSent notifications');
      return true;
    } catch (e) {
      debugPrint('❌ [Deadline] Error in deadline reminder process: $e');
      return false;
    }
  }

  /// Send deadline reminder for a specific job
  static Future<bool> sendJobDeadlineReminder({
    required String jobId,
    required String applicantId,
  }) async {
    try {
      // Get job details
      final jobDetails = await _supabase
          .from('jobs')
          .select('''
            id,
            title,
            application_deadline,
            companies (
              name
            )
          ''')
          .eq('id', jobId)
          .single();

      final jobTitle = jobDetails['title'];
      final companyName = jobDetails['companies']['name'] ?? 'Unknown Company';
      final deadline = DateTime.parse(jobDetails['application_deadline']);
      final now = DateTime.now();
      final daysRemaining = deadline.difference(now).inDays;

      // Send notification
      await OneSignalNotificationService.sendApplicationDeadlineReminderNotification(
        applicantId: applicantId,
        jobId: jobId,
        jobTitle: jobTitle,
        companyName: companyName,
        deadline: deadline,
        daysRemaining: daysRemaining,
      );

      debugPrint('✅ [Deadline] Job deadline reminder sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ [Deadline] Error sending job deadline reminder: $e');
      return false;
    }
  }

  /// Get jobs with upcoming deadlines for a specific applicant
  static Future<List<Map<String, dynamic>>> getUpcomingDeadlines({
    required String applicantId,
    int daysAhead = 7,
  }) async {
    try {
      final now = DateTime.now();
      final futureDate = now.add(Duration(days: daysAhead));

      final upcomingJobs = await _supabase
          .from('jobs')
          .select('''
            id,
            title,
            application_deadline,
            companies (
              name
            )
          ''')
          .not('application_deadline', 'is', null)
          .gte('application_deadline', now.toIso8601String())
          .lte('application_deadline', futureDate.toIso8601String())
          .eq('status', 'open')
          .order('application_deadline', ascending: true);

      // Filter out jobs the applicant has already applied to
      final filteredJobs = <Map<String, dynamic>>[];
      
      for (final job in upcomingJobs) {
        final hasApplied = await _supabase
            .from('job_applications')
            .select('id')
            .eq('applicant_id', applicantId)
            .eq('job_id', job['id'])
            .maybeSingle();

        if (hasApplied == null) {
          final deadline = DateTime.parse(job['application_deadline']);
          final daysRemaining = deadline.difference(now).inDays;
          
          filteredJobs.add({
            ...job,
            'days_remaining': daysRemaining,
          });
        }
      }

      return filteredJobs;
    } catch (e) {
      debugPrint('❌ [Deadline] Error getting upcoming deadlines: $e');
      return [];
    }
  }
}
