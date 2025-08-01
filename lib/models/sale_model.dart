import 'package:cloud_firestore/cloud_firestore.dart';

class SaleModel {
  final String id;
  final double totalAmount;
  final bool isReturn;
  final bool isCredit;
  final String invoiceNo;
  final String createdBy;

  final DateTime createdAt;
  final String paymentMethod;
  final String customerId;
  final String status;
  final String? originalId;
  final double? tax;
  final double? discount;
  final double? subtotals;
  SaleModel({
    required this.id,
    required this.totalAmount,
    required this.isReturn,
    required this.isCredit,
    required this.invoiceNo,
    required this.createdBy,
    required this.paymentMethod,
    required this.status,
    this.originalId,
    required this.customerId,
    required this.createdAt,
    this.tax,
    this.discount,
    this.subtotals,
  });
  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['id'] ?? '',
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      isReturn: json['isReturn'] ?? false,
      isCredit: json['isCredit'] ?? false,
      invoiceNo: json['invoiceNo'] ?? '',
      createdBy: json['createdBy'] ?? '',
      paymentMethod: json['paymentMethod'] ?? 'cash',
      originalId: json['originalId'],
      customerId: json['customerId'] ?? '',
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
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
      'originalId': originalId,
      'customerId': customerId,
      'createdAt': createdAt,
      'tax': tax,
      'discount': discount,
      'subtotals': subtotals,
      'status': status,
    };
  }

  SaleModel copyWith({
    String? id,
    double? totalAmount,
    bool? isReturn,
    bool? isCredit,
    String? invoiceNo,
    String? createdBy,
    DateTime? date,
    String? paymentMethod,
    String? originalId,
    String? customerId,
    DateTime? createdAt,
    double? tax,
    double? discount,
    double? subtotals,
    String? status,
  }) {
    return SaleModel(
      id: id ?? this.id,
      totalAmount: totalAmount ?? this.totalAmount,
      isReturn: isReturn ?? this.isReturn,
      isCredit: isCredit ?? this.isCredit,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      createdBy: createdBy ?? this.createdBy,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      originalId: originalId ?? this.originalId,
      customerId: customerId ?? this.customerId,
      createdAt: createdAt ?? this.createdAt,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      subtotals: subtotals ?? this.subtotals,
      status: status ?? this.status,
    );
  }
}
