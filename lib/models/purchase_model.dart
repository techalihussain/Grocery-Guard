import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseModel {
  final String id;
  final double totalAmount;
  final bool isReturn;
  final bool isCredit;
  final String invoiceNo;
  final String createdBy;
  final DateTime createdAt;
  final String paymentMethod;
  final String vendorId;
  final String? originalId;
  final double? tax;
  final double? discount;
  final double? subtotals;
  final String status;
  PurchaseModel({
    required this.id,
    required this.totalAmount,
    required this.isReturn,
    required this.isCredit,
    required this.invoiceNo,
    required this.createdBy,
    required this.paymentMethod,
    required this.vendorId,
    required this.createdAt,
    this.originalId,
    this.tax,
    this.discount,
    this.subtotals,
    required this.status,
  });
  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    return PurchaseModel(
      id: json['id'] ?? '',
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      isReturn: json['isReturn'] ?? false,
      isCredit: json['isCredit'] ?? false,
      invoiceNo: json['invoiceNo'] ?? '',
      createdBy: json['createdBy'] ?? '',
      paymentMethod: json['paymentMethod'] ?? 'cash',
      vendorId: json['vendorId'] ?? '',
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      originalId: json['originalId'],
      tax: json['tax']?.toDouble(),
      discount: json['discount']?.toDouble(),
      subtotals: json['subtotals']?.toDouble(),
      status: json['status'] ?? 'drafted',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'totalAmount': totalAmount,
      'isReturn': isReturn,
      'isCredit': isCredit,
      'invoiceNo': invoiceNo,
      'createdBy': createdBy,
      'paymentMethod': paymentMethod,
      'vendorId': vendorId,
      'createdAt': createdAt,
      'originalId': originalId,
      'tax': tax,
      'discount': discount,
      'subtotals': subtotals,
      'status': status,
    };
  }

  PurchaseModel copyWith({
    String? id,
    double? totalAmount,
    bool? isReturn,
    bool? isCredit,
    String? invoiceNo,
    String? createdBy,
    DateTime? date,
    String? paymentMethod,
    String? vendorId,
    String? originalId,
    DateTime? createdAt,
    double? tax,
    double? discount,
    double? subtotals,
    String? status,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      totalAmount: totalAmount ?? this.totalAmount,
      isReturn: isReturn ?? this.isReturn,
      isCredit: isCredit ?? this.isCredit,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      createdBy: createdBy ?? this.createdBy,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      vendorId: vendorId ?? this.vendorId,
      createdAt: createdAt ?? this.createdAt,
      originalId: originalId ?? this.originalId,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      subtotals: subtotals ?? this.subtotals,
      status: status ?? this.status,
    );
  }
}
