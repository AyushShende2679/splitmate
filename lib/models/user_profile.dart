import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
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
    this.profileImagePath = '',
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

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      currency: map['currency'] as String,
     
      profileImagePath: map['profileImagePath'] as String? ?? '', 
     
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'currency': currency,
     
      'profileImagePath': profileImagePath,
     
    };
  }
}