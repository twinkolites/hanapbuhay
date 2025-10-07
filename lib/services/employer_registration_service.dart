import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/employer_registration_data.dart';
import '../services/input_security_service.dart';
import '../services/storage_service.dart';

class EmployerRegistrationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Register a new employer with comprehensive validation
  static Future<Map<String, dynamic>> registerEmployer({
    required EmployerRegistrationData registrationData,
  }) async {
    try {
      debugPrint('🏢 Starting employer registration for: ${registrationData.companyName}');

      // Validate input data
      final validationErrors = registrationData.getValidationErrors();
      if (validationErrors.isNotEmpty) {
        throw Exception('Validation errors: ${validationErrors.join(', ')}');
      }

      // Additional security validation
      final fullNameError = InputSecurityService.validateSecureName(
        registrationData.fullName,
        'Full name',
      );
      if (fullNameError != null) {
        throw Exception(fullNameError);
      }

      final emailError = InputSecurityService.validateSecureEmail(
        registrationData.email,
      );
      if (emailError != null) {
        debugPrint('❌ Email validation failed: $emailError');
        throw Exception(emailError);
      }
      debugPrint('✅ Email validation passed: ${registrationData.email}');
      
      // Additional basic email format check
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(registrationData.email.trim())) {
        debugPrint('❌ Basic email regex validation failed');
        throw Exception('Invalid email format');
      }
      debugPrint('✅ Basic email regex validation passed');

      final passwordError = InputSecurityService.validateSecurePassword(
        registrationData.password,
      );
      if (passwordError != null) {
        throw Exception(passwordError);
      }

      // Check if email already exists in profiles table
      debugPrint('🔍 Checking if email exists in profiles: ${registrationData.email}');
      final existingUser = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', registrationData.email.trim().toLowerCase())
          .maybeSingle();

      if (existingUser != null) {
        debugPrint('❌ Email already exists in profiles table');
        throw Exception('Email already registered');
      }
      
      // Also check if email exists in Supabase Auth (this will be caught by signup if it exists)
      debugPrint('✅ Email not found in profiles table, proceeding with signup');

      // Check if company name already exists
      final existingCompany = await _supabase
          .from('companies')
          .select('id')
          .eq('name', registrationData.companyName.trim())
          .maybeSingle();

      if (existingCompany != null) {
        throw Exception('Company name already registered');
      }

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
        debugPrint('❌ Auth signup error: $e');
        
        // Handle specific email validation errors
        if (e.toString().contains('email_address_invalid')) {
          throw Exception('Email address "${registrationData.email}" is invalid. Please check the email format.');
        } else if (e.toString().contains('email_address_already_registered')) {
          throw Exception('Email address "${registrationData.email}" is already registered. Please use a different email or try logging in.');
        } else if (e.toString().contains('password_too_short')) {
          throw Exception('Password is too short. Please use at least 6 characters.');
        } else if (e.toString().contains('password_too_common')) {
          throw Exception('Password is too common. Please choose a stronger password.');
        } else {
          throw Exception('Failed to create account: ${e.toString()}');
        }
      }

      if (authResponse.user == null) {
        throw Exception('Failed to create user account - no user returned');
      }

      final userId = authResponse.user!.id;
      debugPrint('✅ User account created: $userId');
      
      // Check if we have a valid session
      final session = authResponse.session;
      debugPrint('🔍 Auth session: ${session != null ? 'Present' : 'Missing'}');
      
      if (session == null) {
        debugPrint('⚠️ No session returned from signup - email confirmation may be required');
        debugPrint('📧 This is normal behavior when email confirmation is enabled');
        
        // Since we can't establish a session, we'll create the company and verification records
        // using the user ID from the auth response, then return a success message
        debugPrint('🏢 Proceeding with company creation using user ID: $userId');
        
        // Continue with company creation even without session
        // The user will need to log in after email confirmation
      }
      
      // If we have a session, proceed normally
      if (session != null) {
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
              // Instead of throwing an exception, return a success response indicating manual login is needed
              return {
                'success': true,
                'message': 'Account created successfully! Please log in to complete your registration.',
                'requiresManualLogin': true,
              };
            }
          } catch (e) {
            debugPrint('❌ Error refreshing session: $e');
            // Instead of throwing an exception, return a success response indicating manual login is needed
            return {
              'success': true,
              'message': 'Account created successfully! Please log in to complete your registration.',
              'requiresManualLogin': true,
            };
          }
        }
      } else {
        debugPrint('📧 No session available - user needs to confirm email first');
        debugPrint('🏢 Will create company and verification records after email confirmation');
        
        // Return success with email confirmation requirement
        return {
          'success': true,
          'message': 'Account created successfully! Please check your email and click the confirmation link to complete your registration.',
          'requiresEmailConfirmation': true,
          'email': registrationData.email,
        };
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

      debugPrint('🏢 Creating company with data: $companyData');

      String companyId;
      try {
        final companyResponse = await _supabase
            .from('companies')
            .insert(companyData)
            .select()
            .single();

        companyId = companyResponse['id'];
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

      await _supabase
          .from('employer_verification')
          .insert(verificationData);

      debugPrint('✅ Employer verification record created');

      // Create detailed company profile with additional information
      final detailedCompanyData = {
        'company_id': companyId,
        'website': registrationData.companyWebsite,
        'business_address': registrationData.businessAddress,
        'city': registrationData.city,
        'province': registrationData.province,
        'postal_code': registrationData.postalCode,
        'country': registrationData.country,
        'industry': registrationData.industry,
        'company_size': registrationData.companySize,
        'business_type': registrationData.businessType,
        'contact_person_name': registrationData.contactPersonName,
        'contact_person_position': registrationData.contactPersonPosition,
        'contact_person_email': registrationData.contactPersonEmail,
        'contact_person_phone': registrationData.contactPersonPhone,
        'linkedin_url': registrationData.linkedinUrl,
        'facebook_url': registrationData.facebookUrl,
        'twitter_url': registrationData.twitterUrl,
        'instagram_url': registrationData.instagramUrl,
        'company_benefits': registrationData.companyBenefits,
        'company_culture': registrationData.companyCulture,
        'company_mission': registrationData.companyMission,
        'company_vision': registrationData.companyVision,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('company_details')
          .insert(detailedCompanyData);

      debugPrint('✅ Detailed company profile created');

      // Log admin action for tracking
      await _logEmployerRegistration(userId, companyId, registrationData);

      return {
        'success': true,
        'userId': userId,
        'companyId': companyId,
        'message': 'Employer registration submitted successfully. Please check your email for verification.',
        'requiresApproval': true,
      };

    } catch (e) {
      debugPrint('❌ Error registering employer: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to register employer: $e',
      };
    }
  }

  /// Get employer registration status
  static Future<Map<String, dynamic>?> getEmployerRegistrationStatus(String userId) async {
    try {
      final response = await _supabase
          .from('employer_verification')
          .select('''
            *,
            companies (
              id,
              name,
              about,
              logo_url,
              is_public
            ),
            profiles (
              id,
              full_name,
              email,
              role
            )
          ''')
          .eq('employer_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error getting employer registration status: $e');
      return null;
    }
  }

  /// Get all pending employer registrations (for admin)
  static Future<List<Map<String, dynamic>>> getPendingRegistrations() async {
    try {
      final response = await _supabase
          .from('employer_verification')
          .select('''
            *,
            companies (
              id,
              name,
              about,
              logo_url,
              is_public
            ),
            profiles (
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
      debugPrint('Error getting pending registrations: $e');
      return [];
    }
  }

  /// Approve employer registration (admin only)
  static Future<bool> approveEmployerRegistration({
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
        actionData: {
          'action': 'approved',
          'notes': notes,
        },
      );

      debugPrint('✅ Employer approved: $employerId');
      return true;
    } catch (e) {
      debugPrint('❌ Error approving employer: $e');
      return false;
    }
  }

  /// Reject employer registration (admin only)
  static Future<bool> rejectEmployerRegistration({
    required String employerId,
    required String adminId,
    required String reason,
    String? notes,
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
            'admin_notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('employer_id', employerId);

      // Log admin action
      await _logAdminAction(
        adminId: adminId,
        actionType: 'employer_rejection',
        targetUserId: employerId,
        actionData: {
          'action': 'rejected',
          'reason': reason,
          'notes': notes,
        },
      );

      debugPrint('✅ Employer rejected: $employerId');
      return true;
    } catch (e) {
      debugPrint('❌ Error rejecting employer: $e');
      return false;
    }
  }

  /// Upload document for verification
  static Future<String?> uploadVerificationDocument({
    required String employerId,
    required String documentType, // 'business_license', 'tax_id', 'business_registration'
    required String filePath,
  }) async {
    try {
      final fileName = '${employerId}_${documentType}_${DateTime.now().millisecondsSinceEpoch}';
      final fileExtension = filePath.split('.').last;
      final fullFileName = '$fileName.$fileExtension';

      final file = File(filePath);
      final response = await _supabase.storage
          .from('employer-documents')
          .upload(fullFileName, file);

      if (response.isNotEmpty) {
        final url = _supabase.storage
            .from('employer-documents')
            .getPublicUrl(fullFileName);

        // Update verification record with document URL
        String columnName;
        switch (documentType) {
          case 'business_license':
            columnName = 'business_license_url';
            break;
          case 'tax_id':
            columnName = 'tax_id_document_url';
            break;
          case 'business_registration':
            columnName = 'business_registration_url';
            break;
          default:
            throw Exception('Invalid document type');
        }

        await _supabase
            .from('employer_verification')
            .update({columnName: url})
            .eq('employer_id', employerId);

        return url;
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading document: $e');
      return null;
    }
  }

  /// Log employer registration for admin tracking
  static Future<void> _logEmployerRegistration(
    String userId,
    String companyId,
    EmployerRegistrationData registrationData,
  ) async {
    try {
      await _supabase
          .from('admin_actions')
          .insert({
            'action_type': 'employer_registration',
            'target_user_id': userId,
            'target_company_id': companyId,
            'action_data': {
              'company_name': registrationData.companyName,
              'industry': registrationData.industry,
              'company_size': registrationData.companySize,
              'business_type': registrationData.businessType,
              'has_documents': registrationData.businessLicenseNumber != null ||
                              registrationData.taxIdNumber != null ||
                              registrationData.businessRegistrationNumber != null,
            },
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint('Error logging employer registration: $e');
    }
  }

  /// Log admin action
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

  /// Upload employer document
  static Future<String?> uploadEmployerDocument({
    required String userId,
    required String documentType,
    required PlatformFile file,
  }) async {
    try {
      debugPrint('📁 Uploading document: ${file.name} for user: $userId');
      
      // Validate file before upload
      final validationError = StorageService.validateFile(file);
      if (validationError != null) {
        throw Exception(validationError);
      }

      // Upload file to Supabase Storage
      final fileUrl = await StorageService.uploadEmployerDocument(
        userId: userId,
        documentType: documentType,
        file: file,
      );

      if (fileUrl != null) {
        debugPrint('✅ Document uploaded successfully: $fileUrl');
        
        // Update the employer verification record with the document URL
        await _supabase
            .from('employer_verification')
            .update({
              '${documentType}_url': fileUrl,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('employer_id', userId);

        return fileUrl;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error uploading document: $e');
      rethrow;
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

  /// Get registration statistics (for admin dashboard)
  static Future<Map<String, dynamic>> getRegistrationStatistics() async {
    try {
      final pendingResponse = await _supabase
          .from('employer_verification')
          .select('id')
          .eq('verification_status', 'pending')
          .count();
      final pendingCount = pendingResponse.count;

      final approvedResponse = await _supabase
          .from('employer_verification')
          .select('id')
          .eq('verification_status', 'approved')
          .count();
      final approvedCount = approvedResponse.count;

      final rejectedResponse = await _supabase
          .from('employer_verification')
          .select('id')
          .eq('verification_status', 'rejected')
          .count();
      final rejectedCount = rejectedResponse.count;

      return {
        'pending': pendingCount,
        'approved': approvedCount,
        'rejected': rejectedCount,
        'total': pendingCount + approvedCount + rejectedCount,
      };
    } catch (e) {
      debugPrint('Error getting registration statistics: $e');
      return {
        'pending': 0,
        'approved': 0,
        'rejected': 0,
        'total': 0,
      };
    }
  }
}
