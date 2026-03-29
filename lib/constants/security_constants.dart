/// Security constants and best practices
class SecurityConstants {
  SecurityConstants._();

  // Password/Key length requirements
  static const int minPinLength = 4;
  static const int maxPinLength = 8;
  static const int minApiKeyLength = 32;
  static const int maxApiKeyLength = 128;

  // Rate limiting
  static const int maxSyncAttemptsPerMinute = 60;
  static const int maxSyncAttemptsPerHour = 1000;
  static const int maxBackupAttemptsPerDay = 5;

  // File size limits (bytes)
  static const int maxDatabaseFileSize = 50 * 1024 * 1024; // 50MB
  static const int maxBackupFileSize = 50 * 1024 * 1024; // 50MB
  static const int maxExportFileSize = 50 * 1024 * 1024; // 50MB

  // Data retention
  static const int maxBackupHistory = 7; // Keep 7 days of backups
  static const int maxSyncHistory = 30; // Keep 30 days of sync logs

  // Security timeouts
  static const Duration sessionTimeout = Duration(minutes: 30);
  static const Duration lockScreenTimeout = Duration(minutes: 5);

  // Encryption
  static const String encryptionAlgorithm = 'AES-256-GCM';
  static const String hashAlgorithm = 'SHA-256';

  // Session tokens
  static const int tokenExpiryHours = 24;

  // Safe characters for user input
  static const Set<int> safeAsciiChars = {
    32..127, // Printable ASCII
  };

  // SQL injection patterns to block
  static const List<String> sqlInjectionPatterns = [
    'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE', 'ALTER',
    'EXEC', 'UNION', 'WHERE', 'AND', 'OR', '1=1', '--', ';', '/*', '*/',
    '\x00', '\x1a', '\x00', '\x01', '\x02', '\x03', '\x04', '\x05', '\x06',
    '\x07', '\x08', '\x0b', '\x0c', '\x0e', '\x0f', '\x10', '\x11', '\x12',
    '\x13', '\x14', '\x15', '\x16', '\x17', '\x18', '\x19', '\x1a', '\x1b',
    '\x1c', '\x1d', '\x1e', '\x1f',
  ];

  // Rate limiting keys
  static const String rateLimitKeySync = 'rate_limit:sync';
  static const String rateLimitKeyBackup = 'rate_limit:backup';
  static const String rateLimitKeyRestore = 'rate_limit:restore';

  // Audit log fields
  static const String auditActionLogin = 'login';
  static const String auditActionLogout = 'logout';
  static const String auditActionSync = 'sync';
  static const String auditActionBackup = 'backup';
  static const String auditActionRestore = 'restore';
  static const String auditActionExport = 'export';
  static const String auditActionImport = 'import';
  static const String auditActionAddTransaction = 'add_transaction';
  static const String auditActionUpdateTransaction = 'update_transaction';
  static const String auditActionDeleteTransaction = 'delete_transaction';

  // Security levels
  static const String securityLevelLow = 'low';
  static const String securityLevelMedium = 'medium';
  static const String securityLevelHigh = 'high';
  static const String securityLevelMaximum = 'maximum';

  // Biometric types
  static const String biometricTypeFaceID = 'face_id';
  static const String biometricTypeTouchID = 'touch_id';
  static const String biometricTypeBiometric = 'biometric';

  // Data masking patterns
  static const String creditCardPattern = '(\\d{4})\\s?(\\d{4})\\s?(\\d{4})\\s?(\\d{4})';
  static const String phonePattern = '(\\d{3})\\s?(\\d{3})\\s?(\\d{4})';
  static const String emailPattern = '(\\w+)(\\@)(\\w+)(\\.)(\\w+)';
}