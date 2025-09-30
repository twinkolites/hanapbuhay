import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JobService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get all jobs
  static Future<List<Map<String, dynamic>>> getAllJobs() async {
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
          .eq('status', 'open')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      return [];
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
      final response = await _supabase
          .from('companies')
          .select('*')
          .eq('owner_id', userId)
          .maybeSingle();
      
      return response;
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

  // Create job posting
  static Future<Map<String, dynamic>?> createJob({
    required String companyId,
    required String title,
    required String description,
    required String location,
    required String type,
    int? salaryMin,
    int? salaryMax,
    String? experienceLevel,
  }) async {
    try {
      final response = await _supabase
          .from('jobs')
          .insert({
            'company_id': companyId,
            'title': title,
            'description': description,
            'location': location,
            'type': type,
            'salary_min': salaryMin,
            'salary_max': salaryMax,
            'experience_level': experienceLevel,
            'status': 'open',
          })
          .select()
          .single();
      
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

  // Apply for job
  static Future<bool> applyForJob({
    required String jobId,
    required String applicantId,
    String? resumeUrl,
    String? coverLetter,
  }) async {
    try {
      await _supabase
          .from('job_applications')
          .insert({
            'job_id': jobId,
            'applicant_id': applicantId,
            'resume_url': resumeUrl,
            'cover_letter': coverLetter,
            'status': 'applied',
          });
      
      return true;
    } catch (e) {
      debugPrint('Error applying for job: $e');
      return false;
    }
  }

  // Get job applications for a job (for employers)
  static Future<List<Map<String, dynamic>>> getJobApplications(String jobId) async {
    try {
      final response = await _supabase
          .from('job_applications')
          .select('''
            *,
            profiles!job_applications_applicant_id_fkey (
              user_id,
              first_name,
              last_name,
              email,
              phone,
              profile_picture_url
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
        return false; // Job unsaved
      } else {
        // Add to saved
        await _supabase
            .from('saved_jobs')
            .insert({
              'job_id': jobId,
              'seeker_id': userId,
            });
        return true; // Job saved
      }
    } catch (e) {
      debugPrint('Error toggling save job: $e');
      return false;
    }
  }

  // Get saved jobs
  static Future<List<Map<String, dynamic>>> getSavedJobs(String userId) async {
    try {
      final response = await _supabase
          .from('saved_jobs')
          .select('''
            *,
            jobs (
              *,
              companies (
                id,
                name,
                logo_url,
                about
              )
            )
          ''')
          .eq('seeker_id', userId)
          .order('saved_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching saved jobs: $e');
      return [];
    }
  }
}
