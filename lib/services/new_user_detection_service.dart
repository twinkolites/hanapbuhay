import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewUserDetectionService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _newUserKey = 'is_new_user';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _firstLoginKey = 'first_login_timestamp';

  /// Check if the current user is new (first time logging in)
  static Future<bool> isNewUser(String userId) async {
    try {
      // Check local storage first for performance
      final prefs = await SharedPreferences.getInstance();
      final localNewUserFlag = prefs.getBool('${_newUserKey}_$userId');
      
      if (localNewUserFlag != null) {
        return localNewUserFlag;
      }

      // Check if user has completed onboarding
      final onboardingCompleted = prefs.getBool('${_onboardingCompletedKey}_$userId') ?? false;
      if (onboardingCompleted) {
        await prefs.setBool('${_newUserKey}_$userId', false);
        return false;
      }

      // Check database for user profile completeness
      final profile = await _supabase
          .from('applicant_profile')
          .select('user_id, job_interests, preferred_industries, preferred_skills, created_at')
          .eq('user_id', userId)
          .maybeSingle();

      // Check if user has any job preferences set
      final hasPreferences = profile != null && 
          ((profile['job_interests'] as List?)?.isNotEmpty == true ||
           (profile['preferred_industries'] as List?)?.isNotEmpty == true ||
           (profile['preferred_skills'] as List?)?.isNotEmpty == true);

      // Check if user has been active for more than 24 hours (not truly new)
      final createdAt = profile?['created_at'];
      bool isRecentlyCreated = true;
      
      if (createdAt != null) {
        final createdDate = DateTime.parse(createdAt);
        final now = DateTime.now();
        isRecentlyCreated = now.difference(createdDate).inHours < 24;
      }

      // User is considered new if:
      // 1. No preferences set AND recently created, OR
      // 2. No onboarding completion flag
      final isNew = (!hasPreferences && isRecentlyCreated) || !onboardingCompleted;

      // Cache the result locally
      await prefs.setBool('${_newUserKey}_$userId', isNew);
      
      debugPrint('🔍 New user check for $userId: $isNew (hasPreferences: $hasPreferences, recentlyCreated: $isRecentlyCreated)');
      
      return isNew;
    } catch (e) {
      debugPrint('❌ Error checking if user is new: $e');
      // Default to true (show onboarding) if we can't determine
      return true;
    }
  }

  /// Mark user as having completed onboarding
  static Future<void> markOnboardingCompleted(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Set local flags
      await prefs.setBool('${_newUserKey}_$userId', false);
      await prefs.setBool('${_onboardingCompletedKey}_$userId', true);
      await prefs.setString('${_firstLoginKey}_$userId', DateTime.now().toIso8601String());
      
      debugPrint('✅ Onboarding marked as completed for user: $userId');
    } catch (e) {
      debugPrint('❌ Error marking onboarding as completed: $e');
    }
  }

  /// Check if user has completed onboarding
  static Future<bool> hasCompletedOnboarding(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('${_onboardingCompletedKey}_$userId') ?? false;
    } catch (e) {
      debugPrint('❌ Error checking onboarding completion: $e');
      return false;
    }
  }

  /// Reset onboarding status (useful for testing or if user wants to redo onboarding)
  static Future<void> resetOnboardingStatus(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove('${_newUserKey}_$userId');
      await prefs.remove('${_onboardingCompletedKey}_$userId');
      await prefs.remove('${_firstLoginKey}_$userId');
      
      debugPrint('🔄 Onboarding status reset for user: $userId');
    } catch (e) {
      debugPrint('❌ Error resetting onboarding status: $e');
    }
  }

  /// Get onboarding completion timestamp
  static Future<DateTime?> getOnboardingCompletionTime(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString('${_firstLoginKey}_$userId');
      return timestamp != null ? DateTime.parse(timestamp) : null;
    } catch (e) {
      debugPrint('❌ Error getting onboarding completion time: $e');
      return null;
    }
  }

  /// Check if user should see onboarding based on multiple factors
  static Future<bool> shouldShowOnboarding(String userId) async {
    try {
      // Check if user is new
      final isNew = await isNewUser(userId);
      
      // Check if onboarding was completed
      final completed = await hasCompletedOnboarding(userId);
      
      // Check if user has any job preferences
      final profile = await _supabase
          .from('applicant_profile')
          .select('job_interests, preferred_industries, preferred_skills')
          .eq('user_id', userId)
          .maybeSingle();

      final hasPreferences = profile != null && 
          ((profile['job_interests'] as List?)?.isNotEmpty == true ||
           (profile['preferred_industries'] as List?)?.isNotEmpty == true ||
           (profile['preferred_skills'] as List?)?.isNotEmpty == true);

      // Show onboarding if:
      // 1. User is new AND hasn't completed onboarding, OR
      // 2. User hasn't completed onboarding AND has no preferences
      final shouldShow = (isNew && !completed) || (!completed && !hasPreferences);
      
      debugPrint('🎯 Should show onboarding for $userId: $shouldShow (isNew: $isNew, completed: $completed, hasPreferences: $hasPreferences)');
      
      return shouldShow;
    } catch (e) {
      debugPrint('❌ Error checking if should show onboarding: $e');
      return true; // Default to showing onboarding if we can't determine
    }
  }

  /// Get user onboarding status summary
  static Future<Map<String, dynamic>> getOnboardingStatus(String userId) async {
    try {
      final isNew = await isNewUser(userId);
      final completed = await hasCompletedOnboarding(userId);
      final completionTime = await getOnboardingCompletionTime(userId);
      
      // Check preferences
      final profile = await _supabase
          .from('applicant_profile')
          .select('job_interests, preferred_industries, preferred_skills')
          .eq('user_id', userId)
          .maybeSingle();

      final hasPreferences = profile != null && 
          ((profile['job_interests'] as List?)?.isNotEmpty == true ||
           (profile['preferred_industries'] as List?)?.isNotEmpty == true ||
           (profile['preferred_skills'] as List?)?.isNotEmpty == true);

      return {
        'isNewUser': isNew,
        'hasCompletedOnboarding': completed,
        'hasJobPreferences': hasPreferences,
        'completionTime': completionTime?.toIso8601String(),
        'shouldShowOnboarding': (isNew && !completed) || (!completed && !hasPreferences),
      };
    } catch (e) {
      debugPrint('❌ Error getting onboarding status: $e');
      return {
        'isNewUser': true,
        'hasCompletedOnboarding': false,
        'hasJobPreferences': false,
        'completionTime': null,
        'shouldShowOnboarding': true,
      };
    }
  }

  /// Check if user should be prompted to update preferences (even if not new)
  static Future<bool> shouldPromptForPreferences(String userId) async {
    try {
      // Check if user has any job preferences
      final profile = await _supabase
          .from('applicant_profile')
          .select('job_interests, preferred_industries, preferred_skills')
          .eq('user_id', userId)
          .maybeSingle();

      final hasPreferences = profile != null && 
          ((profile['job_interests'] as List?)?.isNotEmpty == true ||
           (profile['preferred_industries'] as List?)?.isNotEmpty == true ||
           (profile['preferred_skills'] as List?)?.isNotEmpty == true);

      // Prompt if user has no preferences at all
      return !hasPreferences;
    } catch (e) {
      debugPrint('❌ Error checking if should prompt for preferences: $e');
      return true; // Default to prompting if we can't determine
    }
  }

  /// Force show onboarding for testing or admin purposes
  static Future<void> forceShowOnboarding(String userId) async {
    try {
      await resetOnboardingStatus(userId);
      debugPrint('🔄 Forced onboarding reset for user: $userId');
    } catch (e) {
      debugPrint('❌ Error forcing onboarding: $e');
    }
  }

  /// Track user onboarding progress
  static Future<void> trackOnboardingProgress({
    required String userId,
    required String step,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.from('audit_log').insert({
        'user_id': userId,
        'operation': 'onboarding_progress',
        'table_name': 'user_onboarding',
        'record_id': userId,
        'new_data': {
          'step': step,
          'timestamp': DateTime.now().toIso8601String(),
          'data': data ?? {},
        },
        'created_at': DateTime.now().toIso8601String(),
      });
      
      debugPrint('📊 Onboarding progress tracked: $step for user $userId');
    } catch (e) {
      debugPrint('❌ Error tracking onboarding progress: $e');
    }
  }

}