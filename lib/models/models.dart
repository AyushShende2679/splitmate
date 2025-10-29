import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class PersonalExpense extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String category;

  PersonalExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
  });

  PersonalExpense copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? category,
  }) {
    return PersonalExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
      };

  factory PersonalExpense.fromMap(Map<String, dynamic> map) => PersonalExpense(
        id: map['id'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: map['date'] is String
            ? DateTime.parse(map['date'] as String)
            : map['date'] as DateTime,
        category: map['category'] as String,
      );
}

@HiveType(typeId: 1)
class GroupExpense extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String category;

  @HiveField(5)
  final String paidBy;

  @HiveField(6)
  final String splitStatus;

  @HiveField(7)
  final bool isSettled;

  @HiveField(8)
  final String groupId;

  @HiveField(9)
  final String paidById;

  @HiveField(10)
  final Map<String, dynamic> settledBy;

  GroupExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.paidBy,
    required this.splitStatus,
    required this.isSettled,
    required this.groupId,
    required this.paidById,
    required this.settledBy,
  });

  GroupExpense copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? paidBy,
    String? splitStatus,
    bool? isSettled,
    String? groupId,
    String? paidById,
    Map<String, dynamic>? settledBy,
  }) {
    return GroupExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      paidBy: paidBy ?? this.paidBy,
      splitStatus: splitStatus ?? this.splitStatus,
      isSettled: isSettled ?? this.isSettled,
      groupId: groupId ?? this.groupId,
      paidById: paidById ?? this.paidById,
      settledBy: settledBy ?? this.settledBy,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
        'paidBy': paidBy,
        'splitStatus': splitStatus,
        'isSettled': isSettled,
        'groupId': groupId,
        'paidById': paidById,
        'settledBy': settledBy,
      };

  factory GroupExpense.fromMap(Map<String, dynamic> map) {
    return GroupExpense(
      id: map['id'] ?? '',
      groupId: map['groupId'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: (map['date'] is String
              ? DateTime.tryParse(map['date'])
              : map['date']) ??
          DateTime.now(),
      category: map['category'] ?? 'Other',
      paidBy: map['paidBy'] ?? 'Unknown',
      paidById: map['paidById'] ?? '',
      isSettled: map['isSettled'] ?? false,
      splitStatus: map['splitStatus'] ?? 'Pending',
      settledBy: Map<String, dynamic>.from(map['settledBy'] ?? {}),
    );
  }
}

@HiveType(typeId: 2)
class UserProfile extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final String phone;

  @HiveField(4)
  final String currency;

  @HiveField(5)
  final String profileImagePath;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.currency,
    required this.profileImagePath,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? currency,
    String? profileImagePath,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      currency: currency ?? this.currency,
      profileImagePath: profileImagePath ?? this.profileImagePath,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'currency': currency,
        'profileImagePath': profileImagePath,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        currency: map['currency'] as String? ?? '₹',
        profileImagePath: map['profileImagePath'] as String? ?? '',
      );
}

@JsonSerializable()
class Group {
  final String id;
  final String name;
  final String createdBy;
  final List<String> members;
  final DateTime createdAt;
  final String? description;
  final double totalExpenses;

  Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    required this.createdAt,
    this.description,
    this.totalExpenses = 0.0,
  });

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
  Map<String, dynamic> toJson() => _$GroupToJson(this);
}

@JsonSerializable()
class GroupInvitation {
  final String id;
  final String groupId;
  final String groupName;
  final String invitedBy;
  final String invitedByName;
  final String invitedUser;
  final String status;
  final DateTime createdAt;

  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.invitedBy,
    required this.invitedByName,
    required this.invitedUser,
    required this.status,
    required this.createdAt,
  });

  factory GroupInvitation.fromJson(Map<String, dynamic> json) =>
      _$GroupInvitationFromJson(json);
  Map<String, dynamic> toJson() => _$GroupInvitationToJson(this);
}

@JsonSerializable()
class GroupExpenseModel {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String paidBy;
  final String paidByName;
  final List<String> splitBetween;
  final DateTime createdAt;
  final String? description;
  final String? category;
  final bool? isSettled;
  final String? splitStatus;

  final Map<String, bool>? settledBy;

  GroupExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.paidByName,
    required this.splitBetween,
    required this.createdAt,
    this.description,
    this.category,
    this.isSettled,
    this.splitStatus,
    this.settledBy, 
  });

  double getSharePerPerson() =>
      splitBetween.isNotEmpty ? amount / splitBetween.length : amount;

  factory GroupExpenseModel.fromJson(Map<String, dynamic> json) =>
      _$GroupExpenseModelFromJson(json);

  Map<String, dynamic> toJson() => _$GroupExpenseModelToJson(this);
}

@JsonSerializable()
class GroupBalance {
  final String userId;
  final String userName;
  final double balance;
  final Map<String, double> owesTo;

  GroupBalance({
    required this.userId,
    required this.userName,
    required this.balance,
    required this.owesTo,
  });

  factory GroupBalance.fromJson(Map<String, dynamic> json) =>
      _$GroupBalanceFromJson(json);
  Map<String, dynamic> toJson() => _$GroupBalanceToJson(this);
}
