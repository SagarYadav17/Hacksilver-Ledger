import 'package:flutter/foundation.dart';
import 'dart:async';

/// Rate limiting service for security-sensitive operations
class RateLimiter {
  final Map<String, Timer> _timers = {};
  final Map<String, int> _counts = {};

  /// Check if operation is rate-limited
  bool isRateLimited(String key, {int maxRequests = 60, Duration window = const Duration(minutes: 1)}) {
    final now = DateTime.now();
    final stored = _timers[key];

    // Reset if timer expired or doesn't exist
    if (stored == null || now.isAfter(stored.expiry)) {
      _timers[key] = _createTimer(key, maxRequests, window);
      return false;
    }

    return true;
  }

  /// Create a timer for rate limiting
  Timer _createTimer(String key, int maxRequests, Duration window) {
    // Reset count
    _counts[key] = 0;

    return Timer.periodic(
      window,
      (timer) {
        _counts[key] = 0;
      },
    );
  }

  /// Increment request count
  void incrementRequest(String key) {
    _counts[key] = (_counts[key] ?? 0) + 1;
    debugPrint('[$key] Request count: ${_counts[key]}');
  }

  /// Get current count
  int getRequestCount(String key) {
    return _counts[key] ?? 0;
  }

  /// Clear rate limiter for a key
  void clear(String key) {
    _timers[key]?.cancel();
    _timers.remove(key);
    _counts.remove(key);
  }

  /// Clear all rate limiters
  void clearAll() {
    _timers.forEach((key, timer) => timer.cancel());
    _timers.clear();
    _counts.clear();
  }
}

/// Global rate limiter instance
final rateLimiter = RateLimiter();

/// Annotated rate limiter for different operations
class OperationRateLimiter {
  static const _rateLimiters = {
    'sync': {'max': 60, 'window': Duration(minutes: 1)},
    'backup': {'max': 5, 'window': Duration(hours: 1)},
    'restore': {'max': 3, 'window': Duration(hours: 1)},
    'export': {'max': 10, 'window': Duration(hours: 1)},
  };

  /// Check if operation is allowed
  static bool isAllowed(String operation) {
    final config = _rateLimiters[operation];
    if (config == null) return true; // No limit

    return !rateLimiter.isRateLimited(
      'op:$operation',
      maxRequests: config['max'],
      window: config['window'],
    );
  }

  /// Record operation
  static void record(String operation) {
    rateLimiter.incrementRequest('op:$operation');
  }

  /// Get remaining attempts
  static int getRemaining(String operation) {
    final config = _rateLimiters[operation];
    if (config == null) return -1;

    final count = rateLimiter.getRequestCount('op:$operation');
    return config['max'] - count;
  }
}