import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String phoneNumber;
  final String email;
  final String role;
  final DateTime createdAt;
  final bool isActive;
  String? employeeId;
  String? company;
  String? address;
  String? accountNo;

  UserModel({
    required this.name,
    required this.id,
    required this.phoneNumber,
    required this.email,
    required this.role,
    required this.createdAt,
    this.isActive = false,
    this.company,
    this.accountNo,
    this.address,
    this.employeeId,
  });
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'],
      id: json['id'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      role: json['role'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      isActive: json['isActive'] ?? false,
      company: json['company'],
      accountNo: json['accountNo'],
      address: json['address'],
      employeeId: json['employeeId'],
    );
  }
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'id': id,
      'phoneNumber': phoneNumber,
      'email': email,
      'role': role,
      'createdAt': createdAt,
      'isActive': isActive,
    };
    if (role == 'vendor') {
      map['company'] = company;
    }
    if (role == 'customer') {
      map['address'] = address;
    }
    if (role == 'salesman' || role == 'storeuser') {
      map['employeeId'] = employeeId;
    }
    if (role == 'customer' || role == 'vendor') {
      map['accountNo'] = accountNo;
    }
    return map;
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? role,
    DateTime? createdAt,
    bool? isActive,
    String? employeeId,
    String? company,
    String? address,
    String? accountNo,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      employeeId: employeeId ?? this.employeeId,
      company: company ?? this.company,
      address: address ?? this.address,
      accountNo: accountNo ?? this.accountNo,
    );
  }
}
