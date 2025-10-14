/// Employer Registration Data Model
/// Comprehensive model for employer registration with validation
library;
import 'package:flutter/foundation.dart';

class EmployerRegistrationData {
  // Personal Information
  final String fullName;
  final String email;
  final String password;
  final String? phoneNumber;
  final String? displayName;
  final String? username;
  final DateTime? birthday;

  // Company Information
  final String companyName;
  final String companyAbout;
  final String? companyWebsite;
  final String? companyLogoUrl;
  final String? companyProfileUrl;

  // Business Information
  final String businessAddress;
  final String city;
  final String province;
  final String postalCode;
  final String country;
  final String industry;
  final String companySize;
  final String businessType;

  // Legal Information
  final String? businessLicenseNumber;
  final String? taxIdNumber;
  final String? businessRegistrationNumber;
  final String? businessLicenseUrl;
  final String? taxIdDocumentUrl;
  final String? businessRegistrationUrl;

  // Contact Information
  final String contactPersonName;
  final String contactPersonPosition;
  final String contactPersonEmail;
  final String? contactPersonPhone;

  // Additional Information
  final String? linkedinUrl;
  final String? facebookUrl;
  final String? twitterUrl;
  final String? instagramUrl;
  final List<String>? companyBenefits;
  final String? companyCulture;
  final String? companyMission;
  final String? companyVision;

  // Verification Status
  final String verificationStatus;
  final String? adminNotes;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final String? verifiedBy;

  const EmployerRegistrationData({
    required this.fullName,
    required this.email,
    required this.password,
    this.phoneNumber,
    this.displayName,
    this.username,
    this.birthday,
    required this.companyName,
    required this.companyAbout,
    this.companyWebsite,
    this.companyLogoUrl,
    this.companyProfileUrl,
    required this.businessAddress,
    required this.city,
    required this.province,
    required this.postalCode,
    required this.country,
    required this.industry,
    required this.companySize,
    required this.businessType,
    this.businessLicenseNumber,
    this.taxIdNumber,
    this.businessRegistrationNumber,
    this.businessLicenseUrl,
    this.taxIdDocumentUrl,
    this.businessRegistrationUrl,
    required this.contactPersonName,
    required this.contactPersonPosition,
    required this.contactPersonEmail,
    this.contactPersonPhone,
    this.linkedinUrl,
    this.facebookUrl,
    this.twitterUrl,
    this.instagramUrl,
    this.companyBenefits,
    this.companyCulture,
    this.companyMission,
    this.companyVision,
    this.verificationStatus = 'pending',
    this.adminNotes,
    this.rejectionReason,
    this.submittedAt,
    this.verifiedAt,
    this.verifiedBy,
  });

  /// Create from JSON
  factory EmployerRegistrationData.fromJson(Map<String, dynamic> json) {
    return EmployerRegistrationData(
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      phoneNumber: json['phone_number'],
      displayName: json['display_name'],
      username: json['username'],
      birthday: json['birthday'] != null ? DateTime.parse(json['birthday']) : null,
      companyName: json['company_name'] ?? '',
      companyAbout: json['company_about'] ?? '',
      companyWebsite: json['company_website'],
      companyLogoUrl: json['company_logo_url'],
      companyProfileUrl: json['company_profile_url'],
      businessAddress: json['business_address'] ?? '',
      city: json['city'] ?? '',
      province: json['province'] ?? '',
      postalCode: json['postal_code'] ?? '',
      country: json['country'] ?? '',
      industry: json['industry'] ?? '',
      companySize: json['company_size'] ?? '',
      businessType: json['business_type'] ?? '',
      businessLicenseNumber: json['business_license_number'],
      taxIdNumber: json['tax_id_number'],
      businessRegistrationNumber: json['business_registration_number'],
      businessLicenseUrl: json['business_license_url'],
      taxIdDocumentUrl: json['tax_id_document_url'],
      businessRegistrationUrl: json['business_registration_url'],
      contactPersonName: json['contact_person_name'] ?? '',
      contactPersonPosition: json['contact_person_position'] ?? '',
      contactPersonEmail: json['contact_person_email'] ?? '',
      contactPersonPhone: json['contact_person_phone'],
      linkedinUrl: json['linkedin_url'],
      facebookUrl: json['facebook_url'],
      twitterUrl: json['twitter_url'],
      instagramUrl: json['instagram_url'],
      companyBenefits: json['company_benefits'] != null 
          ? List<String>.from(json['company_benefits']) 
          : null,
      companyCulture: json['company_culture'],
      companyMission: json['company_mission'],
      companyVision: json['company_vision'],
      verificationStatus: json['verification_status'] ?? 'pending',
      adminNotes: json['admin_notes'],
      rejectionReason: json['rejection_reason'],
      submittedAt: json['submitted_at'] != null 
          ? DateTime.parse(json['submitted_at']) 
          : null,
      verifiedAt: json['verified_at'] != null 
          ? DateTime.parse(json['verified_at']) 
          : null,
      verifiedBy: json['verified_by'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'email': email,
      'password': password,
      'phone_number': phoneNumber,
      'display_name': displayName,
      'username': username,
      'birthday': birthday?.toIso8601String(),
      'company_name': companyName,
      'company_about': companyAbout,
      'company_website': companyWebsite,
      'company_logo_url': companyLogoUrl,
      'company_profile_url': companyProfileUrl,
      'business_address': businessAddress,
      'city': city,
      'province': province,
      'postal_code': postalCode,
      'country': country,
      'industry': industry,
      'company_size': companySize,
      'business_type': businessType,
      'business_license_number': businessLicenseNumber,
      'tax_id_number': taxIdNumber,
      'business_registration_number': businessRegistrationNumber,
      'business_license_url': businessLicenseUrl,
      'tax_id_document_url': taxIdDocumentUrl,
      'business_registration_url': businessRegistrationUrl,
      'contact_person_name': contactPersonName,
      'contact_person_position': contactPersonPosition,
      'contact_person_email': contactPersonEmail,
      'contact_person_phone': contactPersonPhone,
      'linkedin_url': linkedinUrl,
      'facebook_url': facebookUrl,
      'twitter_url': twitterUrl,
      'instagram_url': instagramUrl,
      'company_benefits': companyBenefits,
      'company_culture': companyCulture,
      'company_mission': companyMission,
      'company_vision': companyVision,
      'verification_status': verificationStatus,
      'admin_notes': adminNotes,
      'rejection_reason': rejectionReason,
      'submitted_at': submittedAt?.toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
      'verified_by': verifiedBy,
    };
  }

  /// Create a copy with updated fields
  EmployerRegistrationData copyWith({
    String? fullName,
    String? email,
    String? password,
    String? phoneNumber,
    String? displayName,
    String? username,
    DateTime? birthday,
    String? companyName,
    String? companyAbout,
    String? companyWebsite,
    String? companyLogoUrl,
    String? companyProfileUrl,
    String? businessAddress,
    String? city,
    String? province,
    String? postalCode,
    String? country,
    String? industry,
    String? companySize,
    String? businessType,
    String? businessLicenseNumber,
    String? taxIdNumber,
    String? businessRegistrationNumber,
    String? businessLicenseUrl,
    String? taxIdDocumentUrl,
    String? businessRegistrationUrl,
    String? contactPersonName,
    String? contactPersonPosition,
    String? contactPersonEmail,
    String? contactPersonPhone,
    String? linkedinUrl,
    String? facebookUrl,
    String? twitterUrl,
    String? instagramUrl,
    List<String>? companyBenefits,
    String? companyCulture,
    String? companyMission,
    String? companyVision,
    String? verificationStatus,
    String? adminNotes,
    String? rejectionReason,
    DateTime? submittedAt,
    DateTime? verifiedAt,
    String? verifiedBy,
  }) {
    return EmployerRegistrationData(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      birthday: birthday ?? this.birthday,
      companyName: companyName ?? this.companyName,
      companyAbout: companyAbout ?? this.companyAbout,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      companyProfileUrl: companyProfileUrl ?? this.companyProfileUrl,
      businessAddress: businessAddress ?? this.businessAddress,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      industry: industry ?? this.industry,
      companySize: companySize ?? this.companySize,
      businessType: businessType ?? this.businessType,
      businessLicenseNumber: businessLicenseNumber ?? this.businessLicenseNumber,
      taxIdNumber: taxIdNumber ?? this.taxIdNumber,
      businessRegistrationNumber: businessRegistrationNumber ?? this.businessRegistrationNumber,
      businessLicenseUrl: businessLicenseUrl ?? this.businessLicenseUrl,
      taxIdDocumentUrl: taxIdDocumentUrl ?? this.taxIdDocumentUrl,
      businessRegistrationUrl: businessRegistrationUrl ?? this.businessRegistrationUrl,
      contactPersonName: contactPersonName ?? this.contactPersonName,
      contactPersonPosition: contactPersonPosition ?? this.contactPersonPosition,
      contactPersonEmail: contactPersonEmail ?? this.contactPersonEmail,
      contactPersonPhone: contactPersonPhone ?? this.contactPersonPhone,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      twitterUrl: twitterUrl ?? this.twitterUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      companyBenefits: companyBenefits ?? this.companyBenefits,
      companyCulture: companyCulture ?? this.companyCulture,
      companyMission: companyMission ?? this.companyMission,
      companyVision: companyVision ?? this.companyVision,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      adminNotes: adminNotes ?? this.adminNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
    );
  }

  /// Validate required fields
  List<String> validateRequiredFields() {
    final errors = <String>[];
    
    if (fullName.trim().isEmpty) errors.add('Full name is required');
    if (email.trim().isEmpty) errors.add('Email is required');
    if (password.isEmpty) errors.add('Password is required');
    if (companyName.trim().isEmpty) errors.add('Company name is required');
    if (companyAbout.trim().isEmpty) errors.add('Company description is required');
    if (businessAddress.trim().isEmpty) errors.add('Business address is required');
    if (city.trim().isEmpty) errors.add('City is required');
    if (province.trim().isEmpty) errors.add('Province is required');
    if (postalCode.trim().isEmpty) errors.add('Postal code is required');
    if (country.trim().isEmpty) errors.add('Country is required');
    if (industry.trim().isEmpty) errors.add('Industry is required');
    if (companySize.trim().isEmpty) errors.add('Company size is required');
    if (businessType.trim().isEmpty) errors.add('Business type is required');
    if (contactPersonName.trim().isEmpty) errors.add('Contact person name is required');
    if (contactPersonPosition.trim().isEmpty) errors.add('Contact person position is required');
    if (contactPersonEmail.trim().isEmpty) errors.add('Contact person email is required');
    
    return errors;
  }

  /// Validate email format
  bool isValidEmail() {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate contact person phone number format (Philippines)
  bool isValidContactPersonPhone() {
    if (contactPersonPhone == null || contactPersonPhone!.trim().isEmpty) return true;
    
    // Remove all non-digit characters for validation
    final digitsOnly = contactPersonPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Check length - accept 10, 11, or 12 digits
    if (digitsOnly.length < 10 || digitsOnly.length > 12) {
      return false;
    }
    
    // Handle different formats:
    // 09XXXXXXXXX (11 digits with leading 0)
    // 9XXXXXXXXX (10 digits)
    // +639XXXXXXXXX (12 digits with country code)
    // 639XXXXXXXXX (11 digits with country code)
    
    String normalizedDigits = digitsOnly;
    
    // Remove country code if present
    if (digitsOnly.length == 12 && digitsOnly.startsWith('63')) {
      normalizedDigits = digitsOnly.substring(2);
    } else if (digitsOnly.length == 11 && digitsOnly.startsWith('63')) {
      normalizedDigits = digitsOnly.substring(2);
    }
    
    // Remove leading 0 if present
    if (normalizedDigits.length == 11 && normalizedDigits.startsWith('0')) {
      normalizedDigits = normalizedDigits.substring(1);
    }
    
    // Must be 10 digits after normalization
    if (normalizedDigits.length != 10) {
      return false;
    }
    
    // Must start with 9 (Philippine mobile prefix)
    return normalizedDigits.startsWith('9');
  }

  /// Validate phone number format (Philippines)
  bool isValidPhoneNumber() {
    if (phoneNumber == null || phoneNumber!.trim().isEmpty) return true;
    
    // Remove all non-digit characters for validation
    final digitsOnly = phoneNumber!.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Check length - accept 10, 11, or 12 digits
    if (digitsOnly.length < 10 || digitsOnly.length > 12) {
      return false;
    }
    
    // Handle different formats:
    // 09XXXXXXXXX (11 digits with leading 0)
    // 9XXXXXXXXX (10 digits)
    // +639XXXXXXXXX (12 digits with country code)
    // 639XXXXXXXXX (11 digits with country code)
    
    String normalizedDigits = digitsOnly;
    
    // Remove country code if present
    if (digitsOnly.length == 12 && digitsOnly.startsWith('63')) {
      normalizedDigits = digitsOnly.substring(2);
    } else if (digitsOnly.length == 11 && digitsOnly.startsWith('63')) {
      normalizedDigits = digitsOnly.substring(2);
    }
    
    // Remove leading 0 if present
    if (normalizedDigits.length == 11 && normalizedDigits.startsWith('0')) {
      normalizedDigits = normalizedDigits.substring(1);
    }
    
    // Must be 10 digits after normalization
    if (normalizedDigits.length != 10) {
      return false;
    }
    
    // Must start with 9 (Philippine mobile prefix)
    return normalizedDigits.startsWith('9');
  }

  /// Validate website URL format
  bool isValidWebsite() {
    if (companyWebsite == null || companyWebsite!.trim().isEmpty) return true;
    return RegExp(r'^https?:\/\/.+').hasMatch(companyWebsite!.trim());
  }

  /// Get validation errors with detailed debugging
  List<String> getValidationErrors() {
    final errors = validateRequiredFields();
    
    if (!isValidEmail()) errors.add('Invalid email format');
    
    // Debug phone number validation
    if (phoneNumber != null && phoneNumber!.trim().isNotEmpty) {
      debugPrint('📱 Validating personal phone: $phoneNumber');
      if (!isValidPhoneNumber()) {
        errors.add('Invalid phone number format');
        debugPrint('❌ Personal phone validation failed: $phoneNumber');
      } else {
        debugPrint('✅ Personal phone validation passed: $phoneNumber');
      }
    }
    
    // Debug contact person phone validation
    if (contactPersonPhone != null && contactPersonPhone!.trim().isNotEmpty) {
      debugPrint('📱 Validating contact person phone: $contactPersonPhone');
      if (!isValidContactPersonPhone()) {
        errors.add('Invalid contact person phone number format');
        debugPrint('❌ Contact person phone validation failed: $contactPersonPhone');
      } else {
        debugPrint('✅ Contact person phone validation passed: $contactPersonPhone');
      }
    }
    
    if (!isValidWebsite()) errors.add('Invalid website URL format');
    
    return errors;
  }

  /// Check if all required fields are filled
  bool get isComplete {
    return validateRequiredFields().isEmpty && 
           isValidEmail() && 
           isValidPhoneNumber() && 
           isValidContactPersonPhone() &&
           isValidWebsite();
  }

  @override
  String toString() {
    return 'EmployerRegistrationData(fullName: $fullName, email: $email, companyName: $companyName, verificationStatus: $verificationStatus)';
  }
}
