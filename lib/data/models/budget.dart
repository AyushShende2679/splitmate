import 'package:hive_flutter/hive_flutter.dart';

part 'budget.g.dart';

@HiveType(typeId: 4)
class Budget extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String category;
  @HiveField(2)
  final double limit;
  @HiveField(3)
  final String period; // 'monthly'
  @HiveField(4)
  final DateTime createdAt;
  @HiveField(5)
  final DateTime updatedAt;

  Budget({
    required this.id,
    required this.category,
    required this.limit,
    this.period = 'monthly',
    required this.createdAt,
    required this.updatedAt,
  });

  Budget copyWith({String? id, String? category, double? limit, String? period, DateTime? createdAt, DateTime? updatedAt}) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      period: period ?? this.period,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'limit': limit,
        'period': period,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: m['id'] as String,
        category: m['category'] as String,
        limit: (m['limit'] as num).toDouble(),
        period: m['period'] as String? ?? 'monthly',
        createdAt: m['createdAt'] is String ? DateTime.parse(m['createdAt']) : m['createdAt'] as DateTime,
        updatedAt: m['updatedAt'] is String ? DateTime.parse(m['updatedAt']) : m['updatedAt'] as DateTime,
      );
}
