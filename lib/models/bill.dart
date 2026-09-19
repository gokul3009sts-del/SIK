import 'bill_item.dart';

class Bill {
  final int? id;
  final String billNumber;
  final String billDate; // yyyy-MM-dd
  final String billTime; // HH:mm:ss
  final double grandTotal;
  final String createdAt; // full ISO timestamp, used for accurate sorting/filtering
  final List<BillItem> items;

  Bill({
    this.id,
    required this.billNumber,
    required this.billDate,
    required this.billTime,
    required this.grandTotal,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_number': billNumber,
      'bill_date': billDate,
      'bill_time': billTime,
      'grand_total': grandTotal,
      'created_at': createdAt,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map, {List<BillItem> items = const []}) {
    return Bill(
      id: map['id'] as int?,
      billNumber: map['bill_number'] as String,
      billDate: map['bill_date'] as String,
      billTime: map['bill_time'] as String,
      grandTotal: (map['grand_total'] as num).toDouble(),
      createdAt: map['created_at'] as String,
      items: items,
    );
  }
}
