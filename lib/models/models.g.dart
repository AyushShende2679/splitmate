// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PersonalExpenseAdapter extends TypeAdapter<PersonalExpense> {
  @override
  final int typeId = 0;

  @override
  PersonalExpense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PersonalExpense(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      date: fields[3] as DateTime,
      category: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PersonalExpense obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonalExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GroupExpenseAdapter extends TypeAdapter<GroupExpense> {
  @override
  final int typeId = 1;

  @override
  GroupExpense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GroupExpense(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      date: fields[3] as DateTime,
      category: fields[4] as String,
      paidBy: fields[5] as String,
      splitStatus: fields[6] as String,
      isSettled: fields[7] as bool,
      groupId: fields[8] as String,
      paidById: fields[9] as String,
      settledBy: (fields[10] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, GroupExpense obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.paidBy)
      ..writeByte(6)
      ..write(obj.splitStatus)
      ..writeByte(7)
      ..write(obj.isSettled)
      ..writeByte(8)
      ..write(obj.groupId)
      ..writeByte(9)
      ..write(obj.paidById)
      ..writeByte(10)
      ..write(obj.settledBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupExpenseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 2;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      phone: fields[3] as String,
      currency: fields[4] as String,
      profileImagePath: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.currency)
      ..writeByte(5)
      ..write(obj.profileImagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Group _$GroupFromJson(Map<String, dynamic> json) => Group(
      id: json['id'] as String,
      name: json['name'] as String,
      createdBy: json['createdBy'] as String,
      members:
          (json['members'] as List<dynamic>).map((e) => e as String).toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String?,
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$GroupToJson(Group instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'createdBy': instance.createdBy,
      'members': instance.members,
      'createdAt': instance.createdAt.toIso8601String(),
      'description': instance.description,
      'totalExpenses': instance.totalExpenses,
    };

GroupInvitation _$GroupInvitationFromJson(Map<String, dynamic> json) =>
    GroupInvitation(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      invitedBy: json['invitedBy'] as String,
      invitedByName: json['invitedByName'] as String,
      invitedUser: json['invitedUser'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$GroupInvitationToJson(GroupInvitation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'groupId': instance.groupId,
      'groupName': instance.groupName,
      'invitedBy': instance.invitedBy,
      'invitedByName': instance.invitedByName,
      'invitedUser': instance.invitedUser,
      'status': instance.status,
      'createdAt': instance.createdAt.toIso8601String(),
    };

GroupExpenseModel _$GroupExpenseModelFromJson(Map<String, dynamic> json) =>
    GroupExpenseModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      paidBy: json['paidBy'] as String,
      paidByName: json['paidByName'] as String,
      splitBetween: (json['splitBetween'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      description: json['description'] as String?,
      category: json['category'] as String?,
      isSettled: json['isSettled'] as bool?,
      splitStatus: json['splitStatus'] as String?,
      settledBy: (json['settledBy'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as bool),
      ),
    );

Map<String, dynamic> _$GroupExpenseModelToJson(GroupExpenseModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'groupId': instance.groupId,
      'title': instance.title,
      'amount': instance.amount,
      'paidBy': instance.paidBy,
      'paidByName': instance.paidByName,
      'splitBetween': instance.splitBetween,
      'createdAt': instance.createdAt.toIso8601String(),
      'description': instance.description,
      'category': instance.category,
      'isSettled': instance.isSettled,
      'splitStatus': instance.splitStatus,
      'settledBy': instance.settledBy,
    };

GroupBalance _$GroupBalanceFromJson(Map<String, dynamic> json) => GroupBalance(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      balance: (json['balance'] as num).toDouble(),
      owesTo: (json['owesTo'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
    );

Map<String, dynamic> _$GroupBalanceToJson(GroupBalance instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'userName': instance.userName,
      'balance': instance.balance,
      'owesTo': instance.owesTo,
    };
