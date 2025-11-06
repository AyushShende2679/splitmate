import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import 'package:splitmate_expense_tracker/screens/services/group_service.dart';
import 'package:splitmate_expense_tracker/screens/pages/create_group_dialog.dart';
import 'package:splitmate_expense_tracker/screens/pages/group_detail_page.dart';
import 'notification_page.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final GroupService _groupService = GroupService();
  String _currencySymbol = '₹';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  void _loadCurrency() {
    final profileBox = Hive.box('user_profile');
    if (profileBox.containsKey('profile')) {
      final profileData = Map<String, dynamic>.from(profileBox.get('profile'));
      final profile = UserProfile.fromMap(profileData);
      
     
      _currencySymbol = profile.currency;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('user_profile').listenable(),
      builder: (context, profileBox, _) {
        _loadCurrency(); 

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          AnimatedBuilder(
            animation: Listenable.merge([
              Hive.box('group_invitations').listenable(),
              Hive.box('notification_status').listenable(),
              Hive.box('group_expenses').listenable(),
            ]),
            builder: (context, _) {
              final statusBox = Hive.box('notification_status');
              final hasUnseenNotifications =
                  statusBox.get('hasUnseenNotifications', defaultValue: false) as bool;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.mail_outline),
                    onPressed: () {
                      statusBox.put('hasUnseenNotifications', false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationPage(),
                        ),
                      );
                    },
                  ),
                  if (hasUnseenNotifications)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Group>>(
        stream: _groupService.getUserGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No groups yet. Create one!'));
          }

          final groups = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                    ),
                  ),
                  title: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${group.members.length} members'),
                      Text(
                        'Total: $_currencySymbol${group.totalExpenses.toStringAsFixed(2)}',
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupDetailPage(group: group),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => const CreateGroupDialog(),
            isScrollControlled: true,
          );
        },
        label: const Text('New Group'),
        icon: const Icon(Icons.add),
      ),
    );
    },
    );
  }
}