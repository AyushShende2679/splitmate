import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:splitmate_expense_tracker/models/models.dart';

Future<void> syncAppDataToFirestore() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final firestore = FirebaseFirestore.instance;
  final userDoc = firestore.collection('users').doc(uid);
  final profileBox = Hive.box('user_profile');
  final settingsBox = Hive.box('settings');
  final personalBox = Hive.box('personal_expenses');
  final groupBox = Hive.box('group_expenses');
  
  // Sync Profile
  Map<String, dynamic> profileMap = {};
  if (profileBox.containsKey('profile')) {
    final raw = profileBox.get('profile');
    if (raw is Map) profileMap = Map<String, dynamic>.from(raw);
  }
  
  final currentUser = FirebaseAuth.instance.currentUser;
  final resolvedEmail = (profileMap['email'] ?? '').toString().trim().isNotEmpty
      ? profileMap['email'].toString().trim()
      : (currentUser?.email ?? '').trim();
  
  final profilePayload = {
    'name': profileMap['name'] ?? '',
    'email': resolvedEmail,
    'emailLower': resolvedEmail.toLowerCase(),
    'phone': profileMap['phone'] ?? '',
    'currency': profileMap['currency'] ?? '₹',
    'updatedAt': FieldValue.serverTimestamp(),
    'profileImagePath': profileMap['profileImagePath'] ?? '',
  };

  // Sync Settings
  Map<String, dynamic> settingsPayload = {};
  if (settingsBox.containsKey('settings')) {
    final raw = settingsBox.get('settings');
    if (raw is Map) settingsPayload = Map<String, dynamic>.from(raw);
  }

  await userDoc.set({
    'settings': settingsPayload,
    ...profilePayload,
  }, SetOptions(merge: true));

  // Sync Personal Expenses
  final personalRef = userDoc.collection('personal_expenses');
  for (final key in personalBox.keys) {
    final raw = personalBox.get(key);
    if (raw is Map) {
      final expense = Map<String, dynamic>.from(raw);
      await personalRef.doc(expense['id'].toString()).set(expense, SetOptions(merge: true));
    }
  }

  // Sync Group Expenses
  final groupExpensesRef = firestore.collection('users').doc(uid).collection('group_expenses');
  for (var key in groupBox.keys) {
    final groupExpense = Map<String, dynamic>.from(groupBox.get(key));
    await groupExpensesRef.doc(key.toString()).set(groupExpense, SetOptions(merge: true));
  }
}

Future<void> restoreAppDataFromFirestore() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
  final profileBox = Hive.box('user_profile');
  final settingsBox = Hive.box('settings');
  final personalBox = Hive.box('personal_expenses');
  final groupBox = Hive.box('group_expenses');
  
  // Restore Profile and Settings
  final snap = await userDoc.get();
  if (snap.exists) {
    final data = snap.data() ?? {};
    final restoredProfile = <String, dynamic>{
      'id': uid,
      'name': data['name'] ?? '',
      'email': data['email'] ?? '',
      'phone': data['phone'] ?? '',
      'currency': data['currency'] ?? '₹',
      'profileImagePath': data['profileImagePath'] ?? '',
    };
    await profileBox.put('profile', restoredProfile);

    if (data['settings'] is Map) {
      await settingsBox.put('settings', Map<String, dynamic>.from(data['settings']));
    }
  }

  // Restore Personal Expenses
  final personalSnap = await userDoc.collection('personal_expenses').get();
  await personalBox.clear(); // Clear existing to prevent duplicates
  for (final doc in personalSnap.docs) {
    final data = doc.data();
    final expense = PersonalExpense.fromMap(data);
    await personalBox.put(expense.id, expense.toMap());
  }

  // Restore Group Expenses
  await groupBox.clear();
  final groupsQuery = await FirebaseFirestore.instance.collection('groups').where('members', arrayContains: uid).get();
  final groupIds = groupsQuery.docs.map((doc) => doc.id).toList();

  if (groupIds.isNotEmpty) {
    final groupExpensesQuery = await FirebaseFirestore.instance.collection('group_expenses').where('groupId', whereIn: groupIds).get();
    for (final doc in groupExpensesQuery.docs) {
      final data = doc.data();
      final expenseModel = GroupExpenseModel.fromJson(data);
      final hiveMap = {
        'id': expenseModel.id,
        'groupId': expenseModel.groupId,
        'title': expenseModel.title,
        'amount': expenseModel.amount,
        'date': expenseModel.createdAt,
        'category': expenseModel.category ?? 'Other',
        'paidBy': expenseModel.paidByName,
        'paidById': expenseModel.paidBy,
        'isSettled': expenseModel.isSettled ?? false,
        'splitStatus': expenseModel.splitStatus ?? 'Pending',
        'settledBy': expenseModel.settledBy ?? {},
      };
      await groupBox.put(expenseModel.id, hiveMap);
    }
  }
  

  final invitationsBox = Hive.box('group_invitations');
  await invitationsBox.clear();
  final invitationsQuery = await FirebaseFirestore.instance
      .collection('invitations')
      .where('invitedUser', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .get();
  
  
  if (invitationsQuery.docs.isNotEmpty) {
    final statusBox = Hive.box('notification_status');
    await statusBox.put('hasUnseenNotifications', true);
  }

  for (final doc in invitationsQuery.docs) {
    final invitation = GroupInvitation.fromJson(doc.data());
    await invitationsBox.put(invitation.id, invitation.toJson());
  }

  print('✅ Restored data from Firestore.');
}

Future<void> clearAppDataFromFirestore() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

  // Clear personal expenses
  final personalSnap = await userDoc.collection('personal_expenses').get();
  for (final doc in personalSnap.docs) {
    await doc.reference.delete();
  }

  // Clear group expenses
  final groupSnap = await userDoc.collection('group_expenses').get();
  for (final doc in groupSnap.docs) {
    await doc.reference.delete();
  }

  // Clear profile and settings
  await userDoc.set({'settings': {}}, SetOptions(merge: true));
  await userDoc.delete();
  
  print('✅ Cleared data from Firestore.');
}
