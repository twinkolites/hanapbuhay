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
      final types = ['business_license', 'tax_id', 'business_registration'];
      final List<Map<String, dynamic>> all = [];
      for (final t in types) {
        final docs = await StorageService.getUserDocuments(userId: employerId, documentType: t);
        for (final d in docs) {
          all.add({
            ...d,
            'docType': t,
          });
        }
      }
      return all;
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

  /// Delete an employer document (admin)
  static Future<bool> deleteEmployerDocument({
    required String filePath,
  }) async {
    try {
      final result = await StorageService.deleteFile(filePath);
      return result;
    } catch (e) {
      debugPrint('❌ Error deleting employer document: $e');
      return false;
    }
  }

  /// Get pending employer approvals
  static Future<List<Map<String, dynamic>>> getPendingApprovals() async {
    try {
      // Use a custom SQL query to bypass RLS issues with joins
      final response = await _supabase.rpc('get_pending_employer_approvals');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching pending approvals: $e');
      return [];
    }
  }

  /// Get employer approvals for all statuses (pending, under_review, approved, rejected)
  static Future<List<Map<String, dynamic>>> getAllEmployerApprovals() async {
    try {
      // Prefer RPC to bypass RLS; implement in DB as needed
      final response = await _supabase.rpc('get_all_employer_approvals');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching all employer approvals via RPC: $e');
      // Fallback: perform a joined query and normalize fields
      try {
        final rows = await _supabase
            .from('employer_verification')
            .select('''
              employer_id,
              company_id,
              verification_status,
              admin_notes,
              rejection_reason,
              submitted_at,
              created_at,
              updated_at,
              business_license_url,
              tax_id_document_url,
              business_registration_url,
              profiles:profiles!employer_id (
                full_name,
                email
              ),
              companies:companies!company_id (
                name,
                about
              )
            ''')
            .or('verification_status.eq.pending,verification_status.eq.under_review,verification_status.eq.approved,verification_status.eq.rejected')
            .order('created_at', ascending: false);

        final List<Map<String, dynamic>> flattened = [];
        for (final r in rows) {
          final map = Map<String, dynamic>.from(r as Map);
          Map<String, dynamic>? profile;
          final p = map['profiles'];
          if (p is List && p.isNotEmpty) {
            profile = Map<String, dynamic>.from(p.first as Map);
          } else if (p is Map) {
            profile = Map<String, dynamic>.from(p);
          }
          Map<String, dynamic>? company;
          final c = map['companies'];
          if (c is List && c.isNotEmpty) {
            company = Map<String, dynamic>.from(c.first as Map);
          } else if (c is Map) {
            company = Map<String, dynamic>.from(c);
          }

          flattened.add({
            // base ids and status
            'employer_id': map['employer_id'],
            'company_id': map['company_id'],
            'verification_status': (map['verification_status'] as String?)?.toLowerCase() ?? 'pending',
            'admin_notes': map['admin_notes'],
            'rejection_reason': map['rejection_reason'],
            'submitted_at': map['submitted_at'] ?? map['created_at'],
            'created_at': map['created_at'],
            'updated_at': map['updated_at'],
            // flattened profile
            'employer_full_name': profile?['full_name'] ?? '',
            'employer_email': profile?['email'] ?? '',
            // flattened company
            'company_name': company?['name'] ?? 'Not provided',
            'company_about': company?['about'] ?? '',
            // document urls if present on verification row
            'business_license_url': map['business_license_url'],
            'tax_id_document_url': map['tax_id_document_url'],
            'business_registration_url': map['business_registration_url'],
          });
        }

        return flattened;
      } catch (e2) {
        debugPrint('All-employer fallback query failed: $e2');
        // Last resort: pending only to avoid hard failure
        try {
          return await getPendingApprovals();
        } catch (_) {
          return [];
        }
      }
    }
  }

  /// Get employer approvals only with rejected status
  static Future<List<Map<String, dynamic>>> getRejectedEmployerApprovals() async {
    try {
      // Prefer RPC first if available
      final response = await _supabase.rpc('get_rejected_employer_approvals');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('RPC get_rejected_employer_approvals not available: $e');
      try {
        final rows = await _supabase
            .from('employer_verification')
            .select('''
              employer_id,
              company_id,
              verification_status,
              admin_notes,
              rejection_reason,
              submitted_at,
              created_at,
              updated_at,
              business_license_url,
              tax_id_document_url,
              business_registration_url,
              profiles:profiles!employer_id (
                full_name,
                email
              ),
              companies:companies!company_id (
                name,
                about
              )
            ''')
            .eq('verification_status', 'rejected')
            .order('created_at', ascending: false);

        return rows.map<Map<String, dynamic>>((r) {
          final map = Map<String, dynamic>.from(r as Map);
          final p = map['profiles'];
          final c = map['companies'];
          final profile = p is List && p.isNotEmpty ? Map<String, dynamic>.from(p.first as Map) : p is Map ? Map<String, dynamic>.from(p) : null;
          final company = c is List && c.isNotEmpty ? Map<String, dynamic>.from(c.first as Map) : c is Map ? Map<String, dynamic>.from(c) : null;
          return {
            'employer_id': map['employer_id'],
            'company_id': map['company_id'],
            'verification_status': 'rejected',
            'admin_notes': map['admin_notes'],
            'rejection_reason': map['rejection_reason'],
            'submitted_at': map['submitted_at'] ?? map['created_at'],
            'created_at': map['created_at'],
            'updated_at': map['updated_at'],
            'employer_full_name': profile?['full_name'] ?? '',
            'employer_email': profile?['email'] ?? '',
            'company_name': company?['name'] ?? 'Not provided',
            'company_about': company?['about'] ?? '',
            'business_license_url': map['business_license_url'],
            'tax_id_document_url': map['tax_id_document_url'],
            'business_registration_url': map['business_registration_url'],
          };
        }).toList();
      } catch (e2) {
        debugPrint('Rejected-only fallback query failed: $e2');
        return [];
      }
    }
  }

  /// Get employer approvals only with rejected or pending status
  static Future<List<Map<String, dynamic>>> getRejectedAndPendingEmployerApprovals() async {
    try {
      final response = await _supabase.rpc('get_rejected_pending_employer_approvals');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('RPC get_rejected_pending_employer_approvals not available: $e');
      try {
        final rows = await _supabase
            .from('employer_verification')
            .select('''
              employer_id,
              company_id,
              verification_status,
              admin_notes,
              rejection_reason,
              submitted_at,
              created_at,
              updated_at,
              business_license_url,
              tax_id_document_url,
              business_registration_url,
              profiles:profiles!employer_id (
                full_name,
                email
              ),
              companies:companies!company_id (
                name,
                about
              )
            ''')
            .or('verification_status.eq.pending,verification_status.eq.rejected')
            .order('created_at', ascending: false);

        return rows.map<Map<String, dynamic>>((r) {
          final map = Map<String, dynamic>.from(r as Map);
          final p = map['profiles'];
          final c = map['companies'];
          final profile = p is List && p.isNotEmpty ? Map<String, dynamic>.from(p.first as Map) : p is Map ? Map<String, dynamic>.from(p) : null;
          final company = c is List && c.isNotEmpty ? Map<String, dynamic>.from(c.first as Map) : c is Map ? Map<String, dynamic>.from(c) : null;
          return {
            'employer_id': map['employer_id'],
            'company_id': map['company_id'],
            'verification_status': (map['verification_status'] as String?)?.toLowerCase() ?? 'pending',
            'admin_notes': map['admin_notes'],
            'rejection_reason': map['rejection_reason'],
            'submitted_at': map['submitted_at'] ?? map['created_at'],
            'created_at': map['created_at'],
            'updated_at': map['updated_at'],
            'employer_full_name': profile?['full_name'] ?? '',
            'employer_email': profile?['email'] ?? '',
            'company_name': company?['name'] ?? 'Not provided',
            'company_about': company?['about'] ?? '',
            'business_license_url': map['business_license_url'],
            'tax_id_document_url': map['tax_id_document_url'],
            'business_registration_url': map['business_registration_url'],
          };
        }).toList();
      } catch (e2) {
        debugPrint('Rejected+Pending fallback query failed: $e2');
        return [];
      }
    }
  }

  /// Get a full, denormalized snapshot of an employer for admin review
  /// Includes profile, company, company_details, and employer_verification
  static Future<Map<String, dynamic>?> getEmployerFullDetails({
    required String employerId,
  }) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('''
            id,
            email,
            full_name,
            display_name,
            phone_number,
            birthday,
            role,
            companies:companies!owner_id (
              id,
              name,
              about,
              logo_url,
              profile_url,
              is_public,
              company_details:company_details!company_id (
                website,
                business_address,
                city,
                province,
                postal_code,
                country,
                industry,
                company_size,
                business_type,
                contact_person_name,
                contact_person_position,
                contact_person_email,
                contact_person_phone,
                linkedin_url,
                facebook_url,
                twitter_url,
                instagram_url,
                company_benefits,
                company_culture,
                company_mission,
                company_vision
              )
            ),
            verification:employer_verification!employer_id (
              id,
              company_id,
              verification_status,
              admin_notes,
              rejection_reason,
              submitted_at,
              verified_at,
              verified_by
            )
          ''')
          .eq('id', employerId)
          .maybeSingle();

      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error fetching employer full details: $e');
      return null;
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
          })
          .eq('owner_id', employerId);

      // Log admin action (don't fail if this fails)
      try {
        await _logAdminAction(
          adminId: adminId,
          actionType: 'employer_approval',
          targetUserId: employerId,
          actionData: {'notes': notes},
        );
      } catch (e) {
        debugPrint('Failed to log admin action, but approval succeeded: $e');
      }

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

      // Log admin action (don't fail if this fails)
      try {
        await _logAdminAction(
          adminId: adminId,
          actionType: 'employer_rejection',
          targetUserId: employerId,
          actionData: {'reason': reason},
        );
      } catch (e) {
        debugPrint('Failed to log admin action, but rejection succeeded: $e');
      }

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
            'is_suspended': true,
            'suspension_reason': reason,
            'suspended_at': DateTime.now().toIso8601String(),
            'suspended_by': adminId,
            'updated_at': DateTime.now().toIso8601String(),
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

  /// Unsuspend (restore) a user
  static Future<bool> unsuspendUser({
    required String userId,
    required String adminId,
    String? notes,
  }) async {
    try {
      // Update user profile to remove suspension
      await _supabase
          .from('profiles')
          .update({
            'is_suspended': false,
            'suspension_reason': null,
            'suspended_at': null,
            'suspended_by': null,
            'unsuspended_at': DateTime.now().toIso8601String(),
            'unsuspended_by': adminId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Log admin action
      await _logAdminAction(
        adminId: adminId,
        actionType: 'user_unsuspension',
        targetUserId: userId,
        actionData: {'notes': notes},
      );

      return true;
    } catch (e) {
      debugPrint('Error unsuspending user: $e');
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
      // Ensure caller is an admin before attempting to write admin_actions
      final isCallerAdmin = await isAdmin(adminId);
      if (!isCallerAdmin) {
        return; // silently skip to avoid RLS errors for non-admins
      }

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
      // Don't rethrow - this is just logging, shouldn't break the main operation
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

  /// Public logger usable across the app (admin or system events)
  static Future<void> logEvent({
    String? adminId,
    required String actionType,
    String? targetUserId,
    String? targetCompanyId,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Only admins may write to admin_actions due to RLS; guard to avoid noisy errors
      if (adminId == null) {
        return;
      }
      final isCallerAdmin = await isAdmin(adminId);
      if (!isCallerAdmin) {
        return;
      }

      await _supabase.from('admin_actions').insert({
        'admin_id': adminId,
        'action_type': actionType,
        'target_user_id': targetUserId,
        'target_company_id': targetCompanyId,
        'action_data': data,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error logging event: $e');
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
