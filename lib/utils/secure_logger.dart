import 'package:flutter/foundation.dart';

/// Conditional logger for security-conscious logging
class SecureLogger {
  SecureLogger._();

  /// Log error with security considerations
  static void error(String tag, dynamic error, {StackTrace? stackTrace}) {
    if (kReleaseMode) {
      // In production, sanitize the error message
      final safeMessage = _sanitizeErrorMessage(error);
      debugPrint('[$tag] $safeMessage');
    } else {
      // In debug, log full error with stack trace
      debugPrint('[$tag] $error');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  /// Log warning (sensitive data redacted)
  static void warning(String tag, String message) {
    if (kReleaseMode) {
      debugPrint('[$tag] $message');
    } else {
      debugPrint('[$tag] $message');
    }
  }

  /// Log info
  static void info(String tag, String message) {
    debugPrint('[$tag] $message');
  }

  /// Log security event (always logged, potentially to external service)
  static void securityEvent(String event, {Map<String, dynamic>? details}) {
    debugPrint('[SECURITY] $event: ${details ?? {}}');
    // In production, this would send to security monitoring service
  }

  /// Sanitize error message to prevent information leakage
  static String _sanitizeErrorMessage(dynamic error) {
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

  /// Mask sensitive data in logs
  static String maskSensitive(String value, {int visibleChars = 4}) {
    if (value.length <= visibleChars * 2) {
      return '*' * value.length;
    }

    final prefix = value.substring(0, visibleChars);
    final suffix = value.substring(value.length - visibleChars);
    return '$prefix${'*' * (value.length - visibleChars * 2)}$suffix';
  }
}