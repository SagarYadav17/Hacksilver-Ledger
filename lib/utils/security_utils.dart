/// Security utilities for input validation, sanitization, and secure operations
class SecurityUtils {
  SecurityUtils._(); // Private constructor

  // Regex patterns for common validations
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  static final RegExp _urlRegex = RegExp(
    r'^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/[a-zA-Z0-9._%+-/]*)?$',
  );
  
  static final RegExp _numericRegex = RegExp(r'^-?[0-9]+\.?[0-9]*$');
  
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  
  static final RegExp _sqlInjectionPattern = RegExp(
    r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION|WHERE|AND|OR)\b)|(--|;|/\*|\*/|'|\"|\")",
    caseSensitive: false,
  );

  /// Validates and sanitizes a string to prevent SQL injection
  static String sanitizeInput(String input, {int maxLength = 500}) {
    if (input.isEmpty) return input;
    
    // Trim whitespace
    var sanitized = input.trim();
    
    // Limit length
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    
    // Remove potentially dangerous characters for SQL
    // Note: sqflite uses parameterized queries, but this adds defense in depth
    sanitized = sanitized
        .replaceAll("'", "''") // Escape single quotes
        .replaceAll("\x00", '') // Remove null bytes
        .replaceAll("\x1a", ''); // Remove EOF character
    
    return sanitized;
  }

  /// Validates a title/name input
  static ValidationResult validateTitle(String? title, {int maxLength = 100}) {
    if (title == null || title.isEmpty) {
      return ValidationResult.invalid('Title cannot be empty');
    }
    
    if (title.length > maxLength) {
      return ValidationResult.invalid('Title cannot exceed $maxLength characters');
    }
    
    // Check for SQL injection attempts
    if (_containsSqlInjection(title)) {
      return ValidationResult.invalid('Invalid characters in title');
    }
    
    final sanitized = sanitizeInput(title, maxLength: maxLength);
    return ValidationResult.valid(sanitized);
  }

  /// Validates an amount input
  static ValidationResult validateAmount(String? amount, {
    double minValue = 0.0,
    double maxValue = 999999999.99,
    bool allowNegative = false,
  }) {
    if (amount == null || amount.isEmpty) {
      return ValidationResult.invalid('Amount cannot be empty');
    }
    
    // Clean the input (remove commas, spaces)
    final cleaned = amount.replaceAll(',', '').replaceAll(' ', '').trim();
    
    // Check if it's a valid number
    if (!_numericRegex.hasMatch(cleaned)) {
      return ValidationResult.invalid('Please enter a valid number');
    }
    
    final value = double.tryParse(cleaned);
    if (value == null) {
      return ValidationResult.invalid('Invalid amount format');
    }
    
    // Check bounds
    if (!allowNegative && value < minValue) {
      return ValidationResult.invalid('Amount cannot be negative');
    }
    
    if (value > maxValue) {
      return ValidationResult.invalid('Amount exceeds maximum limit');
    }
    
    // Round to 2 decimal places for currency
    final rounded = double.parse(value.toStringAsFixed(2));
    
    return ValidationResult.valid(rounded);
  }

  /// Validates an interest rate
  static ValidationResult validateInterestRate(String? rate) {
    if (rate == null || rate.isEmpty) {
      return ValidationResult.valid(0.0); // 0% is valid
    }
    
    final cleaned = rate.replaceAll(',', '').trim();
    
    if (!_numericRegex.hasMatch(cleaned)) {
      return ValidationResult.invalid('Invalid interest rate');
    }
    
    final value = double.tryParse(cleaned);
    if (value == null) {
      return ValidationResult.invalid('Invalid interest rate format');
    }
    
    if (value < 0 || value > 100) {
      return ValidationResult.invalid('Interest rate must be between 0 and 100%');
    }
    
    return ValidationResult.valid(value);
  }

  /// Validates an integer (e.g., tenure months)
  static ValidationResult validateInteger(String? value, {
    int minValue = 1,
    int maxValue = 999,
    String fieldName = 'Value',
  }) {
    if (value == null || value.isEmpty) {
      return ValidationResult.invalid('$fieldName cannot be empty');
    }
    
    final cleaned = value.trim();
    
    final intValue = int.tryParse(cleaned);
    if (intValue == null) {
      return ValidationResult.invalid('$fieldName must be a whole number');
    }
    
    if (intValue < minValue) {
      return ValidationResult.invalid('$fieldName must be at least $minValue');
    }
    
    if (intValue > maxValue) {
      return ValidationResult.invalid('$fieldName cannot exceed $maxValue');
    }
    
    return ValidationResult.valid(intValue);
  }

  /// Validates a Supabase URL
  static ValidationResult validateSupabaseUrl(String? url) {
    if (url == null || url.isEmpty) {
      return ValidationResult.invalid('URL cannot be empty');
    }
    
    final trimmed = url.trim();
    
    if (!trimmed.startsWith('https://')) {
      return ValidationResult.invalid('URL must use HTTPS');
    }
    
    if (!trimmed.contains('.supabase.co')) {
      return ValidationResult.invalid('Invalid Supabase URL format');
    }
    
    if (!_urlRegex.hasMatch(trimmed)) {
      return ValidationResult.invalid('Invalid URL format');
    }
    
    return ValidationResult.valid(trimmed);
  }

  /// Validates a UUID
  static ValidationResult validateUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) {
      return ValidationResult.invalid('UUID cannot be empty');
    }
    
    if (!_uuidRegex.hasMatch(uuid.trim())) {
      return ValidationResult.invalid('Invalid UUID format');
    }
    
    return ValidationResult.valid(uuid.trim().toLowerCase());
  }

  /// Validates notes/description
  static ValidationResult validateNotes(String? notes, {int maxLength = 1000}) {
    if (notes == null || notes.isEmpty) {
      return ValidationResult.valid(''); // Notes are optional
    }
    
    if (notes.length > maxLength) {
      return ValidationResult.invalid('Notes cannot exceed $maxLength characters');
    }
    
    if (_containsSqlInjection(notes)) {
      return ValidationResult.invalid('Invalid characters in notes');
    }
    
    final sanitized = sanitizeInput(notes, maxLength: maxLength);
    return ValidationResult.valid(sanitized);
  }

  /// Checks if input contains potential SQL injection patterns
  static bool _containsSqlInjection(String input) {
    return _sqlInjectionPattern.hasMatch(input);
  }

  /// Sanitizes an error message to prevent information leakage
  static String sanitizeErrorMessage(dynamic error) {
    if (error == null) return 'An error occurred';
    
    final errorString = error.toString().toLowerCase();
    
    // Don't leak database or internal errors
    if (errorString.contains('database') ||
        errorString.contains('sql') ||
        errorString.contains('constraint') ||
        errorString.contains('foreign key') ||
        errorString.contains('sqflite')) {
      return 'A database error occurred. Please try again.';
    }
    
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return 'Network error. Please check your connection.';
    }
    
    // For generic errors, return a safe message
    if (errorString.length > 200) {
      return 'An unexpected error occurred. Please try again.';
    }
    
    // Return the original if it's safe
    return error.toString();
  }

  /// Masks sensitive data for logging
  static String maskSensitiveData(String data, {int visibleChars = 4}) {
    if (data.length <= visibleChars * 2) {
      return '*' * data.length;
    }
    
    final prefix = data.substring(0, visibleChars);
    final suffix = data.substring(data.length - visibleChars);
    return '$prefix${'*' * (data.length - visibleChars * 2)}$suffix';
  }
}

/// Result of a validation operation
class ValidationResult {
  final bool isValid;
  final dynamic value;
  final String? errorMessage;

  ValidationResult._(this.isValid, this.value, this.errorMessage);

  factory ValidationResult.valid(dynamic value) {
    return ValidationResult._(true, value, null);
  }

  factory ValidationResult.invalid(String message) {
    return ValidationResult._(false, null, message);
  }

  /// Throws an exception if validation failed
  T getOrThrow<T>() {
    if (!isValid) {
      throw ValidationException(errorMessage ?? 'Validation failed');
    }
    return value as T;
  }
}

/// Exception thrown when validation fails
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}
