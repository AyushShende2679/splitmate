import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'package:splitmate_expense_tracker/screens/services/group_service.dart'; 


class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final GroupService _groupService = GroupService();
  bool _isLoading = false;
String _currencySymbol = '₹';

@override
  void initState() {
    super.initState();
    _loadCurrency(); 
  }
  void _loadCurrency() {
    final profileBox = Hive.box('user_profile');
    if (profileBox.containsKey('profile')) {
      final profile = UserProfile.fromMap(Map<String, dynamic>.from(profileBox.get('profile')));
     
      _currencySymbol = profile.currency;
    }
  }
  Future<void> _accept(GroupInvitation invitation) async {
    setState(() => _isLoading = true);
    try {
      await _groupService.acceptInvitation(invitation.id, invitation.groupId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined "${invitation.groupName}"!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _decline(GroupInvitation invitation) async {
    setState(() => _isLoading = true);
    try {
      await _groupService.declineInvitation(invitation.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation declined.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.grey[800],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          Hive.box('personal_expenses').listenable(),
          Hive.box('group_expenses').listenable(),
          Hive.box('group_invitations').listenable(),
          Hive.box('user_profile').listenable(), 
        ]),
        builder: (context, _) {
          _loadCurrency();
          final personalExpenses = Hive.box('personal_expenses').values
              .whereType<Map>()
              .map((e) => PersonalExpense.fromMap(Map<String, dynamic>.from(e)))
              .toList();

          final groupExpenses = Hive.box('group_expenses').values
              .whereType<Map>()
              .map((e) => GroupExpense.fromMap(Map<String, dynamic>.from(e)))
              .toList();

          final groupInvitations = Hive.box('group_invitations').values
              .whereType<Map>()
              .map((e) => GroupInvitation.fromJson(Map<String, dynamic>.from(e)))
              .toList();

          final List<NotificationItem> notifications = [];

          for (final expense in personalExpenses) {
            notifications.add(NotificationItem(
              id: expense.id,
              type: 'personal',
              title: 'New Expense Added',
              subtitle: '${expense.title} - $_currencySymbol${expense.amount.toStringAsFixed(2)}',
              date: expense.date,
            ));
          }

          for (final expense in groupExpenses) {
            notifications.add(NotificationItem(
              id: expense.id,
              type: 'group',
              title: 'New Group Expense Added',
              subtitle: '${expense.title} - $_currencySymbol${expense.amount.toStringAsFixed(2)}',
              date: expense.date,
            ));
          }

          for (final invitation in groupInvitations) {
            notifications.add(NotificationItem(
              id: invitation.id,
              type: 'invitation',
              title: 'Group Invitation',
              subtitle: invitation.groupName,
              date: invitation.createdAt,
              invitation: invitation,
            ));
          }

          notifications.sort((a, b) => b.date.compareTo(a.date));

          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          final displayCount = notifications.length > 10 ? 10 : notifications.length;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayCount,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              IconData icon;
              Color iconColor;

              switch (notification.type) {
                case 'personal':
                  icon = Icons.person;
                  iconColor = const Color(0xFF4A90E2);
                  break;
                case 'group':
                  icon = Icons.group;
                  iconColor = Colors.green;
                  break;
                case 'invitation':
                  icon = Icons.mail;
                  iconColor = Colors.orange;
                  break;
                default:
                  icon = Icons.notifications;
                  iconColor = const Color(0xFF4A90E2);
              }

              if (notification.type == 'invitation' && notification.invitation != null) {
                final invitation = notification.invitation!;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orangeAccent,
                            child: Icon(icon, color: Colors.white),
                          ),
                          title: Text('Invitation to join "${invitation.groupName}"'),
                          subtitle: Text(
                            'From: ${invitation.invitedByName}\nSent on: ${DateFormat.yMMMd().format(invitation.createdAt)}',
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _decline(invitation),
                                child: const Text('Decline', style: TextStyle(color: Colors.red)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _accept(invitation),
                                child: const Text('Accept'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(icon, color: iconColor),
                  title: Text(notification.title),
                  subtitle: Text(notification.subtitle),
                  trailing: Text(
                    DateFormat('MMM dd').format(notification.date),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class NotificationItem {
  final String id;
  final String type; 
  final String title;
  final String subtitle;
  final DateTime date;
  final GroupInvitation? invitation; 

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    this.invitation,
  });
}
