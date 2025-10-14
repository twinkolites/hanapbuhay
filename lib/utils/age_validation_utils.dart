/// Utility functions for age validation across the application
/// 
/// This utility ensures consistent 18+ age validation across all screens
/// that handle birthday/date of birth input.
class AgeValidationUtils {
  /// The minimum age required for users to register/use the application
  static const int minimumAge = 18;

  /// Get the date that represents exactly the minimum age years ago from today
  /// 
  /// For example, if today is 2025-01-15 and minimumAge is 18,
  /// this returns 2007-01-15 (exactly 18 years ago)
  static DateTime getMinimumBirthDate() {
    final now = DateTime.now();
    return DateTime(now.year - minimumAge, now.month, now.day);
  }

  /// Get the date that represents exactly the minimum age years ago from a specific date
  /// 
  /// Useful for testing or when you need to calculate based on a different reference date
  static DateTime getMinimumBirthDateFrom(DateTime referenceDate) {
    return DateTime(referenceDate.year - minimumAge, referenceDate.month, referenceDate.day);
  }

  /// Check if a given birth date meets the minimum age requirement
  /// 
  /// Returns true if the person is at least [minimumAge] years old
  static bool isAgeValid(DateTime birthDate) {
    final minimumBirthDate = getMinimumBirthDate();
    return birthDate.isBefore(minimumBirthDate) || birthDate.isAtSameMomentAs(minimumBirthDate);
  }

  /// Get the age of a person based on their birth date
  /// 
  /// Returns the age in years
  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    
    // Adjust if birthday hasn't occurred this year
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    
    return age;
  }

  /// Get a user-friendly error message for age validation
  /// 
  /// Returns a string explaining the age requirement
  static String getAgeValidationErrorMessage() {
    return 'You must be at least $minimumAge years old to use this application.';
  }

  /// Get a user-friendly description of the age requirement
  /// 
  /// Returns a string describing who can use the application
  static String getAgeRequirementDescription() {
    return 'Must be $minimumAge years or older';
  }

  /// Validate that a birth date is not in the future
  /// 
  /// Returns true if the birth date is not in the future
  static bool isNotFutureDate(DateTime birthDate) {
    final now = DateTime.now();
    return birthDate.isBefore(now) || birthDate.isAtSameMomentAs(now);
  }

  /// Comprehensive validation for birth date
  /// 
  /// Returns a validation result with error message if invalid
  static BirthDateValidationResult validateBirthDate(DateTime birthDate) {
    // Check if birth date is in the future
    if (!isNotFutureDate(birthDate)) {
      return BirthDateValidationResult(
        isValid: false,
        errorMessage: 'Birth date cannot be in the future.',
      );
    }

    // Check if birth date is too old (before 1900)
    if (birthDate.year < 1900) {
      return BirthDateValidationResult(
        isValid: false,
        errorMessage: 'Birth date cannot be before 1900.',
      );
    }

    // Check if age meets minimum requirement
    if (!isAgeValid(birthDate)) {
      return BirthDateValidationResult(
        isValid: false,
        errorMessage: getAgeValidationErrorMessage(),
      );
    }

    return BirthDateValidationResult(
      isValid: true,
      errorMessage: null,
    );
  }
}

/// Result of birth date validation
class BirthDateValidationResult {
  final bool isValid;
  final String? errorMessage;

  const BirthDateValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}
