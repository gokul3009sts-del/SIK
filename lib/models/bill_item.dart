class BillItem {
  final int? id;
  final int? billId;
  final int dishId;
  final String dishName; // snapshot, so old bills stay correct even if dish is edited/deleted
  final int quantity;
  final double price; // snapshot of price at billing time
  final double total;

  BillItem({
    this.id,
    this.billId,
    required this.dishId,
    required this.dishName,
    required this.quantity,
    required this.price,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bill_id': billId,
      'dish_id': dishId,
      'dish_name': dishName,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      id: map['id'] as int?,
      billId: map['bill_id'] as int?,
      dishId: map['dish_id'] as int,
      dishName: map['dish_name'] as String,
      quantity: map['quantity'] as int,
      price: (map['price'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
    );
  }
}
