import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'dish_management.dart';
import 'billing_screen.dart';
import 'sales_records.dart';
import 'todays_sales.dart';
import 'backup_restore.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_DashItem>[
      _DashItem('Billing', Icons.point_of_sale, (ctx) => const BillingScreen()),
      _DashItem('Manage Dishes', Icons.restaurant_menu, (ctx) => const DishManagementScreen()),
      _DashItem('Sales Records', Icons.receipt_long, (ctx) => const SalesRecordsScreen()),
      _DashItem('Today\'s Sales', Icons.today, (ctx) => const TodaysSalesScreen()),
      _DashItem('Export / Backup', Icons.backup, (ctx) => const BackupRestoreScreen()),
      _DashItem('Change Password', Icons.lock_reset, (ctx) => const SettingsScreen()),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('${AppConstants.appName} — Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _DashCard(item: item);
          },
        ),
      ),
    );
  }
}

class _DashItem {
  final String label;
  final IconData icon;
  final Widget Function(BuildContext) builder;
  _DashItem(this.label, this.icon, this.builder);
}

class _DashCard extends StatelessWidget {
  final _DashItem item;
  const _DashCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: item.builder));
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 40, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
