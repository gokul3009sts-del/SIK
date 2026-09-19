import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/dish.dart';
import '../services/bill_service.dart';
import '../services/printer_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/dish_card.dart';
import '../widgets/bill_item_widget.dart';
import '../widgets/total_widget.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final _db = DatabaseHelper.instance;
  final _billService = BillService();
  final _printerService = PrinterService();

  List<Dish> _dishes = [];
  final Map<int, int> _quantities = {}; // dishId -> quantity
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  Future<void> _loadDishes() async {
    setState(() => _loading = true);
    final dishes = await _db.getActiveDishes();
    setState(() {
      _dishes = dishes;
      _loading = false;
    });
  }

  double get _grandTotal {
    double total = 0;
    for (final dish in _dishes) {
      final qty = _quantities[dish.id] ?? 0;
      total += dish.price * qty;
    }
    return total;
  }

  Map<Dish, int> get _cart {
    final Map<Dish, int> cart = {};
    for (final dish in _dishes) {
      final qty = _quantities[dish.id] ?? 0;
      if (qty > 0) cart[dish] = qty;
    }
    return cart;
  }

  void _increment(Dish dish) {
    setState(() {
      _quantities[dish.id!] = (_quantities[dish.id!] ?? 0) + 1;
    });
  }

  void _decrement(Dish dish) {
    setState(() {
      final current = _quantities[dish.id!] ?? 0;
      _quantities[dish.id!] = current > 0 ? current - 1 : 0;
    });
  }

  void _clearCart() {
    setState(() => _quantities.clear());
  }

  Future<void> _generateBill() async {
    final cart = _cart;
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item before generating the bill.')),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final bill = await _billService.generateBill(cart);
      if (!mounted) return;
      _clearCart();
      await _showBillCompletedDialog(bill.billNumber, bill.id!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save bill: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _showBillCompletedDialog(String billNumber, int billId) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Bill Generated'),
        content: Text('Bill $billNumber has been saved successfully.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              final bill = await _db.getBillWithItems(billId);
              await _printerService.shareBillPdf(bill);
            },
            child: const Text('Save PDF'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.print),
            label: const Text('Print'),
            onPressed: () async {
              final bill = await _db.getBillWithItems(billId);
              await _printerService.printBill(bill);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = _cart;

    return Scaffold(
      appBar: AppBar(title: const Text('${AppConstants.appName} — Billing')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _dishes.isEmpty
              ? const Center(child: Text('No dishes available. Ask admin to add dishes.'))
              : Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.25,
                          ),
                          itemCount: _dishes.length,
                          itemBuilder: (context, index) {
                            final dish = _dishes[index];
                            return DishCard(
                              dish: dish,
                              quantity: _quantities[dish.id] ?? 0,
                              onIncrement: () => _increment(dish),
                              onDecrement: () => _decrement(dish),
                            );
                          },
                        ),
                      ),
                    ),
                    if (cart.isNotEmpty)
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Colors.grey.shade300)),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Current Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  TextButton(onPressed: _clearCart, child: const Text('Clear')),
                                ],
                              ),
                              const Divider(),
                              Expanded(
                                child: ListView(
                                  children: cart.entries
                                      .map((e) => BillItemWidget(dish: e.key, quantity: e.value))
                                      .toList(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TotalWidget(total: _grandTotal),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _generating ? null : _generateBill,
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                                child: _generating
                                    ? const SizedBox(
                                        height: 22, width: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                                    : const Text('GENERATE BILL'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
