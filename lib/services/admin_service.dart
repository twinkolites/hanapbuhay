import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';

class AdminService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get dashboard statistics for admin
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Get user counts by role
      final userStats = await _supabase
          .from('profiles')
          .select('role')
          .then((profiles) {
        int totalUsers = profiles.length;
        int totalEmployers = profiles.where((p) => p['role'] == 'employer').length;
        int totalApplicants = profiles.where((p) => p['role'] == 'applicant').length;
        
        return {
          'total_users': totalUsers,
          'total_employers': totalEmployers,
          'total_applicants': totalApplicants,
        };
      });

      // Get job statistics
      final jobStats = await _supabase
          .from('jobs')
          .select('id, status')
          .then((jobs) {
        int totalJobs = jobs.length;
        int activeJobs = jobs.where((j) => j['status'] == 'open').length;
        
        return {
          'total_jobs': totalJobs,
          'active_jobs': activeJobs,
        };
      });

      // Get application statistics
      final applicationStats = await _supabase
          .from('job_applications')
          .select('id, status')
          .then((applications) {
        int totalApplications = applications.length;
        int pendingApplications = applications.where((a) => a['status'] == 'applied').length;
        
        return {
          'total_applications': totalApplications,
          'pending_applications': pendingApplications,
        };
      });

      // Get pending approvals (if employer_verification table exists)
      int pendingApprovals = 0;
      try {
        final pendingCount = await _supabase
            .from('employer_verification')
            .select('id')
            .eq('verification_status', 'pending')
            .then((verifications) => verifications.length);
        pendingApprovals = pendingCount;
      } catch (e) {
        // Table might not exist yet, that's okay
        debugPrint('Employer verification table not found: $e');
      }

      return {
        ...userStats,
        ...jobStats,
        ...applicationStats,
        'pending_approvals': pendingApprovals,
      };
    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      return {
        'total_users': 0,
        'total_employers': 0,
        'total_applicants': 0,
        'total_jobs': 0,
        'active_jobs': 0,
        'total_applications': 0,
        'pending_applications': 0,
        'pending_approvals': 0,
      };
    }
  }

  /// Get all users with their details
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('''
            *,
            companies!owner_id (
              id,
              name,
              about
            ),
            applicant_profile!user_id (
              id,
              professional_summary,
              years_of_experience
            )
          ''')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all users: $e');
      return [];
    }
  }

  /// Get employer documents for admin review
  static Future<List<Map<String, dynamic>>> getEmployerDocuments({
    required String employerId,
  }) async {
    try {
      final documents = await StorageService.getUserDocuments(
        userId: employerId,
      );

      return documents;
    } catch (e) {
      debugPrint('❌ Error getting employer documents: $e');
      return [];
    }
  }

  /// Get signed URL for viewing employer document
  static Future<String?> getEmployerDocumentUrl({
    required String filePath,
    int expiresIn = 3600, // 1 hour
  }) async {
    try {
      final signedUrl = await StorageService.getSignedUrl(
        filePath: filePath,
        expiresIn: expiresIn,
      );

      return signedUrl;
    } catch (e) {
      debugPrint('❌ Error getting document URL: $e');
      return null;
    }
  }

  /// Get pending employer approvals
  static Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    try {
      final response = await _supabase
          .from('employer_verification')
          .select('''
            *,
            companies!company_id (
              id,
              name,
              about,
              logo_url,
              profile_url
            ),
            profiles!employer_id (
              id,
              full_name,
              email,
              phone_number,
              role
            )
          ''')
          .eq('verification_status', 'pending')
          .order('submitted_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching pending approvals: $e');
      return [];
    }
  }

  /// Approve an employer
  static Future<bool> approveEmployer({
    required String employerId,
    required String adminId,
    String? notes,
  }) async {
    try {
      // Update verification status
      await _supabase
          .from('employer_verification')
          .update({
            'verification_status': 'approved',
            'verified_by': adminId,
            'verified_at': DateTime.now().toIso8601String(),
            'admin_notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('employer_id', employerId);

      // Make company public
      await _supabase
          .from('companies')
          .update({
            'is_public': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('owner_id', employerId);

      // Log admin action
      await _logAdminAction(
        adminId: adminId,
        actionType: 'employer_approval',
        targetUserId: employerId,
        actionData: {'notes': notes},
      );

      return true;
    } catch (e) {
      debugPrint('Error approving employer: $e');
      return false;
    }
  }

  /// Reject an employer
  static Future<bool> rejectEmployer({
    required String employerId,
    required String adminId,
    required String reason,
  }) async {
    try {
      // Update verification status
      await _supabase
          .from('employer_verification')
          .update({
            'verification_status': 'rejected',
            'verified_by': adminId,
            'verified_at': DateTime.now().toIso8601String(),
            'rejection_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('employer_id', employerId);

      // Log admin action
      await _logAdminAction(
        adminId: adminId,
        actionType: 'employer_rejection',
        targetUserId: employerId,
        actionData: {'reason': reason},
      );

      return true;
    } catch (e) {
      debugPrint('Error rejecting employer: $e');
      return false;
    }
  }

  /// Suspend a user
  static Future<bool> suspendUser({
    required String userId,
    required String adminId,
    required String reason,
  }) async {
    try {
      // Update user profile to mark as suspended
      await _supabase
          .from('profiles')
          .update({
            'updated_at': DateTime.now().toIso8601String(),
            // Add suspended field when schema is updated
          })
          .eq('id', userId);

      // Log admin action
      await _logAdminAction(
        adminId: adminId,
        actionType: 'user_suspension',
        targetUserId: userId,
        actionData: {'reason': reason},
      );

      return true;
    } catch (e) {
      debugPrint('Error suspending user: $e');
      return false;
    }
  }

  /// Get system analytics
  static Future<Map<String, dynamic>> getSystemAnalytics() async {
    try {
      // Get user growth over time
      final userGrowth = await _supabase
          .from('profiles')
          .select('created_at')
          .order('created_at', ascending: true);

      // Get job posting trends
      final jobTrends = await _supabase
          .from('jobs')
          .select('created_at, status')
          .order('created_at', ascending: true);

      // Get application trends
      final applicationTrends = await _supabase
          .from('job_applications')
          .select('created_at, status')
          .order('created_at', ascending: true);

      // Get login attempts (for security monitoring)
      final loginAttempts = await _supabase
          .from('login_attempts')
          .select('created_at, success')
          .order('created_at', ascending: false)
          .limit(100);

      return {
        'user_growth': userGrowth,
        'job_trends': jobTrends,
        'application_trends': applicationTrends,
        'login_attempts': loginAttempts,
        'total_users': userGrowth.length,
        'total_jobs': jobTrends.length,
        'total_applications': applicationTrends.length,
        'failed_logins': loginAttempts.where((l) => l['success'] == false).length,
      };
    } catch (e) {
      debugPrint('Error getting system analytics: $e');
      return {};
    }
  }

  /// Log admin actions for audit trail
  static Future<void> _logAdminAction({
    required String adminId,
    required String actionType,
    String? targetUserId,
    String? targetCompanyId,
    Map<String, dynamic>? actionData,
  }) async {
    try {
      await _supabase
          .from('admin_actions')
          .insert({
            'admin_id': adminId,
            'action_type': actionType,
            'target_user_id': targetUserId,
            'target_company_id': targetCompanyId,
            'action_data': actionData,
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }

  /// Get admin actions log
  static Future<List<Map<String, dynamic>>> getAdminActionsLog({
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from('admin_actions')
          .select('''
            *,
            profiles!admin_id (
              full_name,
              email
            )
          ''')
          .order('created_at', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching admin actions log: $e');
      return [];
    }
  }

  /// Check if user is admin
  static Future<bool> isAdmin(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      
      return response != null && response['role'] == 'admin';
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  /// Create initial admin user
  static Future<bool> createInitialAdmin({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Create admin user
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'admin',
        },
      );

      if (response.user != null) {
        // Update profile with admin role
        await _supabase
            .from('profiles')
            .update({'role': 'admin'})
            .eq('id', response.user!.id);

        debugPrint('✅ Initial admin created successfully');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error creating initial admin: $e');
      return false;
    }
  }
}
