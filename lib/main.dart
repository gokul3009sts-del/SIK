import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'services/export_service.dart';
import 'screens/login_screen.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SikApp());
}

class SikApp extends StatefulWidget {
  const SikApp({super.key});

  @override
  State<SikApp> createState() => _SikAppState();
}

class _SikAppState extends State<SikApp> {
  @override
  void initState() {
    super.initState();
    _runStartupTasks();
  }

  /// Ensures the local SQLite database exists/opens, and silently writes an
  /// automatic CSV export for yesterday's sales if one hasn't been made yet
  /// (covers the "automatic file backup at end of day" requirement even if
  /// the app is only reopened the next day, since there's no background
  /// process running while the app is fully closed).
  Future<void> _runStartupTasks() async {
    await DatabaseHelper.instance.database; // opens/creates DB + seeds defaults

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    try {
      await ExportService().autoExportForDate(yesterday);
    } catch (_) {
      // Non-fatal: manual export is always available from Export/Backup screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginScreen(),
    );
  }
}
