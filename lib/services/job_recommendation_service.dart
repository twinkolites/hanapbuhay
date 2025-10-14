import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/app_config.dart';
import 'onesignal_notification_service.dart';

class JobRecommendationService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static late final GenerativeModel _model;
  static bool _isInitialized = false;

  // Initialize AI model for recommendations
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final modelsToTry = [
        'gemini-2.5-flash',
        'gemini-1.5-flash',
        'gemini-1.5-pro',
        'gemini-pro',
      ];
      
      GenerativeModel? model;
      String? successfulModel;
      
      for (final modelName in modelsToTry) {
        try {
          if (AppConfig.geminiApiKey.isEmpty) {
            debugPrint('❌ Gemini API key is empty');
            continue;
          }
          
          model = GenerativeModel(
            model: modelName,
            apiKey: AppConfig.geminiApiKey,
          );
          
          // Test the model
          final testContent = [Content.text('Test recommendation')];
          final testResponse = await model.generateContent(testContent);
          
          if (testResponse.text != null) {
            successfulModel = modelName;
            debugPrint('✅ Job Recommendation Service initialized with model: $modelName');
            break;
          }
        } catch (e) {
          debugPrint('❌ Failed to initialize model $modelName: $e');
          continue;
        }
      }
      
      if (model != null && successfulModel != null) {
        _model = model;
        _isInitialized = true;
      } else {
        debugPrint('❌ All AI models failed to initialize for recommendations');
      }
    } catch (e) {
      debugPrint('❌ Error initializing Job Recommendation Service: $e');
    }
  }

  // Get personalized job recommendations
  static Future<List<Map<String, dynamic>>> getPersonalizedRecommendations({
    required String userId,
    int limit = 10,
    bool useAI = true,
  }) async {
    try {
      // Get user profile and preferences
      final profile = await _getUserProfile(userId);
      if (profile == null) {
        debugPrint('❌ User profile not found');
        return await _getFallbackRecommendations(limit);
      }

      // Get all available jobs
      final allJobs = await _supabase
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

      if (allJobs.isEmpty) {
        return [];
      }

      if (useAI && _isInitialized) {
        // Use AI for intelligent recommendations
        return await _getAIRecommendations(profile, allJobs, limit);
      } else {
        // Use rule-based recommendations as fallback
        return await _getRuleBasedRecommendations(profile, allJobs, limit);
      }
    } catch (e) {
      debugPrint('❌ Error getting personalized recommendations: $e');
      return await _getFallbackRecommendations(limit);
    }
  }

  // Get user profile with preferences
  static Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('applicant_profile')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      return null;
    }
  }

  // AI-powered job recommendations
  static Future<List<Map<String, dynamic>>> _getAIRecommendations(
    Map<String, dynamic> profile,
    List<dynamic> allJobs,
    int limit,
  ) async {
    try {
      final prompt = _buildRecommendationPrompt(profile, allJobs);
      
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      final responseText = response.text ?? '[]';
      debugPrint('🔍 AI Recommendation Response: $responseText');
      
      // Parse JSON response
      final jsonStart = responseText.indexOf('[');
      final jsonEnd = responseText.lastIndexOf(']') + 1;
      
      if (jsonStart == -1 || jsonEnd == 0) {
        debugPrint('❌ No valid JSON array found in AI response');
        return await _getRuleBasedRecommendations(profile, allJobs, limit);
      }
      
      final jsonString = responseText.substring(jsonStart, jsonEnd);
      final recommendedJobIds = jsonDecode(jsonString) as List<dynamic>;
      
      // Filter jobs based on AI recommendations - return only AI recommended jobs
      final recommendedJobs = <Map<String, dynamic>>[];
      for (final jobId in recommendedJobIds) {
        try {
          final job = allJobs.firstWhere(
            (job) => job['id'] == jobId,
          );
          recommendedJobs.add(Map<String, dynamic>.from(job));
        } catch (e) {
          // Job not found, skip it
          debugPrint('⚠️ Job with ID $jobId not found in available jobs');
        }
      }
      
      debugPrint('🎯 AI recommended ${recommendedJobs.length} jobs out of ${recommendedJobIds.length} requested');
      
      return recommendedJobs;
    } catch (e) {
      debugPrint('❌ Error in AI recommendations: $e');
      return await _getRuleBasedRecommendations(profile, allJobs, limit);
    }
  }

  // Build comprehensive prompt for AI recommendations
  static String _buildRecommendationPrompt(
    Map<String, dynamic> profile,
    List<dynamic> allJobs,
  ) {
    final skills = (profile['skills'] as List?)?.join(', ') ?? '';
    final experience = profile['years_of_experience'] ?? 0;
    final location = profile['location'] ?? '';
    final education = (profile['education'] as List?)?.map((e) => e['degree']).join(', ') ?? '';
    final workExperience = (profile['work_experience'] as List?)?.map((e) => e['title']).join(', ') ?? '';
    final jobInterests = (profile['job_interests'] as List?)?.join(', ') ?? '';
    final preferredIndustries = (profile['preferred_industries'] as List?)?.join(', ') ?? '';
    
    final jobsData = allJobs.map((job) => {
      'id': job['id'],
      'title': job['title'],
      'description': job['description'],
      'location': job['location'],
      'type': job['type'],
      'experience_level': job['experience_level'],
      'salary_min': job['salary_min'],
      'salary_max': job['salary_max'],
      'company': job['companies']?['name'],
    }).toList();

    return '''
Analyze this job seeker's profile and recommend the most suitable jobs from the available positions.

JOB SEEKER PROFILE:
- Skills: $skills
- Years of Experience: $experience
- Location: $location
- Education: $education
- Work Experience: $workExperience
- Job Interests: $jobInterests
- Preferred Industries: $preferredIndustries

AVAILABLE JOBS:
${jsonEncode(jobsData)}

RECOMMENDATION CRITERIA:
1. Skills Match: How well do the job requirements match the candidate's skills?
2. Experience Level: Is the candidate's experience appropriate for the role?
3. Location Preference: Consider location compatibility
4. Career Progression: Does the role offer growth opportunities?
5. Industry Interest: Does it align with preferred industries?
6. Salary Expectations: Consider salary range compatibility
7. Job Type: Full-time, part-time, remote preferences

TASK:
Return a JSON array of job IDs in order of recommendation priority (best match first).
Format: ["job_id_1", "job_id_2", "job_id_3", ...]

Consider both technical fit and career development potential. Prioritize jobs that:
- Match the candidate's core skills
- Offer appropriate challenge level
- Align with career interests
- Provide growth opportunities
- Match location preferences

Return only the JSON array, no additional text:
''';
  }

  // Rule-based recommendations as fallback
  static Future<List<Map<String, dynamic>>> _getRuleBasedRecommendations(
    Map<String, dynamic> profile,
    List<dynamic> allJobs,
    int limit,
  ) async {
    try {
      final scoredJobs = <Map<String, dynamic>>[];
      
      for (final job in allJobs) {
        double score = 0.0;
        
        // Skills matching (40% weight)
        final jobSkills = _extractSkillsFromJob(job);
        final userSkills = (profile['skills'] as List?) ?? [];
        final skillMatch = _calculateSkillMatch(userSkills, jobSkills);
        score += skillMatch * 0.4;
        
        // Experience level matching (25% weight)
        final experienceMatch = _calculateExperienceMatch(
          profile['years_of_experience'] ?? 0,
          job['experience_level'],
        );
        score += experienceMatch * 0.25;
        
        // Location matching (20% weight)
        final locationMatch = _calculateLocationMatch(
          profile['location'],
          job['location'],
        );
        score += locationMatch * 0.2;
        
        // Job type preference (15% weight)
        final typeMatch = _calculateTypeMatch(profile, job['type']);
        score += typeMatch * 0.15;
        
        scoredJobs.add({
          ...Map<String, dynamic>.from(job),
          'recommendation_score': score,
        });
      }
      
      // Sort by score and return top recommendations
      scoredJobs.sort((a, b) => 
        (b['recommendation_score'] as double).compareTo(a['recommendation_score'] as double));
      
      return scoredJobs.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error in rule-based recommendations: $e');
      return [];
    }
  }

  // Extract skills from job description
  static List<String> _extractSkillsFromJob(Map<String, dynamic> job) {
    final description = job['description']?.toString().toLowerCase() ?? '';
    final title = job['title']?.toString().toLowerCase() ?? '';
    final experienceLevel = job['experience_level']?.toString().toLowerCase() ?? '';
    
    // Common tech skills to look for
    final techSkills = [
      'flutter', 'dart', 'react', 'javascript', 'typescript', 'python', 'java',
      'node.js', 'angular', 'vue', 'php', 'ruby', 'swift', 'kotlin', 'c++',
      'c#', 'go', 'rust', 'sql', 'mongodb', 'postgresql', 'mysql', 'redis',
      'aws', 'azure', 'gcp', 'docker', 'kubernetes', 'git', 'ci/cd',
      'machine learning', 'ai', 'data science', 'analytics', 'blockchain',
    ];
    
    final foundSkills = <String>[];
    for (final skill in techSkills) {
      if (description.contains(skill) || title.contains(skill) || experienceLevel.contains(skill)) {
        foundSkills.add(skill);
      }
    }
    
    return foundSkills;
  }

  // Calculate skill match percentage
  static double _calculateSkillMatch(List<dynamic> userSkills, List<String> jobSkills) {
    if (userSkills.isEmpty || jobSkills.isEmpty) return 0.0;
    
    final userSkillsLower = userSkills.map((s) => s.toString().toLowerCase()).toList();
    final jobSkillsLower = jobSkills.map((s) => s.toLowerCase()).toList();
    
    int matches = 0;
    for (final userSkill in userSkillsLower) {
      if (jobSkillsLower.any((jobSkill) => 
        jobSkill.contains(userSkill) || userSkill.contains(jobSkill))) {
        matches++;
      }
    }
    
    return matches / userSkills.length;
  }

  // Calculate experience level match
  static double _calculateExperienceMatch(int userExperience, String? jobExperienceLevel) {
    if (jobExperienceLevel == null) return 0.5;
    
    final level = jobExperienceLevel.toLowerCase();
    
    if (level.contains('entry') || level.contains('junior')) {
      return userExperience <= 2 ? 1.0 : 0.7;
    } else if (level.contains('mid') || level.contains('intermediate')) {
      return userExperience >= 2 && userExperience <= 5 ? 1.0 : 0.6;
    } else if (level.contains('senior') || level.contains('lead')) {
      return userExperience >= 5 ? 1.0 : 0.4;
    } else if (level.contains('executive') || level.contains('director')) {
      return userExperience >= 8 ? 1.0 : 0.2;
    }
    
    return 0.5; // Default match
  }

  // Calculate location match
  static double _calculateLocationMatch(String? userLocation, String? jobLocation) {
    if (userLocation == null || jobLocation == null) return 0.5;
    
    final userLoc = userLocation.toLowerCase();
    final jobLoc = jobLocation.toLowerCase();
    
    if (jobLoc.contains('remote')) return 1.0;
    if (userLoc.contains(jobLoc) || jobLoc.contains(userLoc)) return 1.0;
    
    return 0.3; // Partial match for different locations
  }

  // Calculate job type match
  static double _calculateTypeMatch(Map<String, dynamic> profile, String? jobType) {
    if (jobType == null) return 0.5;
    
    // For now, return neutral score - can be enhanced with user preferences
    return 0.5;
  }

  // Fallback recommendations (most recent jobs)
  static Future<List<Map<String, dynamic>>> _getFallbackRecommendations(int limit) async {
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
          .order('created_at', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting fallback recommendations: $e');
      return [];
    }
  }

  // Update user job preferences
  static Future<bool> updateJobPreferences({
    required String userId,
    List<String>? jobInterests,
    List<String>? preferredIndustries,
    List<String>? preferredSkills,
    Map<String, dynamic>? feedback,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'last_recommendation_update': DateTime.now().toIso8601String(),
      };
      
      if (jobInterests != null) updateData['job_interests'] = jobInterests;
      if (preferredIndustries != null) updateData['preferred_industries'] = preferredIndustries;
      if (preferredSkills != null) updateData['preferred_skills'] = preferredSkills;
      if (feedback != null) updateData['job_preference_feedback'] = feedback;
      
      await _supabase
          .from('applicant_profile')
          .update(updateData)
          .eq('user_id', userId);
      
      debugPrint('✅ Job preferences updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating job preferences: $e');
      return false;
    }
  }

  // Send notification for new job recommendations
  static Future<bool> sendJobRecommendationNotifications({
    required String userId,
    required List<Map<String, dynamic>> recommendations,
    int maxNotifications = 3,
  }) async {
    try {
      if (recommendations.isEmpty) return false;

      // Send notifications for top recommendations
      final topRecommendations = recommendations.take(maxNotifications).toList();
      
      for (final job in topRecommendations) {
        final matchScore = job['recommendation_score']?.toDouble() ?? 0.0;
        
        // Only send notification for high-quality matches (score > 0.7)
        if (matchScore > 0.7) {
          await OneSignalNotificationService.sendJobRecommendationNotification(
            applicantId: userId,
            jobId: job['id'],
            jobTitle: job['title'],
            companyName: job['companies']['name'] ?? 'Unknown Company',
            matchScore: matchScore,
          );
        }
      }

      debugPrint('✅ Job recommendation notifications sent successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending job recommendation notifications: $e');
      return false;
    }
  }

  // Record recommendation feedback
  static Future<bool> recordRecommendationFeedback({
    required String userId,
    required String jobId,
    required String feedbackType, // 'liked', 'disliked', 'applied', 'ignored'
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final feedback = {
        'job_id': jobId,
        'feedback_type': feedbackType,
        'timestamp': DateTime.now().toIso8601String(),
        'additional_data': additionalData ?? {},
      };
      
      // Get current feedback data
      final profile = await _getUserProfile(userId);
      final currentFeedback = (profile?['job_preference_feedback'] as Map<String, dynamic>?) ?? {};
      final feedbackList = (currentFeedback['feedback_history'] as List?) ?? [];
      
      // Add new feedback
      feedbackList.add(feedback);
      
      // Update profile
      await _supabase
          .from('applicant_profile')
          .update({
            'job_preference_feedback': {
              ...currentFeedback,
              'feedback_history': feedbackList,
              'last_feedback_update': DateTime.now().toIso8601String(),
            },
          })
          .eq('user_id', userId);
      
      debugPrint('✅ Recommendation feedback recorded');
      return true;
    } catch (e) {
      debugPrint('❌ Error recording feedback: $e');
      return false;
    }
  }

  // Get recommendation insights
  static Future<Map<String, dynamic>> getRecommendationInsights(String userId) async {
    try {
      final profile = await _getUserProfile(userId);
      if (profile == null) return {};
      
      final feedback = profile['job_preference_feedback'] as Map<String, dynamic>? ?? {};
      final feedbackHistory = feedback['feedback_history'] as List? ?? [];
      
      // Calculate insights
      int totalFeedback = feedbackHistory.length;
      int likedJobs = feedbackHistory.where((f) => f['feedback_type'] == 'liked').length;
      int appliedJobs = feedbackHistory.where((f) => f['feedback_type'] == 'applied').length;
      
      return {
        'total_recommendations_viewed': totalFeedback,
        'liked_recommendations': likedJobs,
        'applied_from_recommendations': appliedJobs,
        'recommendation_accuracy': totalFeedback > 0 ? (likedJobs / totalFeedback) : 0.0,
        'conversion_rate': totalFeedback > 0 ? (appliedJobs / totalFeedback) : 0.0,
        'last_updated': profile['last_recommendation_update'],
      };
    } catch (e) {
      debugPrint('❌ Error getting recommendation insights: $e');
      return {};
    }
  }
}
