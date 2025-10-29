import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:splitmate_expense_tracker/models/models.dart';
import '../services/group_service.dart';
import 'package:splitmate_expense_tracker/screens/pages/add_member_dialog.dart';
import 'package:intl/intl.dart';
import 'package:splitmate_expense_tracker/screens/add_edit_expense_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

class GroupDetailPage extends StatefulWidget {
  final Group group;
  const GroupDetailPage({super.key, required this.group});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final GroupService _groupService = GroupService();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
String _currencySymbol = '₹';

  Future<List<Map<String, dynamic>>>? _memberDetailsFuture;

  @override
  void initState() {
    super.initState();
    _loadCurrency(); 
    _memberDetailsFuture = _groupService.getGroupMemberDetails(widget.group.members);
  }
  void _loadCurrency() {
    final profileBox = Hive.box('user_profile');
    if (profileBox.containsKey('profile')) {
      final profile = UserProfile.fromMap(Map<String, dynamic>.from(profileBox.get('profile')));
  
      _currencySymbol = profile.currency;
    }
  }

  // Method to add a group expense
  Future<void> _addGroupExpense() async {
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditExpenseScreen(
          initialIsGroup: true,
          groupId: widget.group.id, 
        ),
      ),
    );

   
    if (result is Map) {
      final newExpense = result['expense'] as GroupExpense;
      final splitBetweenMembers = result['splitBetween'] as List<String>;

      await _groupService.addGroupExpense(
        groupId: newExpense.groupId,
        title: newExpense.title,
        amount: newExpense.amount,
        splitBetween: splitBetweenMembers, 
        category: newExpense.category,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense added to group!')),
        );
      }
    }
  }

  // Method to handle editing an expense
  Future<void> _editGroupExpense(GroupExpense expense) async {
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditExpenseScreen(
          initialIsGroup: true,
          expense: expense,
        ),
      ),
    );

    if (result is Map) {
      final updatedExpense = result['expense'] as GroupExpense;
     
      await _groupService.updateGroupExpense(
        groupId: updatedExpense.groupId,
        expenseId: updatedExpense.id,
        title: updatedExpense.title,
        amount: updatedExpense.amount,
        category: updatedExpense.category,
        isSettled: updatedExpense.isSettled,
        splitStatus: updatedExpense.splitStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense updated!')),
        );
      }
    }
  }


  void _handleMenuAction(String action) async {
    switch (action) {
      case 'leave':
        final confirm = await _showConfirmDialog('Leave Group', 'Are you sure you want to leave this group?');
        if (confirm == true) {
          await _groupService.leaveGroup(widget.group.id);
          if (mounted) Navigator.pop(context);
        }
        break;
      case 'delete':
        final confirm = await _showConfirmDialog('Delete Group', 'This will permanently delete the group and all expenses. This cannot be undone.');
        if (confirm == true) {
          await _groupService.deleteGroup(widget.group.id);
          if (mounted) Navigator.pop(context);
        }
        break;
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Confirm')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.group.createdBy == currentUserId;
return ValueListenableBuilder(
      valueListenable: Hive.box('user_profile').listenable(),
      builder: (context, profileBox, _) {
        _loadCurrency();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddMemberDialog(group: widget.group),
              );
            },
            tooltip: 'Add Member',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'leave', child: Text('Leave Group')),
              if (isAdmin)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete Group', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Members', style: Theme.of(context).textTheme.titleLarge),
          ),
          SizedBox(
            height: 80,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _memberDetailsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No members found.'));
                }
                final members = snapshot.data!;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final name = member['username'] as String? ?? '...';
                    return Container(
                      width: 70,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          CircleAvatar(
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Expenses', style: Theme.of(context).textTheme.titleLarge),
          ),
          Expanded(
            child: StreamBuilder<List<GroupExpenseModel>>(
              stream: _groupService.getGroupExpenses(widget.group.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final expenses = snapshot.data ?? [];
                if (expenses.isEmpty) {
                  return const Center(
                    child: Text('No expenses yet. Tap + to add one!'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(_getCategoryIcon(expense.category)),
                        ),
                        title: Text(expense.title),
                        subtitle: Text(
                            'Paid by ${expense.paidByName} • ${DateFormat.yMMMd().format(expense.createdAt)}'),
                        trailing: Text(
                          '$_currencySymbol${expense.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onTap: () => _editGroupExpense(GroupExpense.fromMap(expense.toJson())),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGroupExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
    },
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'food & drinks':
        return Icons.fastfood;
      case 'transportation':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'bills':
        return Icons.receipt;
      default:
        return Icons.money;
    }
  }
}