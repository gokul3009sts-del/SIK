import 'dart:io';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/bill.dart';
import '../services/export_service.dart';
import '../services/backup_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _db = DatabaseHelper.instance;
  final _exportService = ExportService();
  final _backupService = BackupService();
  bool _busy = false;

  Future<void> _runBusy(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<Bill>> _billsForScope(String scope) async {
    switch (scope) {
      case 'today':
        final now = DateTime.now();
        return _db.getBillsBetween(Formatters.startOfDay(now), Formatters.endOfDay(now));
      case 'all':
      default:
        return _db.getAllBills();
    }
  }

  Future<void> _exportSales(String scope, String format) async {
    await _runBusy(() async {
      final bills = await _billsForScope(scope);
      if (bills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No bills to export for this range.')));
        return;
      }
      final label = scope == 'today' ? Formatters.dateForFile(DateTime.now()) : 'ALL_${Formatters.dateForFile(DateTime.now())}';
      final File file = format == 'csv'
          ? await _exportService.exportCsv(bills, label)
          : await _exportService.exportTxt(bills, label);
      await _exportService.shareFile(file);
    });
  }

  Future<void> _createBackup() async {
    await _runBusy(() async {
      final file = await _backupService.createBackup();
      await _backupService.shareBackup(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved: ${file.path}')));
      }
    });
  }

  Future<void> _restoreBackup() async {
    final file = await _backupService.pickBackupFile();
    if (file == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: const Text(
          'This will REPLACE all current dishes, bills, and settings with the data in this backup file. '
          'This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _runBusy(() async {
        await _backupService.restoreFromFile(file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data restored successfully.')));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export / Backup')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Opacity(
          opacity: _busy ? 0.5 : 1,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Sales Export', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Exported as CSV/TXT files, saved on-device and shareable.", style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _exportSales('today', 'csv'), child: const Text("Today (CSV)"))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _exportSales('today', 'txt'), child: const Text("Today (TXT)"))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _exportSales('all', 'csv'), child: const Text("All Sales (CSV)"))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _exportSales('all', 'txt'), child: const Text("All Sales (TXT)"))),
              ]),
              const SizedBox(height: 28),
              const Text('Backup & Restore', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Full local backup (dishes, bills, settings) as a JSON file.", style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.backup),
                label: const Text('Backup Data'),
                onPressed: _createBackup,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.restore, color: AppColors.danger),
                label: const Text('Restore Data', style: TextStyle(color: AppColors.danger)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                onPressed: _restoreBackup,
              ),
              if (_busy) const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
