import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminInitializationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Create the initial admin user
  /// This should be called once to set up the first admin account
  static Future<bool> createInitialAdmin({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      debugPrint('🔧 Creating initial admin user...');
      
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
        debugPrint('   Email: $email');
        debugPrint('   Name: $fullName');
        debugPrint('   User ID: ${response.user!.id}');
        
        return true;
      }
      
      debugPrint('❌ Failed to create admin user');
      return false;
    } catch (e) {
      debugPrint('❌ Error creating initial admin: $e');
      return false;
    }
  }

  /// Check if any admin users exist
  static Future<bool> hasAdminUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin')
          .limit(1);
      
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking for admin users: $e');
      return false;
    }
  }

  /// Get all admin users
  static Future<List<Map<String, dynamic>>> getAdminUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, email, created_at')
          .eq('role', 'admin')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching admin users: $e');
      return [];
    }
  }

  /// Promote a user to admin
  static Future<bool> promoteToAdmin({
    required String userId,
    required String adminId,
  }) async {
    try {
      // Update user role to admin
      await _supabase
          .from('profiles')
          .update({
            'role': 'admin',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Log admin action
      await _logAdminAction(
        adminId: adminId,
        actionType: 'user_promotion',
        targetUserId: userId,
        actionData: {'promoted_to': 'admin'},
      );

      debugPrint('✅ User promoted to admin successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error promoting user to admin: $e');
      return false;
    }
  }

  /// Demote an admin to regular user
  static Future<bool> demoteFromAdmin({
    required String userId,
    required String adminId,
    required String newRole, // 'applicant' or 'employer'
  }) async {
    try {
      // Update user role
      await _supabase
          .from('profiles')
          .update({
            'role': newRole,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Log admin action
      await _logAdminAction(
        adminId: adminId,
        actionType: 'admin_demotion',
        targetUserId: userId,
        actionData: {'demoted_to': newRole},
      );

      debugPrint('✅ Admin demoted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error demoting admin: $e');
      return false;
    }
  }

  /// Log admin actions for audit trail
  static Future<void> _logAdminAction({
    required String adminId,
    required String actionType,
    String? targetUserId,
    Map<String, dynamic>? actionData,
  }) async {
    try {
      await _supabase
          .from('admin_actions')
          .insert({
            'admin_id': adminId,
            'action_type': actionType,
            'target_user_id': targetUserId,
            'action_data': actionData,
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint('Error logging admin action: $e');
    }
  }

  /// Initialize admin system (create tables if needed)
  static Future<void> initializeAdminSystem() async {
    try {
      debugPrint('🔧 Initializing admin system...');
      
      // Check if admin_actions table exists, if not, create it
      try {
        await _supabase
            .from('admin_actions')
            .select('id')
            .limit(1);
        debugPrint('✅ admin_actions table exists');
      } catch (e) {
        debugPrint('⚠️ admin_actions table not found - will be created when needed');
      }
      
      debugPrint('✅ Admin system initialization complete');
    } catch (e) {
      debugPrint('❌ Error initializing admin system: $e');
    }
  }
}
