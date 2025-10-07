import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../models/employer_registration_data.dart';
import '../services/input_security_service.dart';
import '../services/storage_service.dart';

class EmployerRegistrationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Register a new employer
  static Future<Map<String, dynamic>> registerEmployer({
    required EmployerRegistrationData registrationData,
  }) async {
    try {
      debugPrint('🏢 Starting employer registration for: ${registrationData.companyName}');

      // Validate phone numbers
      debugPrint('📱 Validating personal phone: ${registrationData.phoneNumber}');
      if (!registrationData.isValidPhoneNumber()) {
        final errors = registrationData.getValidationErrors();
        debugPrint('❌ Personal phone validation failed: $errors');
        throw Exception('Validation errors: $errors');
      }
      debugPrint('✅ Personal phone validation passed: ${registrationData.phoneNumber}');

      debugPrint('📱 Validating contact person phone: ${registrationData.contactPersonPhone}');
      if (!registrationData.isValidContactPersonPhone()) {
        final errors = registrationData.getValidationErrors();
        debugPrint('❌ Contact person phone validation failed: $errors');
        throw Exception('Validation errors: $errors');
      }
      debugPrint('✅ Contact person phone validation passed: ${registrationData.contactPersonPhone}');

      // Validate email
      debugPrint('📧 Validating email: ${registrationData.email}');
      if (InputSecurityService.validateSecureEmail(registrationData.email) != true) {
        debugPrint('❌ Email validation failed');
        throw Exception('Invalid email format');
      }
      debugPrint('✅ Email validation passed: ${registrationData.email}');

      // Basic email regex validation
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(registrationData.email.trim())) {
        debugPrint('❌ Basic email regex validation failed');
        throw Exception('Invalid email format');
      }
      debugPrint('✅ Basic email regex validation passed');

      // Check if email already exists
      debugPrint('🔍 Checking if email exists in profiles: ${registrationData.email}');
      final existingProfile = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', registrationData.email.trim().toLowerCase())
          .maybeSingle();

      if (existingProfile != null) {
        debugPrint('❌ Email already exists in profiles table');
        throw Exception('Email address is already registered');
      }
      debugPrint('✅ Email not found in profiles table, proceeding with signup');

      // Create user account
      debugPrint('📧 Attempting to create user account for: ${registrationData.email}');
      debugPrint('📧 Email length: ${registrationData.email.length}');
      debugPrint('📧 Email contains @: ${registrationData.email.contains('@')}');
      debugPrint('📧 Email contains .: ${registrationData.email.contains('.')}');
      debugPrint('📧 Email trimmed and lowercased: "${registrationData.email.trim().toLowerCase()}"');

      AuthResponse authResponse;
      try {
        authResponse = await _supabase.auth.signUp(
          email: registrationData.email.trim().toLowerCase(),
          password: registrationData.password,
          data: {
            'full_name': registrationData.fullName.trim(),
            'display_name': registrationData.displayName?.trim() ?? registrationData.fullName.trim(),
            'username': registrationData.username?.trim().toLowerCase(),
            'phone_number': registrationData.phoneNumber?.trim(),
            'birthday': registrationData.birthday?.toIso8601String(),
            'role': 'employer', // Set as employer
            'email_confirm': true, // Auto-confirm email for employers
          },
          emailRedirectTo: 'https://twinkolites.github.io/hanapbuhay/',
        );
      } catch (e) {
        debugPrint('❌ Supabase signup error: $e');
        if (e is AuthApiException) {
          switch (e.message) {
            case 'email_address_invalid':
              throw Exception('Invalid email address format');
            case 'email_address_already_registered':
              throw Exception('Email address is already registered');
            case 'password_too_short':
              throw Exception('Password is too short');
            case 'password_too_common':
              throw Exception('Password is too common');
            default:
              throw Exception('Registration failed: ${e.message}');
          }
        }
        rethrow;
      }

      if (authResponse.user == null) {
        throw Exception('Failed to create user account - no user returned');
      }

      final userId = authResponse.user!.id;
      debugPrint('✅ User account created: $userId');
      
      final session = authResponse.session;
      debugPrint('🔍 Auth session: ${session != null ? 'Present' : 'Missing'}');
      
      // Create profile, company, and verification records regardless of session status
      debugPrint('🏢 Creating profile, company, and verification records for user: $userId');
      
      // First, create/update the user profile with employer role
      debugPrint('👤 Creating/updating user profile with employer role');
      final profileData = {
        'id': userId,
        'email': registrationData.email.trim().toLowerCase(),
        'full_name': registrationData.fullName.trim(),
        'display_name': registrationData.displayName?.trim() ?? registrationData.fullName.trim(),
        'username': registrationData.username?.trim().toLowerCase(),
        'phone_number': registrationData.phoneNumber?.trim(),
        'birthday': registrationData.birthday?.toIso8601String(),
        'role': 'employer', // Set role as employer
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await _supabase
            .from('profiles')
            .upsert(profileData);

        debugPrint('✅ User profile created/updated with employer role');
      } catch (e) {
        debugPrint('❌ Error creating/updating profile: $e');
        debugPrint('❌ Profile data: ${profileData.toString()}');
        rethrow;
      }

      // Create company profile
      final companyData = {
        'owner_id': userId,
        'name': registrationData.companyName.trim(),
        'about': registrationData.companyAbout.trim(),
        'logo_url': registrationData.companyLogoUrl,
        'profile_url': registrationData.companyProfileUrl,
        'is_public': false, // Initially private until approved
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint('🏢 Creating company with data: $companyData');

      String companyId;
      try {
        final companyResponse = await _supabase
            .from('companies')
            .insert(companyData)
            .select()
            .single();

        companyId = companyResponse['id'] as String;
        debugPrint('✅ Company profile created: $companyId');
      } catch (e) {
        debugPrint('❌ Error creating company: $e');
        debugPrint('❌ Company data: $companyData');
        debugPrint('❌ Current user: ${_supabase.auth.currentUser?.id}');
        rethrow;
      }

      // Create employer verification record
      final verificationData = {
        'employer_id': userId,
        'company_id': companyId,
        'business_license_number': registrationData.businessLicenseNumber,
        'tax_id_number': registrationData.taxIdNumber,
        'business_registration_number': registrationData.businessRegistrationNumber,
        'business_license_url': registrationData.businessLicenseUrl,
        'tax_id_document_url': registrationData.taxIdDocumentUrl,
        'business_registration_url': registrationData.businessRegistrationUrl,
        'verification_status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint('📋 Creating employer verification record: $verificationData');

      try {
        await _supabase
            .from('employer_verification')
            .insert(verificationData);

        debugPrint('✅ Employer verification record created successfully');
      } catch (e) {
        debugPrint('❌ Error creating verification record: $e');
        debugPrint('❌ Verification data: $verificationData');
        rethrow;
      }

      // Log admin action
      try {
        await _supabase
            .from('admin_actions')
            .insert({
          'admin_id': userId,
          'action_type': 'employer_registration_completed',
          'target_user_id': userId,
          'action_data': {'message': 'Employer registration completed'},
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Admin action logged successfully');
      } catch (e) {
        debugPrint('⚠️ Error logging admin action: $e');
        // Don't fail the entire process for logging errors
      }

      debugPrint('✅ Employer registration completed successfully');

      // Handle session status for response
      if (session == null) {
        debugPrint('⚠️ No session returned from signup - email confirmation may be required');
        debugPrint('📧 This is normal behavior when email confirmation is enabled');
        
        // Return success with email confirmation requirement
        return {
          'success': true,
          'message': 'Account created successfully! Please check your email and click the confirmation link to complete your registration.',
          'requiresEmailConfirmation': true,
          'email': registrationData.email,
        };
      }
      
      // If we have a session, proceed with additional session-based logic
      // Wait a moment for authentication to be established
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Debug: Check current authenticated user
      final currentUser = _supabase.auth.currentUser;
      debugPrint('🔍 Current authenticated user: ${currentUser?.id}');
      debugPrint('🔍 User matches: ${currentUser?.id == userId}');
      
      // If user is not authenticated, try to refresh the session
      if (currentUser?.id != userId) {
        debugPrint('🔄 Refreshing authentication session...');
        try {
          await _supabase.auth.refreshSession();
          final refreshedUser = _supabase.auth.currentUser;
          debugPrint('🔍 After refresh - Current user: ${refreshedUser?.id}');
          
          if (refreshedUser?.id != userId) {
            debugPrint('❌ Still not authenticated after refresh');
            // Return success since records are already created
            return {
              'success': true,
              'message': 'Account created successfully! Please log in to complete your registration.',
              'requiresManualLogin': true,
            };
          }
        } catch (e) {
          debugPrint('❌ Error refreshing session: $e');
          // Return success since records are already created
          return {
            'success': true,
            'message': 'Account created successfully! Please log in to complete your registration.',
            'requiresManualLogin': true,
          };
        }
      }

      return {
        'success': true,
        'message': 'Registration completed successfully! Your application is now under review.',
        'companyId': companyId,
      };
    } catch (e) {
      debugPrint('❌ Error registering employer: $e');
      return {
        'success': false,
        'message': 'Registration failed: $e',
      };
    }
  }

  /// Complete employer registration after email confirmation
  static Future<Map<String, dynamic>> completeEmployerRegistrationAfterEmailConfirmation({
    required EmployerRegistrationData registrationData,
  }) async {
    try {
      debugPrint('🏢 Completing employer registration after email confirmation');
      
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found. Please log in first.');
      }
      
      final userId = user.id;
      debugPrint('✅ User authenticated: $userId');
      
      // First, create/update the user profile with employer role
      debugPrint('👤 Creating/updating user profile with employer role');
      final profileData = {
        'id': userId,
        'email': registrationData.email.trim().toLowerCase(),
        'full_name': registrationData.fullName.trim(),
        'display_name': registrationData.displayName?.trim() ?? registrationData.fullName.trim(),
        'username': registrationData.username?.trim().toLowerCase(),
        'phone_number': registrationData.phoneNumber?.trim(),
        'birthday': registrationData.birthday?.toIso8601String(),
        'role': 'employer', // Set role as employer
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await _supabase
            .from('profiles')
            .upsert(profileData);

        debugPrint('✅ User profile created/updated with employer role');
      } catch (e) {
        debugPrint('❌ Error creating/updating profile: $e');
        debugPrint('❌ Profile data: ${profileData.toString()}');
        throw Exception('Failed to create/update user profile: $e');
      }
      
      // Create company profile
      final companyData = {
        'owner_id': userId,
        'name': registrationData.companyName.trim(),
        'about': registrationData.companyAbout.trim(),
        'logo_url': registrationData.companyLogoUrl,
        'profile_url': registrationData.companyProfileUrl,
        'is_public': false, // Initially private until approved
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint('🏢 Creating company with data: $companyData');

      String companyId;
      try {
        final companyResponse = await _supabase
            .from('companies')
            .insert(companyData)
            .select()
            .single();
        
        companyId = companyResponse['id'] as String;
        debugPrint('✅ Company created successfully: $companyId');
      } catch (e) {
        debugPrint('❌ Error creating company: $e');
        throw Exception('Failed to create company profile: $e');
      }

      // Create employer verification record
      final verificationData = {
        'employer_id': userId,
        'company_id': companyId,
        'verification_status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      debugPrint('📋 Creating employer verification record: $verificationData');

      try {
        await _supabase
            .from('employer_verification')
            .insert(verificationData);

        debugPrint('✅ Employer verification record created successfully');
      } catch (e) {
        debugPrint('❌ Error creating verification record: $e');
        throw Exception('Failed to create verification record: $e');
      }

      // Log admin action
      await _logAdminAction(
        adminId: userId,
        actionType: 'employer_registration_completed',
        targetUserId: userId,
        actionData: {'message': 'Employer registration completed after email confirmation'},
      );

      debugPrint('✅ Employer registration completed successfully after email confirmation');

      return {
        'success': true,
        'message': 'Registration completed successfully! Your application is now under review.',
        'companyId': companyId,
      };
    } catch (e) {
      debugPrint('❌ Error completing employer registration: $e');
      return {
        'success': false,
        'message': 'Failed to complete registration: $e',
      };
    }
  }

  /// Upload employer document to Supabase Storage
  static Future<Map<String, dynamic>> uploadEmployerDocument({
    required String userId,
    required String documentType,
    required PlatformFile file,
  }) async {
    try {
      debugPrint('📄 Uploading employer document: $documentType for user: $userId');
      
      // Upload file to Supabase Storage
      final documentUrl = await StorageService.uploadEmployerDocument(
        userId: userId,
        documentType: documentType,
        file: file,
      );

      if (documentUrl != null) {
        // Update employer verification record with document URL
        String updateField;
        switch (documentType) {
          case 'business_license':
            updateField = 'business_license_url';
            break;
          case 'tax_id':
            updateField = 'tax_id_document_url';
            break;
          case 'business_registration':
            updateField = 'business_registration_url';
            break;
          default:
            throw Exception('Invalid document type: $documentType');
        }

        await _supabase
            .from('employer_verification')
            .update({updateField: documentUrl})
            .eq('employer_id', userId);

        debugPrint('✅ Document uploaded and verification record updated');
        
        return {
          'success': true,
          'message': 'Document uploaded successfully!',
          'url': documentUrl,
        };
      } else {
        throw Exception('Failed to upload document');
      }
    } catch (e) {
      debugPrint('❌ Error uploading employer document: $e');
      return {
        'success': false,
        'message': 'Failed to upload document: $e',
      };
    }
  }

  /// Get employer documents for admin review
  static Future<List<Map<String, dynamic>>> getEmployerDocuments(String userId) async {
    try {
      return await StorageService.getUserDocuments(userId: userId);
    } catch (e) {
      debugPrint('❌ Error getting employer documents: $e');
      return [];
    }
  }

  /// Get employer verification statistics
  static Future<Map<String, int>> getVerificationStats() async {
    try {
      final result = await _supabase
          .from('employer_verification')
          .select('verification_status');

      final stats = <String, int>{
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total': 0,
      };

      for (final record in result) {
        final status = record['verification_status'] as String? ?? 'pending';
        stats[status] = (stats[status] ?? 0) + 1;
        stats['total'] = (stats['total'] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      debugPrint('❌ Error getting verification stats: $e');
      return {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total': 0,
      };
    }
  }

  /// Log admin action for audit trail
  static Future<void> _logAdminAction({
    required String adminId,
    required String actionType,
    required String targetUserId,
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
}
