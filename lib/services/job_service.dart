import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:typed_data';
import '../config/app_config.dart';

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

      final response = await _supabase.rpc('update_application_status', params: {
        'application_uuid': applicationId,
        'new_status': newStatus,
        'updated_by_uuid': user.id,
        'interview_scheduled_at': interviewScheduledAt,
        'interview_notes': interviewNotes,
        'employer_rating': employerRating,
      });

      if (response['success'] == true) {
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

  /// Withdraw a job application
  static Future<bool> withdrawApplication({
    required String applicationId,
    String? withdrawalReason,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Update application status to 'withdrawn'
      final response = await supabase
          .from('job_applications')
          .update({
            'status': 'withdrawn',
            'withdrawal_reason': withdrawalReason,
            'withdrawn_at': DateTime.now().toIso8601String(),
          })
          .eq('id', applicationId);

      if (response.error != null) {
        debugPrint('❌ Failed to withdraw application: ${response.error}');
        return false;
      }

      debugPrint('✅ Application withdrawn successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error withdrawing application: $e');
      return false;
    }
  }
}
