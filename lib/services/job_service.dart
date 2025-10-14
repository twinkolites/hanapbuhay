import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/app_config.dart';
import 'onesignal_notification_service.dart';
import 'admin_service.dart';

class JobService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get all available job types
  static Future<List<Map<String, dynamic>>> getJobTypes() async {
    try {
      final response = await _supabase
          .from('job_types')
          .select('*')
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching job types: $e');
      return [];
    }
  }

  // Get job type ids and primary flag for a specific job
  static Future<List<Map<String, dynamic>>> getJobTypesForJob(String jobId) async {
    try {
      final response = await _supabase
          .from('job_job_types')
          .select('job_type_id,is_primary')
          .eq('job_id', jobId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching job types for job: $e');
      return [];
    }
  }

  // Replace a job's job types with the provided set and primary flag
  static Future<bool> setJobTypesForJob({
    required String jobId,
    required List<String> jobTypeIds,
    String? primaryJobTypeId,
  }) async {
    try {
      // Clear existing relations
      await _supabase.from('job_job_types').delete().eq('job_id', jobId);

      if (jobTypeIds.isEmpty) {
        return true; // nothing to insert
      }

      final rows = jobTypeIds.map((id) => {
            'job_id': jobId,
            'job_type_id': id,
            'is_primary': primaryJobTypeId == id ||
                (primaryJobTypeId == null && id == jobTypeIds.first),
          }).toList();

      await _supabase.from('job_job_types').insert(rows);

      return true;
    } catch (e) {
      debugPrint('Error setting job types for job: $e');
      return false;
    }
  }

  // Get all jobs with multiple job types (OPTIMIZED with stored procedure)
  static Future<List<Map<String, dynamic>>> getAllJobs() async {
    try {
      // Use optimized stored procedure for faster data fetching
      final response = await _supabase.rpc('get_all_jobs_with_details');
      
      if (response == null) {
        debugPrint('⚠️ No response from get_all_jobs_with_details, using fallback');
        return await _getAllJobsFallback();
      }
      
      // Process the response to match expected format
      final jobs = List<Map<String, dynamic>>.from(response);
      
      for (final job in jobs) {
        // Transform company data to match old format
        job['companies'] = {
          'id': job['company_id'],
          'name': job['company_name'],
          'logo_url': job['company_logo_url'],
          'about': job['company_about'],
          'profile_url': job['company_profile_url'],
          'is_public': job['company_is_public'],
          'industry': job['company_industry'],
          'company_size': job['company_size'],
        };
        
        // job_types is already in JSONB array format from the procedure
        // Decode it from JSON if needed
        if (job['job_types'] is String) {
          job['job_types'] = jsonDecode(job['job_types']);
        }
        
        // Find primary job type
        final jobTypes = job['job_types'] as List?;
        job['primary_job_type'] = jobTypes?.firstWhere(
          (jt) => jt['is_primary'] == true,
          orElse: () => null,
        );
        
        // Remove individual company fields to keep clean structure
        job.remove('company_name');
        job.remove('company_logo_url');
        job.remove('company_about');
        job.remove('company_profile_url');
        job.remove('company_is_public');
        job.remove('company_industry');
        job.remove('company_size');
      }
      
      debugPrint('✅ Fetched ${jobs.length} jobs using optimized procedure');
      return jobs;
    } catch (e) {
      debugPrint('❌ Error fetching jobs with procedure: $e');
      debugPrint('⚠️ Falling back to traditional query');
      return await _getAllJobsFallback();
    }
  }

  // Fallback method using traditional query (in case procedure fails)
  static Future<List<Map<String, dynamic>>> _getAllJobsFallback() async {
    try {
      final response = await _supabase
          .from('jobs')
          .select('''
            *,
            companies (
              id,
              name,
              logo_url,
              about
            ),
            job_job_types (
              is_primary,
              job_types (
                id,
                name,
                display_name,
                description
              )
            )
          ''')
          .eq('status', 'open')
          .order('created_at', ascending: false);
      
      // Process the response to include job types in a more accessible format
      final jobs = List<Map<String, dynamic>>.from(response);
      for (final job in jobs) {
        final jobTypes = (job['job_job_types'] as List?)
            ?.map((jjt) => jjt['job_types'])
            .cast<Map<String, dynamic>>()
            .toList() ?? [];
        
        // Find primary job type
        final primaryJobType = (job['job_job_types'] as List?)
            ?.where((jjt) => jjt['is_primary'] == true)
            .map((jjt) => jjt['job_types'])
            .cast<Map<String, dynamic>>()
            .firstOrNull;
        
        job['job_types'] = jobTypes;
        job['primary_job_type'] = primaryJobType;
      }
      
      return jobs;
    } catch (e) {
      debugPrint('Error fetching jobs (fallback): $e');
      return [];
    }
  }

  // Get all jobs with saved status for user (SUPER OPTIMIZED - single query)
  static Future<List<Map<String, dynamic>>> getAllJobsWithSavedStatus(String userId) async {
    try {
      // Use super-optimized stored procedure that includes saved status
      final response = await _supabase.rpc('get_all_jobs_with_saved_status', 
        params: {'user_id_param': userId});
      
      if (response == null) {
        debugPrint('⚠️ No response from get_all_jobs_with_saved_status');
        return [];
      }
      
      // Process the response
      final jobs = List<Map<String, dynamic>>.from(response);
      
      for (final job in jobs) {
        // Transform company data to match expected format
        job['companies'] = {
          'id': job['company_id'],
          'name': job['company_name'],
          'logo_url': job['company_logo_url'],
          'about': job['company_about'],
          'profile_url': job['company_profile_url'],
          'is_public': job['company_is_public'],
          'industry': job['company_industry'],
          'company_size': job['company_size'],
        };
        
        // job_types is already in JSONB array format
        if (job['job_types'] is String) {
          job['job_types'] = jsonDecode(job['job_types']);
        }
        
        // Find primary job type
        final jobTypes = job['job_types'] as List?;
        job['primary_job_type'] = jobTypes?.firstWhere(
          (jt) => jt['is_primary'] == true,
          orElse: () => null,
        );
        
        // Remove individual company fields
        job.remove('company_name');
        job.remove('company_logo_url');
        job.remove('company_about');
        job.remove('company_profile_url');
        job.remove('company_is_public');
        job.remove('company_industry');
        job.remove('company_size');
      }
      
      debugPrint('✅ Fetched ${jobs.length} jobs with saved status in single query');
      return jobs;
    } catch (e) {
      debugPrint('❌ Error fetching jobs with saved status: $e');
      return [];
    }
  }

  // Get saved jobs in bulk (OPTIMIZED)
  static Future<Map<String, bool>> getSavedJobsMap(String userId) async {
    try {
      final response = await _supabase.rpc('get_saved_jobs_for_user',
        params: {'user_id_param': userId});
      
      if (response == null) return {};
      
      final savedJobsList = List<Map<String, dynamic>>.from(response);
      final savedJobsMap = <String, bool>{};
      
      for (final item in savedJobsList) {
        savedJobsMap[item['job_id'] as String] = true;
      }
      
      debugPrint('✅ Fetched ${savedJobsMap.length} saved jobs in single query');
      return savedJobsMap;
    } catch (e) {
      debugPrint('❌ Error fetching saved jobs map: $e');
      return {};
    }
  }

  // Get jobs cache timestamp for cache validation
  static Future<DateTime?> getJobsCacheTimestamp() async {
    try {
      final response = await _supabase.rpc('get_jobs_cache_timestamp');
      
      if (response == null) return null;
      
      return DateTime.parse(response as String);
    } catch (e) {
      debugPrint('❌ Error fetching cache timestamp: $e');
      return null;
    }
  }

  // Get jobs by company (for employers)
  static Future<List<Map<String, dynamic>>> getJobsByCompany(String companyId) async {
    try {
      final response = await _supabase
          .from('jobs')
          .select('''
            *,
            companies (
              id,
              name,
              logo_url,
              about
            )
          ''')
          .eq('company_id', companyId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching company jobs: $e');
      return [];
    }
  }

  // Get user's company
  static Future<Map<String, dynamic>?> getUserCompany(String userId) async {
    try {
      // 1) Prefer a company that already has jobs (so employer home shows postings)
      try {
        final withJobs = await _supabase
            .from('companies')
            .select('''
              *,
              jobs:jobs!inner (id)
            ''')
            .eq('owner_id', userId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (withJobs != null) {
          // Remove joined jobs field to keep original shape
          withJobs.remove('jobs');
          return withJobs;
        }
      } catch (_) {
        // Ignore and fallback below
      }

      // 2) Fallback: return the most recently created company for this owner
      final latest = await _supabase
          .from('companies')
          .select('*')
          .eq('owner_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      return latest;
    } catch (e) {
      debugPrint('Error fetching user company: $e');
      return null;
    }
  }

  // Create company if not exists
  static Future<Map<String, dynamic>?> createCompany({
    required String ownerId,
    required String name,
    String? about,
    String? logoUrl,
  }) async {
    try {
      final response = await _supabase
          .from('companies')
          .insert({
            'owner_id': ownerId,
            'name': name,
            'about': about,
            'logo_url': logoUrl,
          })
          .select()
          .single();
      
      return response;
    } catch (e) {
      debugPrint('Error creating company: $e');
      return null;
    }
  }

  // Update company
  static Future<Map<String, dynamic>?> updateCompany(String companyId, Map<String, dynamic> companyData) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('companies')
          .update({
            'name': companyData['name'],
            'about': companyData['about'],
            'logo_url': companyData['logo_url'],
            'is_public': companyData['is_public'] ?? true,
            'profile_url': companyData['profile_url'],
          })
          .eq('id', companyId)
          .eq('owner_id', user.id)
          .select()
          .single();
      
      return response;
    } catch (e) {
      debugPrint('Error updating company: $e');
      return null;
    }
  }

  // Create job posting with multiple job types
  static Future<Map<String, dynamic>?> createJob({
    required String companyId,
    required String title,
    required String description,
    required String location,
    required List<String> jobTypeIds,
    String? primaryJobTypeId,
    int? salaryMin,
    int? salaryMax,
    String? experienceLevel,
  }) async {
    try {
      // Start a transaction by creating the job first
      final response = await _supabase
          .from('jobs')
          .insert({
            'company_id': companyId,
            'title': title,
            'description': description,
            'location': location,
            'type': 'full_time', // Keep for backward compatibility, will be replaced by job_types
            'salary_min': salaryMin,
            'salary_max': salaryMax,
            'experience_level': experienceLevel,
            'status': 'open',
          })
          .select()
          .single();
      
      final jobId = response['id'];
      try {
        final user = _supabase.auth.currentUser;
        await AdminService.logEvent(
          actionType: 'job_created',
          targetUserId: user?.id,
          targetCompanyId: companyId,
          data: {'job_id': jobId, 'title': title},
        );
      } catch (_) {}
      
      // Add job types to the job
      if (jobTypeIds.isNotEmpty) {
        final jobJobTypesData = jobTypeIds.map((jobTypeId) => {
          'job_id': jobId,
          'job_type_id': jobTypeId,
          'is_primary': primaryJobTypeId == jobTypeId || (primaryJobTypeId == null && jobTypeId == jobTypeIds.first),
        }).toList();
        
        await _supabase
            .from('job_job_types')
            .insert(jobJobTypesData);
      }
      
      return response;
    } catch (e) {
      debugPrint('Error creating job: $e');
      return null;
    }
  }

  // Update job
  static Future<bool> updateJob({
    required String jobId,
    String? title,
    String? description,
    String? location,
    String? type,
    int? salaryMin,
    int? salaryMax,
    String? experienceLevel,
    String? status,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (location != null) updateData['location'] = location;
      if (type != null) updateData['type'] = type;
      if (salaryMin != null) updateData['salary_min'] = salaryMin;
      if (salaryMax != null) updateData['salary_max'] = salaryMax;
      if (experienceLevel != null) updateData['experience_level'] = experienceLevel;
      if (status != null) updateData['status'] = status;

      await _supabase
          .from('jobs')
          .update(updateData)
          .eq('id', jobId);
      try {
        await AdminService.logEvent(
          actionType: 'job_updated',
          data: {'job_id': jobId, 'updated_fields': updateData.keys.toList()},
        );
      } catch (_) {}
      
      return true;
    } catch (e) {
      debugPrint('Error updating job: $e');
      return false;
    }
  }

  // Archive job (move to archived_jobs table instead of deleting)
  static Future<bool> archiveJob(String jobId) async {
    try {
      await _supabase.rpc('archive_job', params: {'job_id_to_archive': jobId});
      try {
        await AdminService.logEvent(actionType: 'job_archived', data: {'job_id': jobId});
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Error archiving job: $e');
      return false;
    }
  }

  // Get archived jobs for a company
  static Future<List<Map<String, dynamic>>> getArchivedJobsByCompany(String companyId) async {
    try {
      final response = await _supabase
          .from('archived_jobs')
          .select('''
            *,
            companies (
              id,
              name,
              logo_url,
              about
            )
          ''')
          .eq('company_id', companyId)
          .order('archived_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching archived jobs: $e');
      return [];
    }
  }

  // Restore archived job
  static Future<bool> restoreArchivedJob(String archivedJobId) async {
    try {
      await _supabase.rpc('restore_archived_job', params: {'archived_job_id_to_restore': archivedJobId});
      try {
        await AdminService.logEvent(actionType: 'job_restored', data: {'archived_job_id': archivedJobId});
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Error restoring archived job: $e');
      return false;
    }
  }

  // Get single job by ID (for editing)
  static Future<Map<String, dynamic>?> getJobById(String jobId) async {
    try {
      final response = await _supabase
          .from('jobs')
          .select('''
            *,
            companies (
              id,
              name,
              logo_url,
              about
            )
          ''')
          .eq('id', jobId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      debugPrint('Error fetching job: $e');
      return null;
    }
  }

  // Apply for job with enhanced features
  static Future<Map<String, dynamic>?> applyForJob({
    required String jobId,
    required String applicantId,
    String? resumeUrl,
    String? resumeFilename,
    String? coverLetter,
    String? applicationNotes,
    String? applicationSource,
  }) async {
    try {
      // Get applicant profile for completeness score
      int profileCompletenessScore = 0;
      try {
        final profile = await _supabase
            .from('applicant_profile')
            .select('profile_completeness')
            .eq('user_id', applicantId)
            .maybeSingle();
        
        profileCompletenessScore = profile?['profile_completeness'] ?? 0;
      } catch (e) {
        debugPrint('Error fetching profile completeness: $e');
      }

      // Insert application with enhanced data
      final response = await _supabase
          .from('job_applications')
          .insert({
            'job_id': jobId,
            'applicant_id': applicantId,
            'resume_url': resumeUrl,
            'cover_letter': coverLetter,
            'application_notes': applicationNotes,
            'application_source': applicationSource ?? 'direct',
            'profile_completeness_score': profileCompletenessScore,
            'status': 'applied',
            'application_stage': 'applied',
            'ai_screening_triggered': false,
          })
          .select()
          .single();

      // Create initial tracking entry
      await _supabase
          .from('application_tracking')
          .insert({
            'application_id': response['id'],
            'status': 'applied',
            'notes': 'Application submitted',
            'updated_by': applicantId,
          });

      // Log application submission
      try {
        await AdminService.logEvent(
          actionType: 'application_submitted',
          targetUserId: applicantId,
          data: {'application_id': response['id'], 'job_id': jobId},
        );
      } catch (_) {}

      // Send notifications for successful application
      try {
        // Get job and employer details for notifications (derive employer via companies.owner_id)
        final jobDetails = await _supabase
            .from('jobs')
            .select('''
              title,
              companies (
                owner_id,
                name
              )
            ''')
            .eq('id', jobId)
            .single();

        final applicantProfile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', applicantId)
            .single();

        // Send notifications
        await OneSignalNotificationService.sendApplicationSubmittedNotification(
          applicantId: applicantId,
          employerId: jobDetails['companies']?['owner_id'] ?? '',
          jobId: jobId,
          jobTitle: jobDetails['title'],
          applicantName: applicantProfile['full_name'] ?? 'Unknown',
          applicationId: response['id'],
        );

        debugPrint('✅ Application notifications sent successfully');
      } catch (notificationError) {
        debugPrint('❌ Error sending application notifications: $notificationError');
        // Don't fail the application if notifications fail
      }

      return response;
    } catch (e) {
      debugPrint('Error applying for job: $e');
      return null;
    }
  }

  // Get job applications for a job (for employers) - Enhanced version
  static Future<List<Map<String, dynamic>>> getJobApplications(String jobId) async {
    try {
      // Use explicit foreign key reference with enhanced fields
      final response = await _supabase
          .from('job_applications')
          .select('''
            *,
            profiles!inner (
              id,
              full_name,
              email,
              phone_number,
              avatar_url
            ),
            jobs!inner (
              id,
              title,
              description,
              location,
              type,
              salary_min,
              salary_max,
              experience_level,
              companies (
                id,
                name,
                logo_url,
                about
              )
            )
          ''')
          .eq('job_id', jobId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching job applications: $e');
      return [];
    }
  }

  // Get user's applications (for applicants)
  static Future<List<Map<String, dynamic>>> getUserApplications(String userId) async {
    try {
      final response = await _supabase
          .from('job_applications')
          .select('''
            *,
            jobs (
              id,
              title,
              location,
              type,
              companies (
                name,
                logo_url
              )
            )
          ''')
          .eq('applicant_id', userId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching user applications: $e');
      return [];
    }
  }

  // Check if user has applied for job
  static Future<bool> hasUserApplied(String jobId, String userId) async {
    try {
      final response = await _supabase
          .from('job_applications')
          .select('id')
          .eq('job_id', jobId)
          .eq('applicant_id', userId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      debugPrint('Error checking application status: $e');
      return false;
    }
  }

  // Update application status (for employers)
  static Future<Map<String, dynamic>?> updateApplicationStatus({
    required String applicationId,
    required String newStatus,
    String? interviewScheduledAt,
    String? interviewNotes,
    int? employerRating,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get current application details before updating
      final currentApplication = await _supabase
          .from('job_applications')
          .select('''
            id,
            status,
            applicant_id,
            job_id,
            jobs (
              id,
              title,
              employer_id
            )
          ''')
          .eq('id', applicationId)
          .single();

      final oldStatus = currentApplication['status'];
      final applicantId = currentApplication['applicant_id'];
      final jobId = currentApplication['job_id'];
      final job = currentApplication['jobs'];
      final jobTitle = job['title'];

      final response = await _supabase.rpc('update_application_status', params: {
        'application_uuid': applicationId,
        'new_status': newStatus,
        'updated_by_uuid': user.id,
        'interview_scheduled_at': interviewScheduledAt,
        'interview_notes': interviewNotes,
        'employer_rating': employerRating,
      });

      if (response['success'] == true) {
        try {
          await AdminService.logEvent(
            actionType: 'application_status_updated',
            data: {
              'application_id': applicationId,
              'old': oldStatus,
              'new': newStatus,
            },
          );
        } catch (_) {}
        // Send notification to applicant about status update
        try {
          await OneSignalNotificationService.sendApplicationStatusUpdateNotification(
            applicantId: applicantId,
            jobId: jobId,
            jobTitle: jobTitle,
            oldStatus: oldStatus,
            newStatus: newStatus,
            applicationId: applicationId,
            message: interviewNotes,
            interviewDate: interviewScheduledAt != null ? DateTime.parse(interviewScheduledAt) : null,
          );

          debugPrint('✅ Application status update notification sent successfully');
        } catch (notificationError) {
          debugPrint('❌ Error sending status update notification: $notificationError');
          // Don't fail the status update if notifications fail
        }

        return {
          'success': true,
          'message': 'Application status updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to update status',
        };
      }
    } catch (e) {
      debugPrint('Error updating application status: $e');
      return {
        'success': false,
        'error': 'Failed to update application status: $e',
      };
    }
  }

  // Check if job is saved by user
  static Future<bool> isJobSaved(String jobId, String userId) async {
    try {
      final response = await _supabase
          .from('saved_jobs')
          .select('job_id')
          .eq('job_id', jobId)
          .eq('seeker_id', userId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      debugPrint('Error checking saved job status: $e');
      return false;
    }
  }

  // Save/unsave job
  static Future<bool> toggleSaveJob(String jobId, String userId) async {
    try {
      // Check if already saved
      final existing = await _supabase
          .from('saved_jobs')
          .select('seeker_id')
          .eq('job_id', jobId)
          .eq('seeker_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Remove from saved
        await _supabase
            .from('saved_jobs')
            .delete()
            .eq('job_id', jobId)
            .eq('seeker_id', userId);

        // Send notification for job unsave
        try {
          final jobDetails = await _supabase
              .from('jobs')
              .select('''
                title,
                companies (
                  owner_id
                )
              ''')
              .eq('id', jobId)
              .single();

          final applicantProfile = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', userId)
              .single();

          await OneSignalNotificationService.sendJobSaveNotification(
            applicantId: userId,
            employerId: jobDetails['companies']?['owner_id'] ?? '',
            jobId: jobId,
            jobTitle: jobDetails['title'],
            applicantName: applicantProfile['full_name'] ?? 'Unknown',
            isSaved: false,
          );

          debugPrint('✅ Job unsave notification sent successfully');
        } catch (notificationError) {
          debugPrint('❌ Error sending job unsave notification: $notificationError');
          // Don't fail the operation if notifications fail
        }

        return false; // Job unsaved
      } else {
        // Add to saved
        await _supabase
            .from('saved_jobs')
            .insert({
              'job_id': jobId,
              'seeker_id': userId,
            });

        // Send notification for job save
        try {
          final jobDetails = await _supabase
              .from('jobs')
              .select('''
                title,
                companies (
                  owner_id
                )
              ''')
              .eq('id', jobId)
              .single();

          final applicantProfile = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', userId)
              .single();

          await OneSignalNotificationService.sendJobSaveNotification(
            applicantId: userId,
            employerId: jobDetails['companies']?['owner_id'] ?? '',
            jobId: jobId,
            jobTitle: jobDetails['title'],
            applicantName: applicantProfile['full_name'] ?? 'Unknown',
            isSaved: true,
          );

          debugPrint('✅ Job save notification sent successfully');
        } catch (notificationError) {
          debugPrint('❌ Error sending job save notification: $notificationError');
          // Don't fail the operation if notifications fail
        }

        return true; // Job saved
      }
    } catch (e) {
      debugPrint('Error toggling save job: $e');
      return false;
    }
  }

  // Get applicant profile for application
  static Future<Map<String, dynamic>?> getApplicantProfile(String userId) async {
    try {
      final response = await _supabase
          .from('applicant_profile')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      debugPrint('Error fetching applicant profile: $e');
      return null;
    }
  }


  // Get application tracking history
  static Future<List<Map<String, dynamic>>> getApplicationTracking(String applicationId) async {
    try {
      final response = await _supabase
          .from('application_tracking')
          .select('''
            *,
            profiles!updated_by (
              full_name,
              email
            )
          ''')
          .eq('application_id', applicationId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching application tracking: $e');
      return [];
    }
  }

  // Upload file to Supabase Storage
  static Future<String?> uploadResume({
    required String userId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    try {
      final filePath = 'resumes/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      await _supabase.storage
          .from('resumes')
          .uploadBinary(filePath, fileBytes);
      
      final publicUrl = _supabase.storage
          .from('resumes')
          .getPublicUrl(filePath);
      
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading resume: $e');
      return null;
    }
  }

  // Generate personalized cover letter using AI
  static Future<String?> generatePersonalizedCoverLetter({
    required Map<String, dynamic> job,
    required Map<String, dynamic> applicantProfile,
  }) async {
    try {
      // Get AI service
      final aiService = _getAIService();
      if (aiService == null) {
        debugPrint('❌ AI service not available, falling back to template');
        return _generateTemplateCoverLetter(job, applicantProfile);
      }

      // Prepare data for AI generation
      final prompt = _buildCoverLetterPrompt(job, applicantProfile);
      
      // Generate cover letter using AI
      final response = await aiService.generateContent([Content.text(prompt)]);
      final generatedText = response.text;
      
      if (generatedText != null && generatedText.trim().isNotEmpty) {
        return generatedText.trim();
      } else {
        debugPrint('❌ AI generated empty response, falling back to template');
        return _generateTemplateCoverLetter(job, applicantProfile);
      }
    } catch (e) {
      debugPrint('❌ Error generating AI cover letter: $e');
      // Fallback to template if AI fails
      return _generateTemplateCoverLetter(job, applicantProfile);
    }
  }

  // Fallback template-based cover letter
  static String _generateTemplateCoverLetter(Map<String, dynamic> job, Map<String, dynamic> applicantProfile) {
    final companyName = job['companies']?['name'] ?? 'the company';
    final jobTitle = job['title'] ?? 'the position';
    final applicantName = applicantProfile['full_name'] ?? 'the applicant';
    final skills = (applicantProfile['skills'] as List?)?.join(', ') ?? '';
    final experience = applicantProfile['years_of_experience'] ?? 0;
    final location = job['location'] ?? '';
    
    return '''
Dear Hiring Manager,

I am writing to express my strong interest in the $jobTitle position at $companyName. With $experience years of experience in the field and expertise in $skills, I am confident that I would be a valuable addition to your team.

My background has equipped me with the skills necessary to excel in this role. I am particularly drawn to this opportunity because it aligns with my career goals and allows me to contribute to $companyName's continued success${location.isNotEmpty ? ' in $location' : ''}.

I would welcome the opportunity to discuss how my skills and experience can contribute to your team's objectives.

Sincerely,
$applicantName
    ''';
  }

  // Build comprehensive prompt for AI cover letter generation
  static String _buildCoverLetterPrompt(Map<String, dynamic> job, Map<String, dynamic> applicantProfile) {
    final companyName = job['companies']?['name'] ?? 'the company';
    final jobTitle = job['title'] ?? 'the position';
    final jobDescription = job['description'] ?? '';
    final location = job['location'] ?? '';
    final jobType = job['type'] ?? '';
    final salaryMin = job['salary_min'];
    final salaryMax = job['salary_max'];
    
    final applicantName = applicantProfile['full_name'] ?? 'the applicant';
    final email = applicantProfile['email'] ?? '';
    final phone = applicantProfile['phone'] ?? '';
    final skills = (applicantProfile['skills'] as List?)?.join(', ') ?? '';
    final experience = applicantProfile['years_of_experience'] ?? 0;
    final education = applicantProfile['education'] ?? '';
    final summary = applicantProfile['summary'] ?? '';
    final workExperience = applicantProfile['work_experience'] ?? '';
    
    return '''
Generate a professional, personalized cover letter for a job application. Use the following information:

JOB DETAILS:
- Position: $jobTitle
- Company: $companyName
- Location: $location
- Type: $jobType
- Description: $jobDescription
${salaryMin != null ? '- Salary Range: ₱${salaryMin.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} - ₱${salaryMax.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}' : ''}

APPLICANT PROFILE:
- Name: $applicantName
- Email: $email
- Phone: $phone
- Years of Experience: $experience
- Skills: $skills
- Education: $education
- Professional Summary: $summary
- Work Experience: $workExperience

REQUIREMENTS:
1. Write a professional cover letter (3-4 paragraphs)
2. Address it to "Dear Hiring Manager"
3. Mention specific skills and experiences that match the job requirements
4. Show enthusiasm for the company and position
5. Include a professional closing with the applicant's name
6. Keep it concise but compelling (200-300 words)
7. Use a professional, confident tone
8. Highlight relevant achievements and experiences
9. Mention why you're interested in this specific company/role
10. End with a call to action for an interview

Generate the cover letter now:
    ''';
  }

  // Get AI service instance - tries multiple models for free tier compatibility
  static GenerativeModel? _getAIService() {
    // List of models to try in order of preference for free tier
    final modelsToTry = [
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-pro',
      'gemini-2.5-flash',
    ];
    
    for (final modelName in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: AppConfig.geminiApiKey,
        );
        
        debugPrint('✅ Successfully initialized AI service with model: $modelName');
        return model;
      } catch (e) {
        debugPrint('❌ Failed to initialize model $modelName: $e');
        continue;
      }
    }
    
    debugPrint('❌ All AI models failed to initialize');
    return null;
  }

  /// Withdraw a job application using stored procedure for comprehensive tracking
  static Future<Map<String, dynamic>> withdrawApplication({
    required String applicationId,
    String? withdrawalReason,
    String? withdrawalCategory,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        return {
          'success': false,
          'error': 'User not authenticated',
          'code': 'AUTH_ERROR',
        };
      }

      debugPrint('🔄 Withdrawing application: $applicationId');

      // Call the database function for atomic withdrawal with tracking
      final response = await supabase.rpc(
        'withdraw_application',
        params: {
          'p_application_id': applicationId,
          'p_withdrawal_reason': withdrawalReason,
          'p_withdrawal_category': withdrawalCategory,
        },
      );

      debugPrint('📥 Withdrawal response: $response');

      // Parse the JSON response
      if (response is Map) {
        final success = response['success'] as bool? ?? false;
        
        if (success) {
          debugPrint('✅ Application withdrawn successfully: $applicationId');
          
          // Send notifications for successful withdrawal
          try {
            // Get application details for notifications
            final applicationDetails = await supabase
                .from('job_applications')
                .select('''
                  id,
                  applicant_id,
                  job_id,
                  jobs (
                    id,
                    title,
                    companies (
                      owner_id
                    )
                  )
                ''')
                .eq('id', applicationId)
                .single();

            final applicantId = applicationDetails['applicant_id'];
            final jobId = applicationDetails['job_id'];
            final job = applicationDetails['jobs'];
            final jobTitle = job['title'];
            final employerId = job['companies']?['owner_id'];

            // Get applicant profile for name
            final applicantProfile = await supabase
                .from('profiles')
                .select('full_name')
                .eq('id', applicantId)
                .single();

            // Send notifications
            await OneSignalNotificationService.sendApplicationWithdrawalNotification(
              applicantId: applicantId,
              employerId: employerId,
              jobId: jobId,
              jobTitle: jobTitle,
              applicantName: applicantProfile['full_name'] ?? 'Unknown',
              applicationId: applicationId,
              withdrawalReason: withdrawalReason ?? 'No reason provided',
              withdrawalCategory: withdrawalCategory,
            );

            debugPrint('✅ Application withdrawal notifications sent successfully');
          } catch (notificationError) {
            debugPrint('❌ Error sending withdrawal notifications: $notificationError');
            // Don't fail the withdrawal if notifications fail
          }

          return {
            'success': true,
            'message': response['message'] ?? 'Application withdrawn successfully',
            'applicationId': response['applicationId'],
            'withdrawnAt': response['withdrawnAt'],
          };
        } else {
          debugPrint('❌ Withdrawal failed: ${response['error']}');
          return {
            'success': false,
            'error': response['error'] ?? 'Unknown error',
            'code': response['code'] ?? 'UNKNOWN_ERROR',
          };
        }
      } else {
        debugPrint('❌ Unexpected response format: $response');
        return {
          'success': false,
          'error': 'Unexpected response from server',
          'code': 'INVALID_RESPONSE',
        };
      }
    } catch (e) {
      debugPrint('❌ Error withdrawing application: $e');
      return {
        'success': false,
        'error': 'Failed to withdraw application: ${e.toString()}',
        'code': 'SYSTEM_ERROR',
      };
    }
  }

  /// Get withdrawal statistics for admin/analytics
  static Future<Map<String, dynamic>> getWithdrawalStatistics({
    String? jobId,
    String? employerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      
      var query = supabase
          .from('withdrawal_tracking')
          .select('*');
      
      if (jobId != null) {
        query = query.eq('job_id', jobId);
      }
      
      if (employerId != null) {
        query = query.eq('employer_id', employerId);
      }
      
      if (startDate != null) {
        query = query.gte('withdrawn_at', startDate.toIso8601String());
      }
      
      if (endDate != null) {
        query = query.lte('withdrawn_at', endDate.toIso8601String());
      }
      
      final response = await query;
      final withdrawals = List<Map<String, dynamic>>.from(response);
      
      // Calculate statistics
      final totalWithdrawals = withdrawals.length;
      final categoryBreakdown = <String, int>{};
      final averageDaysSinceApplication = withdrawals.isNotEmpty
          ? withdrawals.map((w) => w['days_since_application'] as int? ?? 0)
              .reduce((a, b) => a + b) / withdrawals.length
          : 0.0;
      
      for (final withdrawal in withdrawals) {
        final category = withdrawal['withdrawal_category'] as String? ?? 'Other';
        categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + 1;
      }
      
      return {
        'total_withdrawals': totalWithdrawals,
        'category_breakdown': categoryBreakdown,
        'average_days_since_application': averageDaysSinceApplication,
        'withdrawals': withdrawals,
      };
    } catch (e) {
      debugPrint('❌ Error fetching withdrawal statistics: $e');
      return {
        'total_withdrawals': 0,
        'category_breakdown': {},
        'average_days_since_application': 0.0,
        'withdrawals': [],
      };
    }
  }

  /// Fetch all applications for a company with optimized stored procedure
  static Future<List<Map<String, dynamic>>> getCompanyApplicationsOptimized(String companyId) async {
    try {
      final response = await _supabase
          .rpc('get_company_applications_with_details', params: {'p_company_id': companyId})
          .select();
      
      final List<Map<String, dynamic>> applications = [];
      
      for (final row in response as List) {
        final application = Map<String, dynamic>.from(row['application_data'] ?? {});
        final job = Map<String, dynamic>.from(row['job_data'] ?? {});
        final profile = Map<String, dynamic>.from(row['applicant_profile'] ?? {});
        final aiData = row['ai_screening_data'];
        
        // Decode JSONB arrays if they're strings
        if (job['job_types'] is String) {
          job['job_types'] = jsonDecode(job['job_types']);
        }
        
        // Merge all data into application object
        application['job'] = job;
        application['profiles'] = profile;
        if (aiData != null) {
          application['ai_screening'] = Map<String, dynamic>.from(aiData);
        }
        
        applications.add(application);
      }
      
      return applications;
    } catch (e) {
      debugPrint('Error fetching optimized company applications: $e');
      return [];
    }
  }
}
