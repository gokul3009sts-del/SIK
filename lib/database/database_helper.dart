import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../models/dish.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// Central SQLite access point. Everything is 100% local — no network calls
/// happen anywhere in this file or anywhere else in the app.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sik_hotel_billing.db');
    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // Enforce referential integrity + enable transactions properly.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE dishes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_number TEXT NOT NULL UNIQUE,
        bill_date TEXT NOT NULL,
        bill_time TEXT NOT NULL,
        grand_total REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bill_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_id INTEGER NOT NULL,
        dish_id INTEGER NOT NULL,
        dish_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_bills_date ON bills(bill_date)');
    await db.execute('CREATE INDEX idx_bill_items_bill_id ON bill_items(bill_id)');

    // Seed default settings: admin/admin123, bill numbering starts at 1.
    final defaultHash = _hashPassword(AppConstants.defaultPassword);
    await db.insert('settings', {'key': AppConstants.keyAdminUsername, 'value': AppConstants.defaultUsername});
    await db.insert('settings', {'key': AppConstants.keyAdminPasswordHash, 'value': defaultHash});
    await db.insert('settings', {'key': AppConstants.keyNextBillNumber, 'value': '1'});
    await db.insert('settings', {'key': AppConstants.keyShopName, 'value': AppConstants.appName});
    await db.insert('settings', {'key': AppConstants.keyPrinterWidth, 'value': '58'});

    // Seed a starter menu so the app is usable immediately.
    final now = DateTime.now().toIso8601String();
    final starterDishes = <Map<String, dynamic>>[
      {'name': 'Idly', 'price': 20.0},
      {'name': 'Dosa', 'price': 50.0},
      {'name': 'Parotta', 'price': 40.0},
      {'name': 'Meals', 'price': 100.0},
      {'name': 'Tea', 'price': 15.0},
      {'name': 'Coffee', 'price': 20.0},
    ];
    for (final d in starterDishes) {
      await db.insert('dishes', {
        'name': d['name'],
        'price': d['price'],
        'created_at': now,
        'updated_at': now,
        'is_active': 1,
      });
    }
  }

  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // ---------------- SETTINGS ----------------

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> verifyAdminCredentials(String username, String password) async {
    final storedUsername = await getSetting(AppConstants.keyAdminUsername);
    final storedHash = await getSetting(AppConstants.keyAdminPasswordHash);
    if (storedUsername == null || storedHash == null) return false;
    return storedUsername == username && storedHash == _hashPassword(password);
  }

  Future<void> changeAdminPassword(String newPassword) async {
    await setSetting(AppConstants.keyAdminPasswordHash, _hashPassword(newPassword));
  }

  // ---------------- DISHES ----------------

  Future<int> insertDish(String name, double price) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('dishes', {
      'name': name,
      'price': price,
      'created_at': now,
      'updated_at': now,
      'is_active': 1,
    });
  }

  Future<List<Dish>> getActiveDishes() async {
    final db = await database;
    final rows = await db.query(
      'dishes',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return rows.map((r) => Dish.fromMap(r)).toList();
  }

  Future<List<Dish>> getAllDishes() async {
    final db = await database;
    final rows = await db.query('dishes', orderBy: 'name ASC');
    return rows.map((r) => Dish.fromMap(r)).toList();
  }

  Future<int> updateDish(int id, String name, double price) async {
    final db = await database;
    return await db.update(
      'dishes',
      {
        'name': name,
        'price': price,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Soft delete: dish disappears from billing/menu, but stays in the table
  /// so historical `bill_items` (which store a name/price snapshot anyway)
  /// remain fully correct and joinable if ever needed.
  Future<int> deleteDish(int id) async {
    final db = await database;
    return await db.update(
      'dishes',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------- BILLS ----------------

  /// Atomically reserves the next bill number, then saves the bill and all
  /// its items in a single database transaction. If anything fails, nothing
  /// is written — there is never a partially-saved bill.
  Future<Bill> createBillWithItems(List<BillItem> cartItems) async {
    if (cartItems.isEmpty) {
      throw Exception('Cannot create a bill with no items.');
    }
    final db = await database;
    final now = DateTime.now();
    final grandTotal = cartItems.fold<double>(0, (sum, item) => sum + item.total);

    late Bill savedBill;

    await db.transaction((txn) async {
      // Read + increment the bill sequence inside the same transaction so
      // concurrent taps can never produce a duplicate number.
      final settingRows = await txn.query(
        'settings',
        where: 'key = ?',
        whereArgs: [AppConstants.keyNextBillNumber],
      );
      final nextNumber = int.parse(settingRows.first['value'] as String);
      final billNumberStr = Formatters.formatBillNumber(nextNumber);

      final billId = await txn.insert('bills', {
        'bill_number': billNumberStr,
        'bill_date': Formatters.dateForFile(now),
        'bill_time': DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second)
            .toIso8601String()
            .split('T')[1],
        'grand_total': grandTotal,
        'created_at': now.toIso8601String(),
      });

      for (final item in cartItems) {
        await txn.insert('bill_items', {
          'bill_id': billId,
          'dish_id': item.dishId,
          'dish_name': item.dishName,
          'quantity': item.quantity,
          'price': item.price,
          'total': item.total,
        });
      }

      await txn.update(
        'settings',
        {'value': (nextNumber + 1).toString()},
        where: 'key = ?',
        whereArgs: [AppConstants.keyNextBillNumber],
      );

      savedBill = Bill(
        id: billId,
        billNumber: billNumberStr,
        billDate: Formatters.dateForFile(now),
        billTime: DateFormatHelper.hms(now),
        grandTotal: grandTotal,
        createdAt: now.toIso8601String(),
        items: cartItems,
      );
    });

    return savedBill;
  }

  Future<List<Bill>> getAllBills({String? date}) async {
    final db = await database;
    final rows = await db.query(
      'bills',
      where: date != null ? 'bill_date = ?' : null,
      whereArgs: date != null ? [date] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => Bill.fromMap(r)).toList();
  }

  Future<List<Bill>> getBillsBetween(DateTime start, DateTime end) async {
    final db = await database;
    final rows = await db.query(
      'bills',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => Bill.fromMap(r)).toList();
  }

  Future<Bill> getBillWithItems(int billId) async {
    final db = await database;
    final billRows = await db.query('bills', where: 'id = ?', whereArgs: [billId]);
    final itemRows = await db.query('bill_items', where: 'bill_id = ?', whereArgs: [billId]);
    return Bill.fromMap(
      billRows.first,
      items: itemRows.map((r) => BillItem.fromMap(r)).toList(),
    );
  }

  Future<List<BillItem>> getItemsForBill(int billId) async {
    final db = await database;
    final rows = await db.query('bill_items', where: 'bill_id = ?', whereArgs: [billId]);
    return rows.map((r) => BillItem.fromMap(r)).toList();
  }

  Future<double> getTotalSalesBetween(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(grand_total) as total FROM bills WHERE created_at >= ? AND created_at <= ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final value = result.first['total'];
    return value == null ? 0.0 : (value as num).toDouble();
  }

  // ---------------- BACKUP / RESTORE ----------------

  Future<Map<String, dynamic>> exportAllDataAsJson() async {
    final db = await database;
    final dishes = await db.query('dishes');
    final bills = await db.query('bills');
    final billItems = await db.query('bill_items');
    final settings = await db.query('settings');
    return {
      'app': AppConstants.appName,
      'exported_at': DateTime.now().toIso8601String(),
      'dishes': dishes,
      'bills': bills,
      'bill_items': billItems,
      'settings': settings,
    };
  }

  /// Wipes and replaces all local data from a backup JSON map, inside a
  /// single transaction. Caller is responsible for confirming with the user
  /// first, since this is destructive.
  Future<void> restoreAllDataFromJson(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('bill_items');
      await txn.delete('bills');
      await txn.delete('dishes');
      await txn.delete('settings');

      for (final row in (data['dishes'] as List)) {
        await txn.insert('dishes', Map<String, dynamic>.from(row));
      }
      for (final row in (data['bills'] as List)) {
        await txn.insert('bills', Map<String, dynamic>.from(row));
      }
      for (final row in (data['bill_items'] as List)) {
        await txn.insert('bill_items', Map<String, dynamic>.from(row));
      }
      for (final row in (data['settings'] as List)) {
        await txn.insert('settings', Map<String, dynamic>.from(row));
      }
    });
  }
}

/// Small local helper (kept dependency-free) for HH:mm:ss formatting.
class DateFormatHelper {
  static String hms(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
