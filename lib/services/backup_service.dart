import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'database_service.dart';

class BackupService {
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

      // 2. Share the file (Easiest way to save to Drive/Local on Android/iOS)
      // Using share_plus is more reliable than managing storage permissions for raw file writes on newer Android.
      await Share.shareXFiles([XFile(path)], text: 'Hacksilver Ledger Backup');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<bool> restoreDatabase(BuildContext context) async {
    try {
      // 1. Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result == null) return false; // User canceled

      final file = File(result.files.single.path!);

      // Basic validation (check extension or rudimentary header if possible, currently just extension)
      if (!file.path.endsWith('.db') && !file.path.endsWith('.sqlite')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid file format. Please select a .db file'),
            ),
          );
        }
        return false;
      }

      // 2. Close current DB connection
      await DatabaseService().close();

      // 3. Overwrite DB file
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'hacksilver_ledger.db');

      await file.copy(path);

      // 4. Re-open/Notify (App restart usually recommended)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore successful! Please restart the app.'),
          ),
        );
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
      return false;
    }
  }
}
