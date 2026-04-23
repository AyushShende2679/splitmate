import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import 'package:splitmate_expense_tracker/screens/services/group_service.dart';
import 'package:splitmate_expense_tracker/screens/pages/create_group_dialog.dart';
import 'package:splitmate_expense_tracker/screens/pages/group_detail_page.dart';
import 'notification_page.dart';
import 'package:splitmate_expense_tracker/theme/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final arrowColor = isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFFCBD5E1);

    return ValueListenableBuilder(
      valueListenable: Hive.box('user_profile').listenable(),
      builder: (context, profileBox, _) {
        _loadCurrency(); 

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textColor,
        actions: [
          ListenableBuilder(
            listenable: Listenable.merge([
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
            return Center(child: Text('No groups yet. Create one!', style: TextStyle(color: subtextColor)));
          }

          final groups = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                color: cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cardBorder)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                    foregroundColor: textColor,
                    child: Text(
                      group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                    ),
                  ),
                  title: Text(
                    group.name,
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${group.members.length} members', style: TextStyle(color: subtextColor)),
                      Text(
                        'Total: $_currencySymbol${group.totalExpenses.toStringAsFixed(2)}',
                        style: TextStyle(color: AppTheme.primary),
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, color: arrowColor),
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
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            builder: (context) => const CreateGroupDialog(),
            isScrollControlled: true,
          );
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        label: const Text('New Group'),
        icon: const Icon(Icons.add),
      ),
    );
    },
    );
  }
}