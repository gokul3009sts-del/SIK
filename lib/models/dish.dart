class Dish {
  final int? id;
  final String name;
  final double price;
  final String createdAt;
  final String updatedAt;
  final int isActive; // 1 = active/visible on billing screen, 0 = deleted (soft delete)

  Dish({
    this.id,
    required this.name,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_active': isActive,
    };
  }

  factory Dish.fromMap(Map<String, dynamic> map) {
    return Dish(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      isActive: map['is_active'] as int? ?? 1,
    );
  }

  Dish copyWith({
    int? id,
    String? name,
    double? price,
    String? createdAt,
    String? updatedAt,
    int? isActive,
  }) {
    return Dish(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
