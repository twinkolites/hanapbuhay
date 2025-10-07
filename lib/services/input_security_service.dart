class InputSecurityService {
  /// Sanitize text input to prevent injection attacks
  static String sanitizeText(String input) {
    if (input.isEmpty) return input;

    return input
        .replaceAll(RegExp(r'[<>]'), '') // Remove HTML tags
        .replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '') // Remove control chars
        .trim();
  }

  /// Comprehensive suspicious pattern detection for maximum security
  static String? detectSuspiciousPatterns(String input, String fieldName) {
    if (input.isEmpty) return null;

    // SQL Injection Patterns
    final sqlPatterns = [
      r'\b(select|union|insert|update|delete|drop|create|alter|exec|execute)\b',
      r';\s*(select|union|insert|update|delete|drop|create|alter|exec)',
      r'/\*.*?\*/', // SQL comments
      r'--\s', // SQL line comments
      r';\s*(shutdown|backup|restore)',
      r'\b(xp_cmdshell|sp_executesql|sp_configure)\b',
    ];

    for (final pattern in sqlPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
        return '$fieldName contains suspicious SQL injection patterns';
      }
    }

    // Command Injection Patterns
    final commandPatterns = [
      r'[;&|`$]\s*(cat|ls|dir|type|find|grep|awk|sed|cut|sort)',
      r'\b(cmd|bash|sh|powershell|exec|system|shell_exec|passthru)\b',
      r'[;&|`$]\s*(rm|del|erase|format|rd|rmdir)',
      r'[;&|`$]\s*(wget|curl|ftp|scp|ssh)',
      r'\b(eval|assert|system|exec|shell_exec|passthru|proc_open|popen)\b',
    ];

    for (final pattern in commandPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
        return '$fieldName contains suspicious command injection patterns';
      }
    }

    // Path Traversal and File Inclusion
    final pathPatterns = [
      r'\.\./', // Directory traversal
      r'\.\.\\', // Windows directory traversal
      r'%2e%2e%2f', // URL encoded ../
      r'%2e%2e%5c', // URL encoded ..\
      r'\b(include|require|include_once|require_once)\b.*\.\.',
      r'\b(file_get_contents|fopen|readfile)\b.*\.\.',
    ];

    for (final pattern in pathPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
        return '$fieldName contains suspicious path traversal patterns';
      }
    }

    // XSS and Script Injection (enhanced)
    final xssPatterns = [
      r'<script[^>]*>.*?</script>',
      r'javascript:',
      r'vbscript:',
      r'onload\s*=',
      r'onerror\s*=',
      r'onclick\s*=',
      r'onmouseover\s*=',
      r'<iframe[^>]*>',
      r'<object[^>]*>',
      r'<embed[^>]*>',
      r'data:text/html',
      r'data:text/javascript',
      r'expression\s*\(',
      r'behavior\s*:',
      r'<link[^>]*stylesheet',
      r'@import\s+url',
      r'<meta[^>]*http-equiv',
      r'<form[^>]*action\s*=',
    ];

    for (final pattern in xssPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
        return '$fieldName contains suspicious script injection patterns';
      }
    }

    // Null Byte and Control Character Injections
    if (input.contains('\x00') || input.contains('%00')) {
      return '$fieldName contains null byte injection attempts';
    }

    // Excessive Special Characters (potential encoding abuse)
    final specialCharCount = RegExp(r'[%&<>]').allMatches(input).length;
    if (specialCharCount > input.length * 0.3) {
      // More than 30% special chars
      return '$fieldName contains excessive special characters';
    }

    // Base64-like patterns (potential encoded malware)
    if (RegExp(
      r'[A-Za-z0-9+/=]{50,}',
    ).hasMatch(input.replaceAll(RegExp(r'\s'), ''))) {
      return '$fieldName contains suspicious encoded content';
    }

    // Hex-encoded content patterns
    if (RegExp(r'\\x[0-9a-fA-F]{2}').hasMatch(input) ||
        RegExp(r'%[0-9a-fA-F]{2}').allMatches(input).length > 5) {
      return '$fieldName contains suspicious hex-encoded content';
    }

    // Unicode exploits and right-to-left override
    if (input.contains('\u202E') || // Right-to-Left Override
        input.contains('\u202D') || // Left-to-Right Override
        input.contains('\u200F') || // Right-to-Left Mark
        input.contains('\u200E')) {
      // Left-to-Right Mark
      return '$fieldName contains suspicious Unicode control characters';
    }

    // Excessive repetition (DoS attempts)
    if (RegExp(r'(.)\1{100,}').hasMatch(input)) {
      return '$fieldName contains excessive character repetition';
    }

    // Suspicious protocol handlers
    final protocolPatterns = [
      r'\b(file|ftp|ldap|ldaps|news|nntp|mailto|telnet|irc|dict|dns)\s*:',
      r'\b(data|blob)\s*:',
      r'\b(chrome|chrome-extension|moz-extension)\s*:',
    ];

    for (final pattern in protocolPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
        return '$fieldName contains suspicious protocol usage';
      }
    }

    // PHP/ASP injection patterns
    final serverPatterns = [
      r'\$\{.*?\}', // Variable interpolation
      r'<\%.*?\%>', // ASP tags
      r'<\?.*?\?>', // PHP tags
      r'\b(eval|assert|preg_replace.*e)\b',
    ];

    for (final pattern in serverPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
        return '$fieldName contains suspicious server-side script patterns';
      }
    }

    // No suspicious patterns detected
    return null;
  }

  /// Enhanced username validation with security checks
  static String? validateSecureUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }

    final sanitized = sanitizeText(value);
    if (sanitized != value) {
      return 'Invalid characters in username';
    }

    // Length checks
    if (sanitized.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (sanitized.length > 30) {
      return 'Username must be less than 30 characters';
    }

    // Only allow alphanumeric, underscore, and dot
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_.]+$');
    if (!usernameRegex.hasMatch(sanitized)) {
      return 'Username can only contain letters, numbers, dots, and underscores';
    }

    // Prevent consecutive special characters
    if (sanitized.contains('..') || sanitized.contains('__')) {
      return 'Username cannot contain consecutive dots or underscores';
    }

    return null;
  }

  /// Enhanced password validation following OWASP guidelines for maximum security
  static String? validateSecurePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    final sanitized = sanitizeText(value);

    // OWASP recommends minimum 8 characters for strong passwords
    if (sanitized.length < 8) {
      return 'Password must be at least 8 characters for security';
    }
    if (sanitized.length > 64) {
      return 'Password must be less than 64 characters';
    }

    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(sanitized)) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(sanitized)) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for at least one number
    if (!RegExp(r'[0-9]').hasMatch(sanitized)) {
      return 'Password must contain at least one number';
    }

    // OWASP recommends allowing special characters and optionally requiring them for stronger passwords
    // Require at least one special character for maximum security
    final specialChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
    bool hasSpecialChar = false;
    for (final char in specialChars.split('')) {
      if (sanitized.contains(char)) {
        hasSpecialChar = true;
        break;
      }
    }
    if (!hasSpecialChar) {
      return 'Password must contain at least one special character like !@#\$%^&*()';
    }

    // Additional security checks for common weak patterns
    final lowerPassword = sanitized.toLowerCase();

    // Check for sequential characters (e.g., 123, abc)
    if (RegExp(
      r'012|123|234|345|456|567|678|789|abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz',
    ).hasMatch(lowerPassword)) {
      return 'Password cannot contain sequential characters like "123" or "abc"';
    }

    // Check for repeated characters (more than 3 consecutive same characters)
    if (RegExp(r'(.)\1{3,}').hasMatch(sanitized)) {
      return 'Password cannot contain more than 3 consecutive identical characters';
    }

    // Check for common dictionary words (basic check)
    final commonWords = [
      'password',
      'admin',
      'user',
      'login',
      'welcome',
      'qwerty',
      'admin123',
      'password123',
    ];
    if (commonWords.any((word) => lowerPassword.contains(word))) {
      return 'Password cannot contain common words or patterns';
    }

    // Check for keyboard patterns (basic detection)
    if (RegExp(
      r'qwerty|asdf|zxcv|qaz|wsx|edc|rfv|tgb|yhn|ujm',
      caseSensitive: false,
    ).hasMatch(sanitized)) {
      return 'Password cannot contain common keyboard patterns';
    }

    // Maximum suspicious pattern detection for passwords
    final suspiciousCheck = detectSuspiciousPatterns(sanitized, 'Password');
    if (suspiciousCheck != null) {
      return suspiciousCheck;
    }

    return null;
  }

  /// Inclusive name validation that respects cultural diversity
  static String? validateSecureName(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    final trimmed = value.trim();

    // Length checks
    if (trimmed.isEmpty) {
      return '$fieldName cannot be empty';
    }
    if (trimmed.length > 50) {
      return '$fieldName must be less than 50 characters';
    }

    // Allow culturally diverse names: letters, spaces, hyphens, apostrophes, and common diacritics
    // This includes Latin characters, accented characters, and common name symbols
    final nameRegex = RegExp(r"^[a-zA-ZÀ-ÿ\u00C0-\u017F\s\-']+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return '$fieldName can only contain letters, spaces, hyphens, and apostrophes';
    }

    // Prevent multiple consecutive spaces or special characters
    if (RegExp(r'\s{2,}').hasMatch(trimmed) ||
        RegExp(r'--+').hasMatch(trimmed) ||
        RegExp(r"''+").hasMatch(trimmed)) {
      return '$fieldName cannot contain consecutive spaces or special characters';
    }

    // Prevent names that start or end with special characters
    if (trimmed.startsWith('-') ||
        trimmed.startsWith("'") ||
        trimmed.endsWith('-') ||
        trimmed.endsWith("'")) {
      return '$fieldName cannot start or end with special characters';
    }

    return null;
  }

  /// Comprehensive email validation following industry best practices
  static String? validateSecureEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email address is required';
    }

    final trimmed = value.trim();

    // Length validation
    if (trimmed.length > 254) {
      return 'Email address is too long';
    }

    // Basic format validation - comprehensive but reliable regex
    // Supports most valid email formats while avoiding overly complex patterns
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      caseSensitive: false,
    );

    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }

    // Extract local part (before @) for additional validation
    final atIndex = trimmed.indexOf('@');
    final localPart = trimmed.substring(0, atIndex);

    // RFC 5322 compliance: periods cannot be at start or end of local part
    if (localPart.startsWith('.') || localPart.endsWith('.')) {
      return 'Email address cannot start or end with a period';
    }

    // RFC 5322 compliance: no consecutive periods in local part
    if (localPart.contains('..')) {
      return 'Email address cannot contain consecutive periods';
    }

    // Extract domain for additional checks
    final domain = trimmed.substring(atIndex + 1).toLowerCase();

    // Check for common disposable email domains (basic list)
    final disposableDomains = {
      '10minutemail.com',
      'temp-mail.org',
      'guerrillamail.com',
      'mailinator.com',
      'throwaway.email',
      'yopmail.com',
      'tempail.com',
      'maildrop.cc',
      'getnada.com',
    };

    if (disposableDomains.contains(domain)) {
      return 'Temporary email addresses are not allowed. Please use a permanent email.';
    }

    // Check for suspicious patterns that might indicate fake emails
    if (RegExp(r'\d{8,}@').hasMatch(trimmed)) {
      return 'This email format appears suspicious. Please use a valid email address.';
    }

    // Only check for obvious security issues, not general suspicious patterns
    // This prevents legitimate emails from being flagged
    if (trimmed.contains('<') || trimmed.contains('>') || trimmed.contains('"')) {
      return 'Email address contains invalid characters';
    }

    return null;
  }

  /// Philippine phone number validation with auto-formatting support
  static String? validatePhilippinePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove all non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');

    // Check length - accept 10, 11, or 12 digits
    if (digitsOnly.length < 10 || digitsOnly.length > 11) {
      return 'Phone number must be 10-11 digits';
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
      return 'Invalid phone number format';
    }

    // Must start with 9 (Philippine mobile prefix)
    if (!normalizedDigits.startsWith('9')) {
      return 'Phone number must start with 9';
    }

    return null;
  }

  /// Auto-format Philippine phone number as user types
  static String formatPhilippinePhone(String value) {
    // Remove all non-digit characters
    String digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    // Limit to 10 digits (excluding country code)
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    // Format as XXX-XXX-XXXX
    if (digits.length >= 6) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length >= 3) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else {
      return digits;
    }
  }

  /// Emergency contact name validation - same as regular name validation
  static String? validateEmergencyContactName(String? value) {
    return validateSecureName(value, 'Emergency contact name');
  }

  /// Relationship validation for emergency contacts
  static String? validateEmergencyRelationship(String? value) {
    if (value == null || value.isEmpty) {
      return 'Relationship is required';
    }

    final trimmed = value.trim();

    // Length checks
    if (trimmed.isEmpty) {
      return 'Relationship cannot be empty';
    }
    if (trimmed.length > 30) {
      return 'Relationship must be less than 30 characters';
    }

    // Allow letters, spaces, hyphens, and apostrophes for relationship names
    // More permissive than names since relationships can include terms like "Mother-in-law"
    final relationshipRegex = RegExp(r"^[a-zA-ZÀ-ÿ\u00C0-\u017F\s\-']+$");
    if (!relationshipRegex.hasMatch(trimmed)) {
      return 'Relationship can only contain letters, spaces, hyphens, and apostrophes';
    }

    // Prevent multiple consecutive spaces or special characters
    if (RegExp(r'\s{2,}').hasMatch(trimmed) ||
        RegExp(r'--+').hasMatch(trimmed) ||
        RegExp(r"''+").hasMatch(trimmed)) {
      return 'Relationship cannot contain consecutive spaces or special characters';
    }

    // Prevent relationships that start or end with special characters
    if (trimmed.startsWith('-') ||
        trimmed.startsWith("'") ||
        trimmed.endsWith('-') ||
        trimmed.endsWith("'")) {
      return 'Relationship cannot start or end with special characters';
    }

    // Common relationship validation - allow but don't require standard terms
    // This is permissive to support cultural variations and custom relationships

    return null;
  }

  static String? validateSecureAddress(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Address details are optional
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null; // Allow empty after trimming
    }

    // Length validation
    if (trimmed.length > 200) {
      return 'Address details must be less than 200 characters';
    }

    // Security: Remove HTML tags and control characters
    final sanitized = sanitizeText(trimmed);
    if (sanitized != trimmed) {
      return 'Address contains invalid characters';
    }

    // Allow common address characters: letters, numbers, spaces, commas, periods, hyphens, slashes, hash symbols
    final addressRegex = RegExp(r"^[a-zA-ZÀ-ÿ\u00C0-\u017F0-9\s,.\-#/]+$");
    if (!addressRegex.hasMatch(sanitized)) {
      return 'Address can only contain letters, numbers, spaces, commas, periods, hyphens, slashes, and hash symbols';
    }

    // Prevent excessive consecutive special characters
    if (RegExp(r'[,.]{3,}').hasMatch(sanitized) ||
        RegExp(r'[-#]{2,}').hasMatch(sanitized) ||
        RegExp(r'[\s]{3,}').hasMatch(sanitized)) {
      return 'Address cannot contain excessive consecutive special characters or spaces';
    }

    // Prevent address starting or ending with special characters (except numbers for house numbers)
    if (RegExp(r'^[,.\-#/]|[,.#]$').hasMatch(sanitized)) {
      return 'Address cannot start or end with special characters';
    }

    // Common security checks for addresses
    final lowerAddress = sanitized.toLowerCase();

    // Check for suspicious patterns (basic detection)
    if (lowerAddress.contains('<script') ||
        lowerAddress.contains('javascript:') ||
        lowerAddress.contains('data:') ||
        lowerAddress.contains('vbscript:')) {
      return 'Address contains suspicious content';
    }

    // Check for excessive repetition (potential DoS)
    if (RegExp(r'(.)\1{10,}').hasMatch(sanitized)) {
      return 'Address contains invalid character repetition';
    }

    // Maximum suspicious pattern detection
    final suspiciousCheck = detectSuspiciousPatterns(sanitized, 'Address');
    if (suspiciousCheck != null) {
      return suspiciousCheck;
    }

    return null;
  }

  static String? validateSecureOrganization(String? value) {
    if (value == null || value.isEmpty) {
      return 'Agency/Organization is required';
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Agency/Organization cannot be empty';
    }

    // Length validation
    if (trimmed.length > 100) {
      return 'Agency/Organization name must be less than 100 characters';
    }

    // Security: Remove HTML tags and control characters
    final sanitized = sanitizeText(trimmed);
    if (sanitized != trimmed) {
      return 'Organization name contains invalid characters';
    }

    // Allow organization name characters: letters, numbers, spaces, hyphens, slashes, periods, ampersands
    final orgRegex = RegExp(r"^[a-zA-ZÀ-ÿ\u00C0-\u017F0-9\s\-/.&]+$");
    if (!orgRegex.hasMatch(sanitized)) {
      return 'Organization name can only contain letters, numbers, spaces, hyphens, slashes, periods, and ampersands';
    }

    // Prevent excessive consecutive special characters
    if (RegExp(r'[.\-&/]{3,}').hasMatch(sanitized) ||
        RegExp(r'[\s]{3,}').hasMatch(sanitized)) {
      return 'Organization name cannot contain excessive consecutive special characters or spaces';
    }

    // Prevent starting/ending with special characters
    if (RegExp(r'^[.\-&/]|[\-&/]$').hasMatch(sanitized)) {
      return 'Organization name cannot start or end with special characters';
    }

    // Common security checks
    final lowerOrg = sanitized.toLowerCase();
    if (lowerOrg.contains('<script') ||
        lowerOrg.contains('javascript:') ||
        lowerOrg.contains('data:')) {
      return 'Organization name contains suspicious content';
    }

    // Maximum suspicious pattern detection
    final suspiciousCheck = detectSuspiciousPatterns(
      sanitized,
      'Organization name',
    );
    if (suspiciousCheck != null) {
      return suspiciousCheck;
    }

    return null;
  }

  static String? validateSecurePosition(String? value) {
    if (value == null || value.isEmpty) {
      return 'Position is required';
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Position cannot be empty';
    }

    // Length validation
    if (trimmed.length > 80) {
      return 'Position must be less than 80 characters';
    }

    // Security: Remove HTML tags and control characters
    final sanitized = sanitizeText(trimmed);
    if (sanitized != trimmed) {
      return 'Position contains invalid characters';
    }

    // Allow position title characters: letters, numbers, spaces, hyphens, slashes, periods, commas, parentheses
    final positionRegex = RegExp(r"^[a-zA-ZÀ-ÿ\u00C0-\u017F0-9\s\-/.,()]+$");
    if (!positionRegex.hasMatch(sanitized)) {
      return 'Position can only contain letters, numbers, spaces, hyphens, slashes, periods, commas, and parentheses';
    }

    // Prevent excessive consecutive special characters
    if (RegExp(r'[.,\-/()]{3,}').hasMatch(sanitized) ||
        RegExp(r'[\s]{3,}').hasMatch(sanitized)) {
      return 'Position cannot contain excessive consecutive special characters or spaces';
    }

    // Prevent starting/ending with special characters
    if (RegExp(r'^[.,\-/()]|[\-/(),]$').hasMatch(sanitized)) {
      return 'Position cannot start or end with special characters';
    }

    // Common security checks
    final lowerPosition = sanitized.toLowerCase();
    if (lowerPosition.contains('<script') ||
        lowerPosition.contains('javascript:') ||
        lowerPosition.contains('data:')) {
      return 'Position contains suspicious content';
    }

    // Maximum suspicious pattern detection
    final suspiciousCheck = detectSuspiciousPatterns(sanitized, 'Position');
    if (suspiciousCheck != null) {
      return suspiciousCheck;
    }

    return null;
  }

  static String? validateSecureSpecializations(String? value) {
    if (value == null || value.isEmpty) {
      return 'Specializations are required';
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Specializations cannot be empty';
    }

    // Length validation
    if (trimmed.length > 300) {
      return 'Specializations must be less than 300 characters';
    }

    // Security: Remove HTML tags and control characters
    final sanitized = sanitizeText(trimmed);
    if (sanitized != trimmed) {
      return 'Specializations contain invalid characters';
    }

    // Allow specialization characters: letters, numbers, spaces, commas, hyphens, slashes, periods, parentheses, ampersands
    final specRegex = RegExp(r"^[a-zA-ZÀ-ÿ\u00C0-\u017F0-9\s,\-/.&()]+$");
    if (!specRegex.hasMatch(sanitized)) {
      return 'Specializations can only contain letters, numbers, spaces, commas, hyphens, slashes, periods, ampersands, and parentheses';
    }

    // Prevent excessive consecutive special characters
    if (RegExp(r'[,&\-/.()]{3,}').hasMatch(sanitized) ||
        RegExp(r'[\s]{3,}').hasMatch(sanitized)) {
      return 'Specializations cannot contain excessive consecutive special characters or spaces';
    }

    // Common security checks
    final lowerSpec = sanitized.toLowerCase();
    if (lowerSpec.contains('<script') ||
        lowerSpec.contains('javascript:') ||
        lowerSpec.contains('data:')) {
      return 'Specializations contain suspicious content';
    }

    // Check for excessive repetition
    if (RegExp(r'(.)\1{8,}').hasMatch(sanitized)) {
      return 'Specializations contain invalid character repetition';
    }

    return null;
  }

  static String? validateSecureCertification(String? value) {
    if (value == null || value.isEmpty) {
      return 'Certification name is required';
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Certification name cannot be empty';
    }

    // Length validation
    if (trimmed.length > 100) {
      return 'Certification name must be less than 100 characters';
    }

    // Security: Remove HTML tags and control characters
    final sanitized = sanitizeText(trimmed);
    if (sanitized != trimmed) {
      return 'Certification contains invalid characters';
    }

    // Allow certification characters: letters, numbers, spaces, hyphens, slashes, periods, commas, parentheses, ampersands
    final certRegex = RegExp(r"^[a-zA-ZÀ-ÿ\u00C0-\u017F0-9\s\-/.,()&]+$");
    if (!certRegex.hasMatch(sanitized)) {
      return 'Certification can only contain letters, numbers, spaces, hyphens, slashes, periods, commas, parentheses, and ampersands';
    }

    // Prevent excessive consecutive special characters
    if (RegExp(r'[,&\-/.()]{3,}').hasMatch(sanitized) ||
        RegExp(r'[\s]{3,}').hasMatch(sanitized)) {
      return 'Certification cannot contain excessive consecutive special characters or spaces';
    }

    // Prevent starting/ending with special characters
    if (RegExp(r'^[,&\-/.()]|[\-&/.(),]$').hasMatch(sanitized)) {
      return 'Certification cannot start or end with special characters';
    }

    // Common security checks
    final lowerCert = sanitized.toLowerCase();
    if (lowerCert.contains('<script') ||
        lowerCert.contains('javascript:') ||
        lowerCert.contains('data:')) {
      return 'Certification contains suspicious content';
    }

    return null;
  }

  static String? validateSecureNumeric(
    String? value,
    String fieldName, {
    int? maxValue,
    int? minValue,
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '$fieldName cannot be empty';
    }

    // Check if it's a valid number
    final number = int.tryParse(trimmed);
    if (number == null) {
      return '$fieldName must be a valid number';
    }

    // Check for negative numbers
    if (number < 0) {
      return '$fieldName cannot be negative';
    }

    // Check minimum value if provided
    if (minValue != null && number < minValue) {
      return '$fieldName cannot be less than $minValue';
    }

    // Check maximum value if provided
    if (maxValue != null && number > maxValue) {
      return '$fieldName cannot exceed $maxValue';
    }

    return null;
  }

  static String? validateSecureExperience(String? value) {
    // First validate as secure numeric with professional limits
    final numericValidation = validateSecureNumeric(
      value,
      'Years of experience',
      maxValue: 50,
      minValue: 0,
    );
    if (numericValidation != null) {
      return numericValidation;
    }

    final years = int.tryParse(value ?? '0') ?? 0;

    // Additional professional standards for emergency responders
    // Most professional responders start at 18-21 years old
    // Career spans typically don't exceed 40-45 years
    if (years > 45) {
      return 'Years of experience seems unusually high for emergency response work';
    }

    return null;
  }

  static String? validateSecureResponseCount(String? value, String fieldName) {
    // First validate as secure numeric
    final numericValidation = validateSecureNumeric(
      value,
      fieldName,
      minValue: 0,
    );
    if (numericValidation != null) {
      return numericValidation;
    }

    final count = int.tryParse(value ?? '0') ?? 0;

    // Professional limits for emergency response counts
    // Individual responder maximum in a career (very experienced responder)
    if (count > 5000) {
      return '$fieldName count seems unusually high - please verify accuracy';
    }

    return null;
  }
}
