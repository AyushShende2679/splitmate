import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:splitmate_expense_tracker/models/models.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  String? get currentUserId => _auth.currentUser?.uid;

  Future<List<Map<String, dynamic>>> getGroupMemberDetails(List<String> memberIds) async {
    if (memberIds.isEmpty) return [];
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: memberIds)
          .get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        final username = (data['name'] ?? (data['email'] ?? '').split('@').first).toString();
        return {
          'uid': doc.id,
          'username': username.isEmpty ? 'User' : username,
          'email': data['email'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error getting member details: $e');
      return [];
    }
  }

  Future<void> updateGroupExpense({
    required String groupId,
    required String expenseId,
    String? title,
    double? amount,
    List<String>? splitBetween,
    String? description,
    String? category,
    bool? isSettled,
    String? splitStatus,
  }) async {
    final docRef = _firestore.collection('group_expenses').doc(expenseId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final oldAmount = (data['amount'] ?? 0).toDouble();

    final Map<String, dynamic> updates = {
      if (title != null) 'title': title,
      if (amount != null) 'amount': amount,
      if (splitBetween != null) 'splitBetween': splitBetween,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (isSettled != null) 'isSettled': isSettled,
      if (splitStatus != null) 'splitStatus': splitStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.update(updates);

    if (amount != null && amount != oldAmount) {
      final delta = amount - oldAmount;
      await _firestore.collection('groups').doc(groupId).update({
        'totalExpenses': FieldValue.increment(delta),
      });
    }
  }
  

  Future<void> settleUserShare({required String expenseId, required String groupId}) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception("User not authenticated.");

    final docRef = _firestore.collection('group_expenses').doc(expenseId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) throw Exception("Expense does not exist!");

      final data = snap.data()! as Map<String, dynamic>;
      final settledBy = Map<String, bool>.from(data['settledBy'] ?? {});
      final splitBetween = List<String>.from(data['splitBetween'] ?? []);

    
      settledBy[currentUserId] = true;

      final settledCount = settledBy.values.where((v) => v == true).length;
      final totalCount = splitBetween.length;
      final newStatus = "Settled by $settledCount of $totalCount";
      final newIsSettled = settledCount >= totalCount;

     
      transaction.update(docRef, {
        'settledBy': settledBy,
        'splitStatus': newStatus,
        'isSettled': newIsSettled,
      });
    });
  }

  Future<void> deleteGroupExpense({
    required String groupId,
    required String expenseId,
  }) async {
    final docRef = _firestore.collection('group_expenses').doc(expenseId);
    final snap = await docRef.get();
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      final amt = (data['amount'] ?? 0).toDouble();
      await _firestore.collection('groups').doc(groupId).update({
        'totalExpenses': FieldValue.increment(-amt),
      });
    }
    await docRef.delete();
  }

  Future<List<Map<String, String>>> getGroupMembersMeta(String groupId) async {
    final g = await _firestore.collection('groups').doc(groupId).get();
    final ids = (g.data()?['members'] ?? []) as List;
    final List<Map<String, String>> out = [];
    for (final id in ids.map((e) => e.toString())) {
      final u = await _firestore.collection('users').doc(id).get();
      final name = (u.data()?['name'] ?? '').toString();
      final email = (u.data()?['email'] ?? '').toString();
      out.add({'id': id, 'name': name, 'email': email});
    }
    return out;
  }


  Future<String> createGroup({
    required String name,
    String? description,
    required List<String> invitedUserIds,
  }) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final groupId = _uuid.v4();
      final group = Group(
        id: groupId,
        name: name,
        description: description,
        createdBy: currentUserId!,
        members: [currentUserId!],
        createdAt: DateTime.now(),
      );
      await _firestore.collection('groups').doc(groupId).set(group.toJson());
      for (String userId in invitedUserIds) {
        await sendInvitation(groupId, name, userId);
      }
      return groupId;
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  
  Future<void> sendInvitation(String groupId, String groupName, String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      final inviterDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final inviterName = inviterDoc.data()?['name'] ?? inviterDoc.data()?['email'] ?? 'Someone';
      final invitationId = _uuid.v4();
      final invitation = GroupInvitation(
        id: invitationId,
        groupId: groupId,
        groupName: groupName,
        invitedBy: currentUser.uid,
        invitedByName: inviterName,
        invitedUser: userId,
        status: 'pending',
        createdAt: DateTime.now(),
      );
      final data = invitation.toJson();
      data['message'] = '$inviterName invited you to join $groupName';
      await _firestore.collection('invitations').doc(invitationId).set(data);
    } catch (e) {
      print('Error sending invitation: $e');
    }
  }


  Stream<List<Group>> getUserGroups() {
    if (currentUserId == null) return Stream.value([]);
    return _firestore
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Group.fromJson(doc.data())).toList());
  }
  
 
  Future<Group?> getGroupById(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return Group.fromJson(doc.data()!);
  }


  Future<List<String>> getGroupMemberIds(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    final members = (doc.data()?['members'] ?? []) as List;
    return members.map((e) => e.toString()).toList();
  }


  Stream<List<GroupInvitation>> getPendingInvitations() {
    if (currentUserId == null) return Stream.value([]);
    return _firestore
        .collection('invitations')
        .where('invitedUser', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GroupInvitation.fromJson(doc.data())).toList());
  }

  
  Future<void> acceptInvitation(String invitationId, String groupId) async {
    if (currentUserId == null) return;
    await _firestore.collection('invitations').doc(invitationId).update({
      'status': 'accepted',
    });
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([currentUserId]),
    });
  }


  Future<void> declineInvitation(String invitationId) async {
    await _firestore.collection('invitations').doc(invitationId).update({
      'status': 'declined',
    });
  }


  Future<void> addGroupExpense({
    required String groupId,
    required String title,
    required double amount,
    required List<String> splitBetween,
    String? description,
    String? category,
  }) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');
      final payerDoc = await _firestore.collection('users').doc(currentUserId).get();
      final payerName = payerDoc.data()?['name'] ?? payerDoc.data()?['email'] ?? 'Unknown';
      
     
      final settledByMap = { for (var memberId in splitBetween) memberId: false };
      settledByMap[currentUserId!] = true;
      final settledCount = settledByMap.values.where((v) => v).length;
      final totalCount = splitBetween.length;

      final expenseId = _uuid.v4();
      final expense = GroupExpenseModel(
        id: expenseId,
        groupId: groupId,
        title: title,
        amount: amount,
        paidBy: currentUserId!,
        paidByName: payerName,
        splitBetween: splitBetween,
        createdAt: DateTime.now(),
        description: description,
        category: category,
        isSettled: settledCount >= totalCount,
        splitStatus: "Settled by $settledCount of $totalCount",
        settledBy: settledByMap, 
      );
      await _firestore.collection('group_expenses').doc(expenseId).set(expense.toJson());
      await _firestore.collection('groups').doc(groupId).update({
        'totalExpenses': FieldValue.increment(amount),
      });
    } catch (e) {
      throw Exception('Failed to add expense: $e');
    }
  }

  Stream<List<GroupExpenseModel>> getGroupExpenses(String groupId) {
    return _firestore
        .collection('group_expenses')
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GroupExpenseModel.fromJson(doc.data())).toList());
  }

  
  Map<String, Map<String, double>> calculateBalances(List<GroupExpenseModel> expenses) {
    Map<String, double> netBalances = {};
    for (var expense in expenses) {
      double sharePerPerson = expense.getSharePerPerson();
      netBalances[expense.paidBy] = (netBalances[expense.paidBy] ?? 0) + expense.amount;
      for (String member in expense.splitBetween) {
        netBalances[member] = (netBalances[member] ?? 0) - sharePerPerson;
      }
    }
    Map<String, Map<String, double>> settlements = {};
    List<MapEntry<String, double>> creditors = [];
    List<MapEntry<String, double>> debtors = [];
    netBalances.forEach((person, balance) {
      if (balance > 0.01) {
        creditors.add(MapEntry(person, balance));
      } else if (balance < -0.01) {
        debtors.add(MapEntry(person, -balance));
      }
    });
    for (var debtor in debtors) {
      settlements[debtor.key] = {};
      double remaining = debtor.value;
      for (var i = 0; i < creditors.length && remaining > 0.01; i++) {
        if (creditors[i].value > 0.01) {
          double payment = remaining < creditors[i].value ? remaining : creditors[i].value;
          settlements[debtor.key]![creditors[i].key] = payment;
          remaining -= payment;
          creditors[i] = MapEntry(creditors[i].key, creditors[i].value - payment);
        }
      }
    }
    return settlements;
  }
  
 
  Future<void> leaveGroup(String groupId) async {
    if (currentUserId == null) return;
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([currentUserId]),
    });
  }


  Future<void> deleteGroup(String groupId) async {
    if (currentUserId == null) return;
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists || groupDoc.data()?['createdBy'] != currentUserId) {
        throw Exception("Only the group admin can delete the group.");
    }
    
    final expenses = await _firestore
        .collection('group_expenses')
        .where('groupId', isEqualTo: groupId)
        .get();
    for (var doc in expenses.docs) {
      await doc.reference.delete();
    }
    await _firestore.collection('groups').doc(groupId).delete();
  }

  
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final me = currentUserId;
    final lower = query.trim().toLowerCase();
    try {
      final snap = await _firestore
          .collection('users')
          .where('emailLower', isGreaterThanOrEqualTo: lower)
          .where('emailLower', isLessThanOrEqualTo: '$lower\uf8ff')
          .limit(10)
          .get();
      
      return snap.docs
          .where((d) => d.id != me)
          .map((d) {
            final data = d.data();
            final username = (data['name'] ?? (data['email'] ?? '').split('@').first).toString();
            return {
              'uid': d.id,
              'username': username.isEmpty ? 'User' : username,
              'email': data['email'] ?? '',
            };
          })
          .toList();
    } catch (e) {
      print("Error searching users: $e");
      return [];
    }
  }
}