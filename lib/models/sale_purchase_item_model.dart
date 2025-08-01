class ItemModel {
  final String referenceId;
  final String productId;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String unit; // Unit in which the item was sold/purchased
  ItemModel({
    required this.referenceId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.unit,
  });
  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      referenceId: json['referenceId'] ?? '',
      productId: json['productId'] ?? '',
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      unitPrice: (json['unitPrice'] ?? 0.0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0.0).toDouble(),
      unit: json['unit'] ?? 'pcs',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'referenceId': referenceId,
      'productId': productId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'unit': unit,
    };
  }

  ItemModel copyWith({
    String? referenceId,
    String? productId,
    double? quantity,
    double? unitPrice,
    double? totalPrice,
    String? unit,
  }) {
    return ItemModel(
      referenceId: referenceId ?? this.referenceId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      unit: unit ?? this.unit,
    );
  }
}
