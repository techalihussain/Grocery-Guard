class StockModel {
  final int change;
  final String reason;
  final DateTime createdAt;
  final double resultingStock;
  final String createdBy;
  StockModel({
    required this.change,
    required this.reason,
    required this.createdAt,
    required this.resultingStock,
    required this.createdBy,
  });
  factory StockModel.fromMap(Map<String, dynamic> map) {
    return StockModel(
      change: map['change'],
      reason: map['reason'],
      createdAt: DateTime.parse(map['createdAt']),
      resultingStock: (map['resultingStock'] as num).toDouble(),
      createdBy: map['createdBy'],
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'change': change,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
      'resultingStock': resultingStock,
      'createdBy': createdBy,
    };
  }
}
