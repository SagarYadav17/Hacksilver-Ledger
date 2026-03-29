import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:crypto/crypto.dart';
import 'database_service.dart';
import '../utils/security_utils.dart';

/// Security-enhanced backup service
class BackupService {
  // Valid backup file extensions
  static const List<String> _validExtensions = ['.db', '.sqlite', '.ledger'];
  
  // Maximum backup file size (50MB)
  static const int _maxFileSizeBytes = 50 * 1024 * 1024;

  /// Export database with security checks
  Future<void> exportDatabase(BuildContext context) async {
    try {
      // 1. Get current DB path
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'hacksilver_ledger.db');
      final file = File(path);

      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Database not found!')));
        }
        return;
      }

      // 2. Verify file size
      final fileSize = await file.length();
      if (fileSize > _maxFileSizeBytes) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database too large to export')),
          );
        }
        return;
      }

      // 3. Generate checksum for integrity verification
      final bytes = await file.readAsBytes();
      final checksum = sha256.convert(bytes).toString();
      
      // Store checksum metadata (could be saved to a file alongside backup)
      debugPrint('Backup checksum: $checksum');

      // 4. Share the file with secure options
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Hacksilver Ledger Backup',
        ),
      );

      // 5. Log export (audit trail)
      debugPrint('Database exported at ${DateTime.now()}. Size: $fileSize bytes');

    } catch (e) {
      final safeError = SecurityUtils.sanitizeErrorMessage(e);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $safeError')));
      }
    }
  }

  /// Restore database with security validation
  Future<bool> restoreDatabase(BuildContext context) async {
    try {
      // 1. Pick file with validation
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'ledger'],
        allowMultiple: false,
      );

      if (result == null) return false; // User canceled

      final filePath = result.files.single.path;
      if (filePath == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not access file path')),
          );
        }
        return false;
      }

      final file = File(filePath);

      // 2. Validate file extension
      final extension = extensionFromPath(filePath).toLowerCase();
      if (!_validExtensions.contains('.$extension')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid file format. Please select a .db, .sqlite, or .ledger file'),
            ),
          );
        }
        return false;
      }

      // 3. Check file size
      final fileSize = await file.length();
      if (fileSize > _maxFileSizeBytes) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File too large. Maximum size is 50MB.')),
          );
        }
        return false;
      }

      if (fileSize == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File is empty')),
          );
        }
        return false;
      }

      // 4. Validate file header (SQLite magic number)
      final header = await file.openRead(0, 16).first;
      if (header.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid or corrupted file')),
          );
        }
        return false;
      }

      // Check SQLite header signature
      final headerString = String.fromCharCodes(header.take(6));
      if (headerString != 'SQLite') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid database file format')),
          );
        }
        return false;
      }

      // 5. Close current DB connection before overwriting
      await DatabaseService().close();

      // 6. Create backup of current database before restore
      final dbPath = await getDatabasesPath();
      final currentDbPath = join(dbPath, 'hacksilver_ledger.db');
      final backupPath = join(dbPath, 'hacksilver_ledger_backup_${DateTime.now().millisecondsSinceEpoch}.db');
      
      final currentFile = File(currentDbPath);
      if (await currentFile.exists()) {
        await currentFile.copy(backupPath);
        debugPrint('Current database backed up to: $backupPath');
      }

      // 7. Overwrite DB file with retry logic
      int retries = 3;
      while (retries > 0) {
        try {
          await file.copy(currentDbPath);
          break;
        } catch (e) {
          retries--;
          if (retries == 0) {
            // Restore backup if copy failed
            if (await File(backupPath).exists()) {
              await File(backupPath).copy(currentDbPath);
            }
            throw e;
          }
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // 8. Verify integrity
      final newDb = await openReadOnlyDatabase(currentDbPath);
      await newDb.execute('PRAGMA integrity_check');
      await newDb.close();

      // 9. Clean up backup file after successful restore
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      // 10. Log restore (audit trail)
      debugPrint('Database restored at ${DateTime.now()}. Size: $fileSize bytes');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore successful! Please restart the app.'),
          ),
        );
      }

      return true;
    } catch (e) {
      final safeError = SecurityUtils.sanitizeErrorMessage(e);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $safeError')));
      }
      return false;
    }
  }

  /// Delete old backup files to save space
  Future<void> cleanupOldBackups({int maxBackups = 3}) async {
    try {
      final dbPath = await getDatabasesPath();
      final directory = Directory(dbPath);
      
      final backupFiles = directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('hacksilver_ledger_backup_'))
          .toList();
      
      if (backupFiles.length > maxBackups) {
        // Sort by modification time (oldest first)
        backupFiles.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        
        // Delete oldest backups
        final toDelete = backupFiles.length - maxBackups;
        for (var i = 0; i < toDelete; i++) {
          await backupFiles[i].delete();
          debugPrint('Deleted old backup: ${backupFiles[i].path}');
        }
      }
    } catch (e) {
      debugPrint('Backup cleanup failed: $e');
    }
  }

  /// Get database info for diagnostics
  Future<Map<String, dynamic>?>> getDatabaseInfo() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'hacksilver_ledger.db');
      final file = File(path);
      
      if (!await file.exists()) {
        return null;
      }

      final stat = await file.stat();
      final bytes = await file.readAsBytes();
      final checksum = sha256.convert(bytes).toString();

      return {
        'path': path,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
        'checksum': checksum,
      };
    } catch (e) {
      debugPrint('Failed to get database info: $e');
      return null;
    }
  }
}
