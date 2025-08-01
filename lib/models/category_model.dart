import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String name;
  final String id;
  final bool isActive;
  final DateTime createdAt;
  String? parentCategory;
  String? lastModifiedBy;
  String? createdBy;
  DateTime? updatedAt;
  CategoryModel({
    required this.name,
    required this.id,
    required this.isActive,
    required this.createdAt,
    this.lastModifiedBy,
    this.parentCategory,
    this.createdBy,
    this.updatedAt,
  });
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      name: json['name'],
      id: json['id'],
      isActive: json['isActive'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      parentCategory: json['parentCategory'],
      lastModifiedBy: json['lastModifiedBy'],
      createdBy: json['createdBy'],
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'id': id,
      'isActive': isActive,
      'createdAt': createdAt,
      'parentCategory': parentCategory,
      'lastModifiedBy': lastModifiedBy,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
    return map;
  }

  CategoryModel copyWith({
    String? name,
    String? id,
    bool? isActive,
    DateTime? createdAt,
    String? parentCategory,
    String? lastModifiedBy,
    String? createdBy,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      name: name ?? this.name,
      id: id ?? this.id,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      parentCategory: parentCategory ?? this.parentCategory,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
