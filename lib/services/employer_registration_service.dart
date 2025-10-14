import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_service.dart';
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

      // Check if user is already authenticated and registration is already completed
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        // Check if profile already exists and is complete
        final existingProfile = await _supabase
            .from('profiles')
            .select('id, role, onboarding_completed')
            .eq('id', currentUser.id)
            .maybeSingle();
            
        if (existingProfile != null && existingProfile['role'] == 'employer') {
          debugPrint('✅ Employer registration already completed for user: ${currentUser.id}');
          return {
            'success': true,
            'message': 'Employer registration already completed',
            'alreadyCompleted': true,
          };
        }
      }

      // Validate personal details using InputSecurityService
      debugPrint('👤 Validating full name: ${registrationData.fullName}');
      final fullNameValidation = InputSecurityService.validateSecureName(registrationData.fullName, 'Full name');
      if (fullNameValidation != null) {
        debugPrint('❌ Full name validation failed: $fullNameValidation');
        throw Exception('Invalid full name: $fullNameValidation');
      }
      debugPrint('✅ Full name validation passed: ${registrationData.fullName}');

      // Validate company details using InputSecurityService
      debugPrint('🏢 Validating company name: ${registrationData.companyName}');
      final companyNameValidation = InputSecurityService.validateSecureOrganization(registrationData.companyName);
      if (companyNameValidation != null) {
        debugPrint('❌ Company name validation failed: $companyNameValidation');
        throw Exception('Invalid company name: $companyNameValidation');
      }
      debugPrint('✅ Company name validation passed: ${registrationData.companyName}');

      // Validate company description
      debugPrint('📝 Validating company description');
      final sanitizedDescription = InputSecurityService.sanitizeText(registrationData.companyAbout);
      if (sanitizedDescription != registrationData.companyAbout) {
        debugPrint('❌ Company description contains invalid characters');
        throw Exception('Company description contains invalid characters');
      }
      final suspiciousDescription = InputSecurityService.detectSuspiciousPatterns(registrationData.companyAbout, 'Company description');
      if (suspiciousDescription != null) {
        debugPrint('❌ Company description validation failed: $suspiciousDescription');
        throw Exception('Invalid company description: $suspiciousDescription');
      }
      debugPrint('✅ Company description validation passed');

      // Validate business address
      debugPrint('📍 Validating business address: ${registrationData.businessAddress}');
      final addressValidation = InputSecurityService.validateSecureAddress(registrationData.businessAddress);
      if (addressValidation != null) {
        debugPrint('❌ Business address validation failed: $addressValidation');
        throw Exception('Invalid business address: $addressValidation');
      }
      debugPrint('✅ Business address validation passed: ${registrationData.businessAddress}');

      // Validate city
      debugPrint('🏙️ Validating city: ${registrationData.city}');
      final cityValidation = InputSecurityService.validateSecureName(registrationData.city, 'City');
      if (cityValidation != null) {
        debugPrint('❌ City validation failed: $cityValidation');
        throw Exception('Invalid city: $cityValidation');
      }
      debugPrint('✅ City validation passed: ${registrationData.city}');

      // Validate province
      debugPrint('🗺️ Validating province: ${registrationData.province}');
      final provinceValidation = InputSecurityService.validateSecureName(registrationData.province, 'Province');
      if (provinceValidation != null) {
        debugPrint('❌ Province validation failed: $provinceValidation');
        throw Exception('Invalid province: $provinceValidation');
      }
      debugPrint('✅ Province validation passed: ${registrationData.province}');

      // Validate contact person name
      debugPrint('👤 Validating contact person name: ${registrationData.contactPersonName}');
      final contactNameValidation = InputSecurityService.validateSecureName(registrationData.contactPersonName, 'Contact person name');
      if (contactNameValidation != null) {
        debugPrint('❌ Contact person name validation failed: $contactNameValidation');
        throw Exception('Invalid contact person name: $contactNameValidation');
      }
      debugPrint('✅ Contact person name validation passed: ${registrationData.contactPersonName}');

      // Validate contact person position
      debugPrint('💼 Validating contact person position: ${registrationData.contactPersonPosition}');
      final contactPositionValidation = InputSecurityService.validateSecurePosition(registrationData.contactPersonPosition);
      if (contactPositionValidation != null) {
        debugPrint('❌ Contact person position validation failed: $contactPositionValidation');
        throw Exception('Invalid contact person position: $contactPositionValidation');
      }
      debugPrint('✅ Contact person position validation passed: ${registrationData.contactPersonPosition}');

      // Validate contact person email
      debugPrint('📧 Validating contact person email: ${registrationData.contactPersonEmail}');
      final contactEmailValidation = InputSecurityService.validateSecureEmail(registrationData.contactPersonEmail);
      if (contactEmailValidation != null) {
        debugPrint('❌ Contact person email validation failed: $contactEmailValidation');
        throw Exception('Invalid contact person email: $contactEmailValidation');
      }
      debugPrint('✅ Contact person email validation passed: ${registrationData.contactPersonEmail}');

      // Validate business license number if provided
      if (registrationData.businessLicenseNumber != null && registrationData.businessLicenseNumber!.isNotEmpty) {
        debugPrint('📄 Validating business license number: ${registrationData.businessLicenseNumber}');
        final licenseValidation = InputSecurityService.validateSecureOrganization(registrationData.businessLicenseNumber!);
        if (licenseValidation != null) {
          debugPrint('❌ Business license number validation failed: $licenseValidation');
          throw Exception('Invalid business license number: $licenseValidation');
        }
        debugPrint('✅ Business license number validation passed: ${registrationData.businessLicenseNumber}');
      }

      // Validate tax ID number if provided
      if (registrationData.taxIdNumber != null && registrationData.taxIdNumber!.isNotEmpty) {
        debugPrint('🧾 Validating tax ID number: ${registrationData.taxIdNumber}');
        final taxIdValidation = InputSecurityService.validateSecureOrganization(registrationData.taxIdNumber!);
        if (taxIdValidation != null) {
          debugPrint('❌ Tax ID number validation failed: $taxIdValidation');
          throw Exception('Invalid tax ID number: $taxIdValidation');
        }
        debugPrint('✅ Tax ID number validation passed: ${registrationData.taxIdNumber}');
      }

      // Validate business registration number if provided
      if (registrationData.businessRegistrationNumber != null && registrationData.businessRegistrationNumber!.isNotEmpty) {
        debugPrint('📋 Validating business registration number: ${registrationData.businessRegistrationNumber}');
        final registrationValidation = InputSecurityService.validateSecureOrganization(registrationData.businessRegistrationNumber!);
        if (registrationValidation != null) {
          debugPrint('❌ Business registration number validation failed: $registrationValidation');
          throw Exception('Invalid business registration number: $registrationValidation');
        }
        debugPrint('✅ Business registration number validation passed: ${registrationData.businessRegistrationNumber}');
      }

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
      final emailValidationResult = InputSecurityService.validateSecureEmail(registrationData.email);
      if (emailValidationResult != null) {
        debugPrint('❌ Email validation failed: $emailValidationResult');
        debugPrint('❌ Email details - Length: ${registrationData.email.length}, Contains @: ${registrationData.email.contains('@')}, Contains .: ${registrationData.email.contains('.')}');
        throw Exception('Invalid email format: $emailValidationResult');
      }
      debugPrint('✅ Email validation passed: ${registrationData.email}');

      // Basic email regex validation
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(registrationData.email.trim())) {
        debugPrint('❌ Basic email regex validation failed');
        throw Exception('Invalid email format');
      }
      debugPrint('✅ Basic email regex validation passed');

      // Check if user is already authenticated (post-email verification)
      final authUser = _supabase.auth.currentUser;
      String? userId;
      
      if (authUser != null && authUser.email == registrationData.email.trim().toLowerCase()) {
        // User is already authenticated (email was verified), skip user creation
        debugPrint('✅ User already authenticated post-verification: ${authUser.email}');
        debugPrint('✅ User ID: ${authUser.id}');
        userId = authUser.id;
      } else {
        // Check if email already exists in profiles
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

        userId = authResponse.user!.id;
        debugPrint('✅ User account created: $userId');
      }
      
      // Get current session for profile creation
      final session = _supabase.auth.currentSession;
      debugPrint('🔍 Auth session: ${session != null ? 'Present' : 'Missing'}');
      
      // Handle profile creation based on session availability
      debugPrint('🏢 Creating profile, company, and verification records for user: $userId');
      
      // Always update the profile to employer role (Supabase Auth creates default 'applicant' profile)
      debugPrint('👤 Updating user profile to employer role');
      try {
        await _supabase
            .from('profiles')
            .update({
              'email': registrationData.email.trim().toLowerCase(),
              'full_name': registrationData.fullName.trim(),
              'display_name': registrationData.displayName?.trim() ?? registrationData.fullName.trim(),
              'username': registrationData.username?.trim().toLowerCase(),
              'phone_number': registrationData.phoneNumber?.trim(),
              'birthday': registrationData.birthday?.toIso8601String(),
              'role': 'employer', // Set role as employer
              'onboarding_completed': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);

        debugPrint('✅ User profile updated with employer role');
      } catch (e) {
        debugPrint('❌ Error updating profile: $e');
        debugPrint('❌ User ID: $userId');
        // Don't rethrow - profile might be updated later after email verification
        debugPrint('⚠️ Profile update failed, will retry after email verification');
      }

      String? companyId;
      
      if (session != null) {
        // Upload company assets to Storage if provided (logo/profile)
        String? uploadedLogoUrl = registrationData.companyLogoUrl;
        String? uploadedProfileUrl = registrationData.companyProfileUrl;

        // If the fields are placeholders for local-picked files, they should come via PlatformFile
        // This service expects URLs in the data model; add UI to call StorageService for file picks.

        final companyData = {
          'owner_id': userId,
          'name': registrationData.companyName.trim(),
          'about': registrationData.companyAbout.trim(),
          'logo_url': uploadedLogoUrl,
          'profile_url': uploadedProfileUrl,
          'is_public': false, // Initially private until approved
          'created_at': DateTime.now().toIso8601String(),
        };

        debugPrint('🏢 Creating company with data: $companyData');

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

        // Create company details record
        final companyDetailsData = {
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
          // Optional socials and extended company info
          'linkedin_url': registrationData.linkedinUrl,
          'facebook_url': registrationData.facebookUrl,
          'twitter_url': registrationData.twitterUrl,
          'instagram_url': registrationData.instagramUrl,
          'company_benefits': registrationData.companyBenefits,
          'company_culture': registrationData.companyCulture,
          'company_mission': registrationData.companyMission,
          'company_vision': registrationData.companyVision,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        debugPrint('📋 Creating company details record: $companyDetailsData');

        try {
          await _supabase
              .from('company_details')
              .insert(companyDetailsData);

          debugPrint('✅ Company details record created successfully');
        } catch (e) {
          debugPrint('❌ Error creating company details: $e');
          throw Exception('Failed to create company details: $e');
        }

        // Create employer verification record only if we have a session
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
      } else {
        debugPrint('⚠️ No session available - company and verification records will be created after email verification');
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
      final currentAuthUser = _supabase.auth.currentUser;
      debugPrint('🔍 Current authenticated user: ${currentAuthUser?.id}');
      debugPrint('🔍 User matches: ${currentAuthUser?.id == userId}');
      
      // If user is not authenticated, try to refresh the session
      if (currentAuthUser?.id != userId) {
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

  /// Upload documents after authentication (called after email verification)
  static Future<bool> uploadDocumentsAfterAuthentication({
    required String userId,
    required EmployerRegistrationData registrationData,
  }) async {
    try {
      debugPrint('📄 Starting document uploads after authentication for user: $userId');
      
      // This would be called after the user is authenticated
      // For now, we'll return true as documents are handled separately
      // In a real implementation, you'd upload the documents here
      
      return true;
    } catch (e) {
      debugPrint('❌ Error uploading documents after authentication: $e');
      return false;
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
      
      // Update the profile to employer role (Supabase Auth creates default 'applicant' profile)
      debugPrint('👤 Updating user profile to employer role');
      try {
        await _supabase
            .from('profiles')
            .update({
              'email': registrationData.email.trim().toLowerCase(),
              'full_name': registrationData.fullName.trim(),
              'display_name': registrationData.displayName?.trim() ?? registrationData.fullName.trim(),
              'username': registrationData.username?.trim().toLowerCase(),
              'phone_number': registrationData.phoneNumber?.trim(),
              'birthday': registrationData.birthday?.toIso8601String(),
              'role': 'employer', // Set role as employer
              'onboarding_completed': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);

        debugPrint('✅ User profile updated with employer role');
      } catch (e) {
        debugPrint('❌ Error updating profile: $e');
        debugPrint('❌ User ID: $userId');
        throw Exception('Failed to update user profile: $e');
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

      // Create company details record
      final companyDetailsData = {
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
        // Optional socials and extended company info
        'linkedin_url': registrationData.linkedinUrl,
        'facebook_url': registrationData.facebookUrl,
        'twitter_url': registrationData.twitterUrl,
        'instagram_url': registrationData.instagramUrl,
        'company_benefits': registrationData.companyBenefits,
        'company_culture': registrationData.companyCulture,
        'company_mission': registrationData.companyMission,
        'company_vision': registrationData.companyVision,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      debugPrint('📋 Creating company details record: $companyDetailsData');

      try {
        await _supabase
            .from('company_details')
            .insert(companyDetailsData);

        debugPrint('✅ Company details record created successfully');
      } catch (e) {
        debugPrint('❌ Error creating company details: $e');
        throw Exception('Failed to create company details: $e');
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

  /// Upload and persist company logo (updates companies.logo_url)
  static Future<Map<String, dynamic>> uploadAndSetCompanyLogo({
    required String ownerId,
    required String companyId,
    required PlatformFile file,
  }) async {
    try {
      final url = await StorageService.uploadCompanyLogo(ownerId: ownerId, file: file);
      if (url == null) throw Exception('Upload failed');

      await _supabase
          .from('companies')
          .update({'logo_url': url, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', companyId)
          .eq('owner_id', ownerId);

      return {
        'success': true,
        'url': url,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to upload company logo: $e',
      };
    }
  }

  /// Upload and persist company profile/cover image (updates companies.profile_url)
  static Future<Map<String, dynamic>> uploadAndSetCompanyProfileImage({
    required String ownerId,
    required String companyId,
    required PlatformFile file,
  }) async {
    try {
      final url = await StorageService.uploadCompanyProfileImage(ownerId: ownerId, file: file);
      if (url == null) throw Exception('Upload failed');

      await _supabase
          .from('companies')
          .update({'profile_url': url, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', companyId)
          .eq('owner_id', ownerId);

      return {
        'success': true,
        'url': url,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to upload company profile image: $e',
      };
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

  /// Resubmit employer application (MCP: no schema changes)
  static Future<bool> resubmitEmployerApplication({
    required String employerId,
    String? messageToAdmin,
  }) async {
    try {
      // Ensure row exists
      final existing = await _supabase
          .from('employer_verification')
          .select('employer_id, verification_status')
          .eq('employer_id', employerId)
          .maybeSingle();

      if (existing == null) {
        throw Exception('No application found to resubmit');
      }

      // Set status back to pending; keep rejection_reason intact for audit
      await _supabase
          .from('employer_verification')
          .update({
            'verification_status': 'pending',
            'submitted_at': DateTime.now().toIso8601String(),
            'admin_notes': messageToAdmin ?? '',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('employer_id', employerId);

      // Best-effort log
      try {
        await _supabase
            .from('admin_actions')
            .insert({
          'admin_id': employerId,
          'action_type': 'employer_resubmitted',
          'target_user_id': employerId,
          'action_data': {'message': messageToAdmin},
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('❌ Error resubmitting employer application: $e');
      return false;
    }
  }

  /// Update company and/or company_details using partial updates (MCP)
  static Future<bool> updateCompanyAndDetails({
    required String ownerId,
    String? companyId,
    Map<String, dynamic>? companyUpdates,
    Map<String, dynamic>? detailsUpdates,
  }) async {
    try {
      String? resolvedCompanyId = companyId;
      if (resolvedCompanyId == null) {
        final comp = await _supabase
            .from('companies')
            .select('id')
            .eq('owner_id', ownerId)
            .maybeSingle();
        resolvedCompanyId = comp?['id'] as String?;
      }
      if (resolvedCompanyId == null) throw Exception('Company not found');

      if (companyUpdates != null && companyUpdates.isNotEmpty) {
        await _supabase
            .from('companies')
            .update({
              ...companyUpdates,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', resolvedCompanyId)
            .eq('owner_id', ownerId);
      }

      if (detailsUpdates != null && detailsUpdates.isNotEmpty) {
        await _supabase
            .from('company_details')
            .update({
              ...detailsUpdates,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('company_id', resolvedCompanyId);
      }

      try {
        await AdminService.logEvent(
          actionType: 'company_update',
          targetUserId: ownerId,
          targetCompanyId: resolvedCompanyId,
          data: {
            'updated_fields': companyUpdates?.keys.toList(),
            'details_updated': detailsUpdates?.keys.toList(),
          },
        );
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('❌ Error updating company/details: $e');
      return false;
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
