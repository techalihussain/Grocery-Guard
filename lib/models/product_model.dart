import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String unit;
  final double purchasePrice;
  final double salePrice;
  final double currentStock;
  final String categoryId;
  final String vendorId;
  final double minimumStockLevel;
  final DateTime createdAt;
  final bool isActive;
  DateTime? updatedAt;
  String? brand;
  final String? barcode;
  ProductModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.purchasePrice,
    required this.salePrice,
    required this.categoryId,
    required this.currentStock,
    required this.minimumStockLevel,
    required this.createdAt,
    required this.isActive,
    required this.vendorId,
    this.updatedAt,
    this.brand,
    this.barcode,
  });
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name'],
      unit: json['unit'],
      purchasePrice: (json['purchasePrice'] as num).toDouble(),
      salePrice: (json['salePrice'] as num).toDouble(),
      categoryId: json['categoryId'],
      currentStock: (json['currentStock'] as num).toDouble(),
      minimumStockLevel: (json['minimumStockLevel'] as num).toDouble(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      isActive: json['isActive'],
      vendorId: json['vendorId'],
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
      brand: json['brand'],
      barcode: json['barcode'],
    );
  }
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'unit': unit,
      'purchasePrice': purchasePrice,
      'salePrice': salePrice,
      'categoryId': categoryId,
      'currentStock': currentStock,
      'minimumStockLevel': minimumStockLevel,
      'createdAt': createdAt,
      'isActive': isActive,
      'vendorId': vendorId,
      'updatedAt': updatedAt,
      'brand': brand,
      'barcode': barcode,
    };
    return map;
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? unit,
    double? purchasePrice,
    double? salePrice,
    double? currentStock,
    String? categoryId,
    String? vendorId,
    double? minimumStockLevel,
    DateTime? createdAt,
    bool? isActive,
    DateTime? updatedAt,
    String? brand,
    String? barcode,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      categoryId: categoryId ?? this.categoryId,
      currentStock: currentStock ?? this.currentStock,
      minimumStockLevel: minimumStockLevel ?? this.minimumStockLevel,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      vendorId: vendorId ?? this.vendorId,
      updatedAt: updatedAt ?? this.updatedAt,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
    );
  }
}
