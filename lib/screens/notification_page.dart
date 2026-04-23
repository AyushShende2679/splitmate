import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'package:splitmate_expense_tracker/screens/services/group_service.dart';
import 'package:splitmate_expense_tracker/theme/app_theme.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final GroupService _groupService = GroupService();

  // Per-invitation loading state — keyed by invitation ID
  final Map<String, bool> _loadingMap = {};

  String _currencySymbol = '₹';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  void _loadCurrency() {
    final profileBox = Hive.box('user_profile');
    if (profileBox.containsKey('profile')) {
      final profile = UserProfile.fromMap(
          Map<String, dynamic>.from(profileBox.get('profile')));
      setState(() => _currencySymbol = profile.currency);
    }
  }

  Future<void> _accept(GroupInvitation invitation) async {
    setState(() => _loadingMap[invitation.id] = true);
    try {
      await _groupService.acceptInvitation(invitation.id, invitation.groupId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined "${invitation.groupName}"!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMap.remove(invitation.id));
    }
  }

  Future<void> _decline(GroupInvitation invitation) async {
    setState(() => _loadingMap[invitation.id] = true);
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
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMap.remove(invitation.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
      ),
      body: ListenableBuilder(
        listenable: Hive.box('group_invitations').listenable(),
        builder: (context, _) {
          final invitations = Hive.box('group_invitations')
              .values
              .whereType<Map>()
              .map((e) => GroupInvitation.fromJson(
                  Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // Also pull recent group expenses from Hive for activity feed
          final recentGroupExpenses = Hive.box('group_expenses')
              .values
              .whereType<Map>()
              .map((e) => GroupExpense.fromMap(
                  Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          final hasNotifications =
              invitations.isNotEmpty || recentGroupExpenses.isNotEmpty;

          if (!hasNotifications) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64,
                      color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFCBD5E1)),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                        color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8),
                        fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Group invitations and activity will appear here',
                    style: TextStyle(
                        color: isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFCBD5E1),
                        fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Section 1: Pending Invitations ──────────────────────────
              if (invitations.isNotEmpty) ...[
                _sectionHeader('Pending Invitations',
                    Icons.mail_outline, Colors.orange),
                const SizedBox(height: 8),
                ...invitations.map((inv) => _buildInvitationCard(inv)),
                const SizedBox(height: 24),
              ],

              // ── Section 2: Recent Group Activity ────────────────────────
              if (recentGroupExpenses.isNotEmpty) ...[
                _sectionHeader('Recent Group Activity',
                    Icons.group_outlined, AppTheme.chartBlue),
                const SizedBox(height: 8),
                ...recentGroupExpenses
                    .take(10)
                    .map((exp) => _buildGroupActivityCard(exp)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationCard(GroupInvitation invitation) {
    final isLoading = _loadingMap[invitation.id] == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);
    final dateColor = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFFCBD5E1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.orange.withValues(alpha: 0.2),
                child: const Icon(Icons.group_add, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invited to "${invitation.groupName}"',
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From: ${invitation.invitedByName}',
                      style: TextStyle(
                          color: subtextColor,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('MMM d').format(invitation.createdAt),
                style: TextStyle(
                    color: dateColor,
                    fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          isLoading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _decline(invitation),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: BorderSide(
                            color: AppTheme.danger.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Decline', style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _accept(invitation),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 0,
                      ),
                      child: const Text('Accept',
                          style: TextStyle(fontSize: 13, color: Colors.white)),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildGroupActivityCard(GroupExpense expense) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);
    final dateColor = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFFCBD5E1);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.chartBlue.withValues(alpha: 0.15),
            child: Icon(Icons.receipt_outlined,
                color: AppTheme.chartBlue, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Paid by ${expense.paidBy} • ${expense.category}',
                  style: TextStyle(
                      color: subtextColor,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_currencySymbol${expense.amount.toStringAsFixed(0)}',
                style: TextStyle(
                    color: AppTheme.chartBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d').format(expense.date),
                style: TextStyle(
                    color: dateColor,
                    fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
