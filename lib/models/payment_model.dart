import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final double balance; // Total credit amount (all sales on credit)
  final double totalPaid; // Running total of all payments made by customer
  final double totalDue; // Calculated as balance - totalPaid
  final double paymentAmount; // Individual payment amount (NEW FIELD)
  final DateTime createdAt;
  final String referenceId;
  final String
  type; // 'payment', 'credit_sale', 'credit_adjustment', 'cash_refund'
  final String? paymentMethod;
  final String? description;

  PaymentModel({
    required this.id,
    required this.balance,
    required this.totalPaid,
    required this.totalDue,
    required this.paymentAmount, // NEW REQUIRED FIELD
    required this.createdAt,
    required this.referenceId,
    required this.type,
    this.paymentMethod,
    this.description,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final balance = (json['balance'] ?? 0.0).toDouble();
    final totalPaid = (json['totalPaid'] ?? 0.0).toDouble();

    return PaymentModel(
      id: json['id'] ?? '',
      balance: balance,
      totalPaid: totalPaid,
      totalDue: json['totalDue'] ?? (balance - totalPaid),
      paymentAmount: (json['paymentAmount'] ?? 0.0).toDouble(), // NEW FIELD
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      referenceId: json['referenceId'] ?? '',
      type: json['type'] ?? '',
      paymentMethod: json['paymentMethod'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'balance': balance,
      'totalPaid': totalPaid,
      'totalDue': totalDue,
      'paymentAmount': paymentAmount, // NEW FIELD
      'createdAt': createdAt,
      'referenceId': referenceId,
      'type': type,
      'paymentMethod': paymentMethod,
      'description': description,
    };
  }

  PaymentModel copyWith({
    String? id,
    double? balance,
    double? totalPaid,
    double? totalDue,
    double? paymentAmount,
    DateTime? createdAt,
    String? referenceId,
    String? type,
    String? paymentMethod,
    String? description,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      balance: balance ?? this.balance,
      totalPaid: totalPaid ?? this.totalPaid,
      totalDue: totalDue ?? this.totalDue,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      createdAt: createdAt ?? this.createdAt,
      referenceId: referenceId ?? this.referenceId,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
    );
  }
}
