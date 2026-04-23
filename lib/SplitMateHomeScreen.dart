import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/models.dart';
import 'screens/add_edit_expense_screen.dart';
import 'screens/profile_page.dart';
import 'screens/notification_page.dart';
import 'screens/reports_page.dart';
import 'screens/groups_page.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:splitmate_expense_tracker/utils/io_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:splitmate_expense_tracker/screens/services/group_service.dart';
import 'package:splitmate_expense_tracker/theme/app_theme.dart';

class SplitMateHomeScreen extends StatefulWidget {
  const SplitMateHomeScreen({super.key});
  @override
  State<SplitMateHomeScreen> createState() => _SplitMateHomeScreenState();
}

class _SplitMateHomeScreenState extends State<SplitMateHomeScreen> {
  int _selectedIndex = 0;
  bool _isGroupMode = false;
  int _selectedMonth = DateTime.now().month;
  bool _showPieChart = true;

  String _currencySymbol = '₹';

  late final Box _personalBox;
  late final Box _groupBox;
  late final Box _invitationsBox;
  final Map<String, StreamSubscription> _groupSubs = {};
  StreamSubscription? _groupsSub;
  StreamSubscription? _invitationsSub;
  final GroupService _groupService = GroupService();
  final Map<String, bool> _groupListenersInitialized = {};

  @override
  void initState() {
    super.initState();
    _personalBox = Hive.box('personal_expenses');
    _groupBox = Hive.box('group_expenses');

    _invitationsBox = Hive.box('group_invitations');
    _loadCurrency(); 
    final statusBox = Hive.box('notification_status');
    statusBox.put('sessionStartedAt', DateTime.now().millisecondsSinceEpoch);
    statusBox.put('hasUnseenNotifications', false);

    _subscribeSharedGroupExpenses();
    _subscribeToInvitations();
  }

  @override
  void dispose() {
    _groupsSub?.cancel();
    _invitationsSub?.cancel();
    for (final sub in _groupSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

void _loadCurrency() {
    
    final profileBox = Hive.box('user_profile');
    if (profileBox.containsKey('profile')) {
      final profile = UserProfile.fromMap(Map<String, dynamic>.from(profileBox.get('profile')));
      _currencySymbol = profile.currency;
    } else {
      _currencySymbol = '₹'; 
    }
  }

  void _subscribeToInvitations() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _invitationsSub?.cancel();
    _invitationsSub =
        _groupService.getPendingInvitations().listen((invitations) async {
      final Set<String> firestoreIds = invitations.map((e) => e.id).toSet();

      // 1) Compare Firestore IDs to Hive IDs to detect brand-new invitations
      final Set<String> hiveIds = _invitationsBox.keys.cast<String>().toSet();

      bool hasNewInvitation = false;
      for (final id in firestoreIds) {
        if (!hiveIds.contains(id)) {
          hasNewInvitation = true;
          break;
        }
      }

      if (hasNewInvitation) {
        final statusBox = Hive.box('notification_status');
        await statusBox.put('hasUnseenNotifications', true);
      }

      // 2) Sync invitations to Hive
      for (final invitation in invitations) {
        await _invitationsBox.put(invitation.id, invitation.toJson());
      }
      final hiveKeys = _invitationsBox.keys.toList();
      for (final key in hiveKeys) {
        if (!firestoreIds.contains(key)) {
          await _invitationsBox.delete(key);
        }
      }
    });
  }

  void _subscribeSharedGroupExpenses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _groupsSub?.cancel();
    _groupsSub = FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots()
        .listen((gs) {
      for (final g in gs.docs) {
        final groupId = g.id;
        if (_groupSubs.containsKey(groupId)) continue;

        _groupListenersInitialized[groupId] = false;

        _groupSubs[groupId] = FirebaseFirestore.instance
            .collection('group_expenses')
            .where('groupId', isEqualTo: groupId)
            .snapshots()
            .listen((es) async {
          bool hasRemoteChange = false;

         
          final bool isInitialLoad =
              _groupListenersInitialized[groupId] == false;

          
          final statusBox = Hive.box('notification_status');
          final int sessionStartMs =
              statusBox.get('sessionStartedAt', defaultValue: 0) as int;
          final String currentUid =
              FirebaseAuth.instance.currentUser?.uid ?? '';

          for (final ch in es.docChanges) {
            final d = ch.doc;
            final data = d.data() as Map<String, dynamic>;

           
            final createdAt = (data['createdAt'] is Timestamp)
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.tryParse('${data['createdAt']}') ?? DateTime.now();
            final createdAtMs = createdAt.millisecondsSinceEpoch;

            
            final payerId = (data['paidBy'] ?? '') as String? ?? '';
            final bool isOtherUser = payerId.isNotEmpty && payerId != currentUid;

            bool notify = false;

            if (!d.metadata.hasPendingWrites) {
              if (ch.type == DocumentChangeType.added) {
                
                if (isOtherUser && createdAtMs >= sessionStartMs) {
                  notify = true;
                }
              } else if (ch.type == DocumentChangeType.modified) {
                
                final prevRaw = _groupBox.get(d.id);
                if (prevRaw is Map) {
                  final prevSettled =
                      Map<String, dynamic>.from(prevRaw['settledBy'] ?? {});
                  final currSettled =
                      Map<String, dynamic>.from(data['settledBy'] ?? {});
                  for (final entry in currSettled.entries) {
                    final k = entry.key.toString();
                    final nowTrue = entry.value == true;
                    final wasTrue = prevSettled[k] == true;
                    if (nowTrue && !wasTrue && k != currentUid) {
                      notify = true;
                      break;
                    }
                  }
                }
              }
            }

            if (notify) {
              hasRemoteChange = true;
            }

           
            final mapForHive = {
              'id': d.id,
              'groupId': groupId,
              'title': data['title'] ?? '',
              'amount': (data['amount'] ?? 0).toDouble(),
              'date': (data['createdAt'] is Timestamp)
                  ? (data['createdAt'] as Timestamp).toDate()
                  : DateTime.tryParse('${data['createdAt']}') ?? DateTime.now(),
              'category': data['category'] ?? 'Other',
              'paidBy': data['paidByName'] ?? data['paidBy'] ?? 'Unknown',
              'paidById': data['paidBy'] ?? '',
              'isSettled': data['isSettled'] ?? false,
              'splitStatus': data['splitStatus'] ?? 'Pending',
              'settledBy': data['settledBy'] ?? {},
            };

            if (ch.type == DocumentChangeType.removed) {
              await _groupBox.delete(d.id);
            } else {
              await _groupBox.put(d.id, mapForHive);
            }
          }

          if (hasRemoteChange) {
            await statusBox.put('hasUnseenNotifications', true);
          }

          if (isInitialLoad) {
            _groupListenersInitialized[groupId] = true;
          }

          if (mounted) setState(() {});
        });
      }
    });
  }



  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();


  void _openNotifications() {
    final statusBox = Hive.box('notification_status');
    statusBox.put('hasUnseenNotifications', false);

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationPage()),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }


  void _toggleChartType() {
    setState(() {
      _showPieChart = !_showPieChart;
    });
  }

 
  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Month"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                return ListTile(
                  title: Text(_getMonthName(month)),
                  onTap: () {
                    setState(() {
                      _selectedMonth = month;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(),
          const SizedBox.shrink(), 
          const GroupsPage(),
          const ReportsPage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHomeContent() {
    final listenable =
        Listenable.merge([_personalBox.listenable(), _groupBox.listenable(),Hive.box('user_profile').listenable() ]);
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        _loadCurrency(); 
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                _buildModeToggle(),
                _buildMonthlySummary(),
                _buildActionableCards(),
                _buildRecentExpenses(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF475569);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'SplitMate',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: textColor,
              fontFamily: 'Inter',
            ),
          ),
          Row(
            children: [
              ValueListenableBuilder(
                valueListenable: Hive.box('notification_status').listenable(),
                builder: (context, Box statusBox, _) {
                  final hasNotification = statusBox.get('hasUnseenNotifications', defaultValue: false) as bool;
                  return _buildActionIconButton(
                    icon: Icons.notifications_outlined,
                    onPressed: _openNotifications,
                    hasNotification: hasNotification,
                    iconColor: iconColor,
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionIconButton(
                icon: Icons.account_circle_outlined,
                onPressed: _openProfile,
                iconColor: iconColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool hasNotification = false,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = iconColor ?? (isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF475569));
    return Stack(
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 24, color: effectiveColor),
          padding: const EdgeInsets.all(8),
        ),
        if (hasNotification)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE53E3E),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModeToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              'Personal Mode',
              !_isGroupMode,
              () => setState(() => _isGroupMode = false),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              'Group Mode',
              _isGroupMode,
              () => setState(() => _isGroupMode = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
      String text, bool isActive, VoidCallback onPressed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final inactiveColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: AppTheme.primary.withValues(alpha: 0.4)) : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isActive ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlySummary() {
    final total = _monthlyTotal();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: isDark
          ? AppTheme.glassDecoration(borderRadius: 20)
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Summary',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              Row(
                children: [
                  GestureDetector(
                    onTap: _toggleChartType,
                    child: Icon(
                        _showPieChart ? Icons.bar_chart : Icons.pie_chart,
                        size: 20,
                        color: AppTheme.chartBlue),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _showMonthPicker,
                    child: Row(
                      children: [
                        Text(_getMonthName(_selectedMonth),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF60A5FA))),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down,
                            size: 16, color: Color(0xFF60A5FA)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 120,
                  child: _showPieChart ? _buildPieChart() : _buildBarChart(),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryItem(
                        'Food',
                        _formatCurrency(_sumByCategory('Food')),
                        AppTheme.chartBlue),
                    _buildSummaryItem(
                        'Transport',
                        _formatCurrency(_sumByCategory('Transport')),
                        AppTheme.chartTeal),
                    _buildSummaryItem(
                        'Shopping',
                        _formatCurrency(_sumByCategory('Shopping')),
                        AppTheme.chartAmber),
                    _buildSummaryItem(
                        'Bills',
                        _formatCurrency(_sumByCategory('Bills')),
                        AppTheme.chartRose),
                    Divider(height: 20, color: dividerColor),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textColor)),
                        Text(
                          _formatCurrency(total),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _isGroupMode
                                ? AppTheme.chartBlue
                                : AppTheme.chartRose,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final total = _monthlyTotal();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (total == 0) {
      return Center(child: Text('No data', style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8))));
    }

    final values = [
      _sumByCategory('Food'),
      _sumByCategory('Transport'),
      _sumByCategory('Shopping'),
      _sumByCategory('Bills'),
    ];

    final colors = [
      AppTheme.chartBlue,
      AppTheme.chartTeal,
      AppTheme.chartAmber,
      AppTheme.chartRose,
    ];

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: List.generate(values.length, (i) {
          final pct = values[i] == 0 ? 0.0 : (values[i] / total) * 100;
          return PieChartSectionData(
            color: colors[i],
            value: values[i],
            title: '${pct.toStringAsFixed(0)}%',
            radius: 35,
            titleStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
          );
        }),
      ),
    );
  }

  Widget _buildBarChart() {
    final values = [
      _sumByCategory('Food'),
      _sumByCategory('Transport'),
      _sumByCategory('Shopping'),
      _sumByCategory('Bills'),
    ];

    final maxY =
        (values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b)) + 500;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY <= 0 ? 1000.0 : maxY.toDouble(),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                const titles = ['Food', 'Trans', 'Shop', 'Bills'];
                final idx = value.toInt();
                return idx >= 0 && idx < titles.length
                    ? Text(titles[idx], style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B), fontSize: 11))
                    : const Text('');
              },
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: values[0], color: AppTheme.chartBlue, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(toY: values[1], color: AppTheme.chartTeal, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(toY: values[2], color: AppTheme.chartAmber, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))
          ]),
          BarChartGroupData(x: 3, barRods: [
            BarChartRodData(toY: values[3], color: AppTheme.chartRose, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))
          ]),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String category, String amount, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Expanded(child: SizedBox()),
          Expanded(
            flex: 15,
            child: Text(category,
                style: TextStyle(fontSize: 14, color: subtextColor)),
          ),
          Text(amount,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor)),
        ],
      ),
    );
  }

  Widget _buildActionableCards() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              'PDF Reports',
              'Export monthly reports',
              Icons.picture_as_pdf_outlined,
              const Color(0xFFE53E3E),
              _exportPDFReport,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              'Parent Monitor',
              'Manage guardian access',
              Icons.family_restroom_outlined,
              const Color(0xFF4A90E2),
              _manageParentAccess,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: isDark
            ? AppTheme.glassDecoration(borderRadius: 16)
            : BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: subtextColor),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentExpenses() {
    final box = _isGroupMode ? _groupBox : _personalBox;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Expenses',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
          const SizedBox(height: 16),
          ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box b, _) {
              final items = b.values
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .map((m) => _isGroupMode
                      ? GroupExpense.fromMap(m)
                      : PersonalExpense.fromMap(m))
                  .toList();

              
              items.sort((a, b) => ((b as dynamic).date as DateTime)
                  .compareTo((a as dynamic).date as DateTime));

              if (items.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: isDark
                      ? AppTheme.glassDecoration(borderRadius: 12)
                      : BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                  child: Center(
                    child: Text('No expenses yet. Tap Add to create one.',
                        style: TextStyle(color: subtextColor)),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final expense = items[index];
                  if (_isGroupMode) {
                    return _buildGroupExpenseItem(expense as GroupExpense);
                  } else {
                    return _buildPersonalExpenseItem(
                        expense as PersonalExpense);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalExpenseItem(PersonalExpense expense) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: isDark
          ? AppTheme.glassDecoration(borderRadius: 14)
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
      child: Row(
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(expense.title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor)),
              const SizedBox(height: 4),
              Wrap(children: [
                Text(expense.category,
                    style: TextStyle(
                        fontSize: 12, color: subtextColor)),
                Text(' • ${_formatDate(expense.date)}',
                    style: TextStyle(
                        fontSize: 12, color: subtextColor)),
              ]),
            ]),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatCurrency(expense.amount),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFB7185))),
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => _openExpenseForm(expense: expense),
                  child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined,
                          size: 16, color: AppTheme.chartBlue)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _deleteExpense(expense),
                  child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 16, color: AppTheme.danger)),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupExpenseItem(GroupExpense expense) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: isDark
          ? AppTheme.glassDecoration(borderRadius: 14)
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(expense.title,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor)),
                      const SizedBox(height: 4),
                      Wrap(children: [
                        Text('Paid by ${expense.paidBy}',
                            style: TextStyle(
                                fontSize: 12, color: subtextColor)),
                        Text(
                            ' • ${expense.category} • ${_formatDate(expense.date)}',
                            style: TextStyle(
                                fontSize: 12, color: subtextColor)),
                      ]),
                    ]),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatCurrency(expense.amount),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.chartBlue)),
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: () => _openExpenseForm(expense: expense),
                      child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined,
                              size: 16, color: AppTheme.chartBlue)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteExpense(expense),
                      child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline,
                              size: 16, color: AppTheme.danger)),
                    ),
                  ]),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: expense.isSettled
                        ? AppTheme.success.withValues(alpha: 0.15)
                        : AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    expense.splitStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: expense.isSettled
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Builder(builder: (context) {
                if (expense.isSettled) return const SizedBox.shrink();
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return const SizedBox.shrink();
                final isPayer = uid == expense.paidById;
                final alreadySettled = expense.settledBy[uid] == true;
                if (isPayer || alreadySettled) return const SizedBox.shrink();
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _settleExpense(expense),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('Settle',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white)),
                    ),
                  ),
                ]);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0))),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) async {
          if (index == 1) {
            await _openExpenseForm();
            return;
          }
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF94A3B8),
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Add'),
          BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Groups'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Reports'),
        ],
      ),
    );
  }

 
  String _getMonthName(int month) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][month - 1];

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.isNegative || difference.inMinutes == 0) {
      return 'Just now';
    } else if (difference.inDays == 0) {
      if (difference.inHours == 0) return '${difference.inMinutes}m ago';
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

 String _formatCurrency(double amount) => '$_currencySymbol${amount.toStringAsFixed(0)}';


  List<dynamic> _allForMonth() {
    final year = DateTime.now().year;
    final month = _selectedMonth;
    final box = _isGroupMode ? _groupBox : _personalBox;
    final list = box.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map((m) =>
            _isGroupMode ? GroupExpense.fromMap(m) : PersonalExpense.fromMap(m))
        .where((e) {
      final d = (e as dynamic).date as DateTime;
      return d.year == year && d.month == month;
    }).toList();
    return list;
  }

  double _monthlyTotal() {
    final items = _allForMonth();
    return items.fold(0.0, (s, e) => s + ((e.amount as num).toDouble()));
  }

  double _sumByCategory(String category) {
    final items = _allForMonth();
    return items
        .where((e) => (e.category as String) == category)
        .fold(0.0, (s, e) => s + ((e.amount as num).toDouble()));
  }

  Future<void> _openExpenseForm({dynamic expense}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String? selectedGroupId;

    if (_isGroupMode && expense == null) {
      final groups = await _groupService.getUserGroups().first;
      if (groups.isEmpty) {
        _showSnackBar('You must create or join a group first.');
        return;
      }
      if (!mounted) return;
      selectedGroupId = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select a Group'),
          content: SizedBox(
            width: double.minPositive,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: groups.length,
              itemBuilder: (ctx, index) {
                return ListTile(
                  title: Text(groups[index].name),
                  onTap: () => Navigator.of(ctx).pop(groups[index].id),
                );
              },
            ),
          ),
        ),
      );
      if (selectedGroupId == null) return;
    }

    if (!mounted) return;
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => AddEditExpenseScreen(
          initialIsGroup: expense is GroupExpense
              ? true
              : (expense is PersonalExpense ? false : _isGroupMode),
          expense: expense,
          groupId: selectedGroupId,
        ),
      ),
    );
    if (result == null) return;

    dynamic exp;
    List<String> splitBetween = [];
    if (result is Map) {
      exp = result['expense'];
      final sb = result['splitBetween'];
      if (sb is List) {
        splitBetween = sb.map((e) => e.toString()).toList();
      }
    } else {
      exp = result;
    }

    if (exp is PersonalExpense) {
      var e = exp;
      if (e.id.isEmpty) e = e.copyWith(id: _newId());
      await _personalBox.put(e.id, e.toMap());
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      await userDoc.collection("personal_expenses").doc(e.id).set(e.toMap());
    } else if (exp is GroupExpense) {
      if (expense == null) {
        final gid =
            exp.groupId.isNotEmpty ? exp.groupId : (selectedGroupId ?? '');
        if (gid.isEmpty) {
          _showSnackBar('No group selected.');
          return;
        }

        final members = splitBetween.isNotEmpty
            ? splitBetween
            : await _groupService.getGroupMemberIds(gid);

        await _groupService.addGroupExpense(
          groupId: gid,
          title: exp.title,
          amount: exp.amount,
          splitBetween: members,
          category: exp.category,
        );
      } else {
        final originalExpense = expense as GroupExpense;
        await _groupService.updateGroupExpense(
          groupId: originalExpense.groupId,
          expenseId: exp.id,
          title: exp.title,
          amount: exp.amount,
          category: exp.category,
          isSettled: exp.isSettled,
          splitStatus: exp.splitStatus,
        );
      }
    } else {
      _showSnackBar('Could not save: unknown data returned.');
      return;
    }

    if (mounted) setState(() {});
    _showSnackBar(expense == null ? 'Expense saved' : 'Expense updated');
  }

  void _deleteExpense(dynamic expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;

              if (expense is PersonalExpense) {
                await _personalBox.delete(expense.id);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection("personal_expenses")
                    .doc(expense.id)
                    .delete();
              } else if (expense is GroupExpense) {
                await _groupService.deleteGroupExpense(
                  groupId: expense.groupId,
                  expenseId: expense.id,
                );
              }

              if (mounted) setState(() {});
              _showSnackBar('Expense deleted');
            },
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFE53E3E)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  
  void _settleExpense(GroupExpense expense) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final payerId = expense.paidById;
    final settledByMap = Map<String, bool>.from(expense.settledBy);
    final isMyShareSettled = settledByMap[currentUserId] ?? false;

    // The person who paid cannot settle the expense for others from this button.
    if (currentUserId == payerId) {
      _showSnackBar(
          "You paid for this. Others must settle their share with you.");
      return;
    }

    // Check if the current user has already settled their share.
    if (isMyShareSettled) {
      _showSnackBar("Your share is already marked as settled.");
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settle Your Share'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expense: ${expense.title}'),
            Text('Paid by: ${expense.paidBy}'),
            const SizedBox(height: 16),
            const Text(
                'Confirm that you have paid your share for this expense?'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _groupService.settleUserShare(
                  groupId: expense.groupId,
                  expenseId: expense.id,
                );
                _showSnackBar('Your share has been settled!');
              } catch (e) {
                _showSnackBar('Error: ${e.toString()}');
              }
              
            },
            child: const Text('Confirm & Settle'),
          ),
        ],
      ),
    );
  }


  Future<void> _exportPDFReport() async {
    try {
    
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

     
      final fontData =
          await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);

      // Generate PDF
      final pdf = pw.Document();

      final expenses = _allForMonth();

      pdf.addPage(
        pw.MultiPage(
          theme: pw.ThemeData.withFont(
            base: ttf,
            bold: ttf,
            italic: ttf,
            boldItalic: ttf,
          ),
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              _buildPDFHeader(ttf),
              pw.SizedBox(height: 20),
              _buildPDFSummary(expenses, ttf),
              pw.SizedBox(height: 30),
              _buildPDFExpensesList(expenses, ttf),
              pw.SizedBox(height: 30),
              _buildPDFCategoryBreakdown(expenses, ttf),
            ];
          },
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 10, font: ttf),
            ),
          ),
        ),
      );

      
      if (kIsWeb) {
        // On web, use printing package to display PDF
        if (mounted) Navigator.pop(context);
        final pdfBytes = await pdf.save();
        await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
      } else {
        // On mobile, save to file and offer open/share
        final dir = await getApplicationDocumentsDirectory();
        final mode = _isGroupMode ? 'Group' : 'Personal';
        final monthName = _getMonthName(_selectedMonth);
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'SplitMate_$mode$monthName$timestamp.pdf';

        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(await pdf.save());

      
        if (mounted) Navigator.pop(context);

       
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('PDF Generated'),
              content: Text('Report saved inside app folder as:\n\n$fileName'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await OpenFile.open(
                        file.path); 
                  },
                  child: const Text('Open'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Share.shareXFiles([XFile(file.path)],
                        text: '📊 My SplitMate Expense Report');
                  },
                  child: const Text('Share'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      _showSnackBar('❌ Error generating PDF: $e');
    }
  }

  pw.Widget _buildPDFHeader(pw.Font tff) {
    final monthYear = '${_getMonthName(_selectedMonth)} ${DateTime.now().year}';
    final mode = _isGroupMode ? 'Group Expenses' : 'Personal Expenses';

    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F0F7FF'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SplitMate Expense Report',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#1A1A1A'),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                mode,
                style: pw.TextStyle(
                  fontSize: 16,
                  color: PdfColor.fromHex('#4A90E2'),
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                monthYear,
                style: pw.TextStyle(
                  fontSize: 16,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated on ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromHex('#999999'),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFSummary(List<dynamic> expenses, pw.Font tff) {
    final total = expenses.fold(0.0, (s, e) => s + ((e.amount as num).toDouble()));
    final avgPerDay =
        total / DateTime(DateTime.now().year, _selectedMonth + 1, 0).day;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildPDFSummaryItem(
              'Total Expenses', _formatCurrency(total), '#E53E3E'),
          _buildPDFSummaryItem(
              'Total Transactions', expenses.length.toString(), '#4A90E2'),
          _buildPDFSummaryItem(
              'Daily Average', _formatCurrency(avgPerDay), '#50E3C2'),
        ],
      ),
    );
  }

  pw.Widget _buildPDFSummaryItem(String label, String value, String colorHex) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColor.fromHex('#666666'),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex(colorHex),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPDFExpensesList(List<dynamic> expenses, pw.Font tff) {
    if (expenses.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Text(
          'No expenses recorded for this month',
          style: const pw.TextStyle(fontSize: 14),
        ),
      );
    }


    expenses.sort((a, b) => (b.date as DateTime).compareTo(a.date as DateTime));

    final headers = _isGroupMode
        ? ['Date', 'Title', 'Category', 'Paid By', 'Amount', 'Status']
        : ['Date', 'Title', 'Category', 'Amount'];

    final data = expenses
        .map((e) {
          if (_isGroupMode && e is GroupExpense) {
            return [
              DateFormat('MMM dd').format(e.date),
              e.title,
              e.category,
              e.paidBy,
              _formatCurrency(e.amount),
              e.isSettled ? 'Settled' : 'Pending',
            ];
          } else if (!_isGroupMode && e is PersonalExpense) {
            return [
              DateFormat('MMM dd').format(e.date),
              e.title,
              e.category,
              _formatCurrency(e.amount),
            ];
          }
          return [];
        })
        .where((row) => row.isNotEmpty)
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Expense Details',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColor.fromHex('#E0E0E0')),
          children: [
            
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F5F5F5'),
              ),
              children: headers
                  .map((header) => pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          header,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ))
                  .toList(),
            ),
           
            ...data.map((row) => pw.TableRow(
                  children: row
                      .map((cell) => pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              cell,
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ))
                      .toList(),
                )),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFCategoryBreakdown(List<dynamic> expenses, pw.Font tff) {
    final categories = ['Food', 'Transport', 'Shopping', 'Bills'];
    final categoryTotals = <String, double>{};
    final total = expenses.fold(0.0, (s, e) => s + ((e.amount as num).toDouble()));

    for (final category in categories) {
      categoryTotals[category] = expenses
          .where((e) => e.category == category)
          .fold(0.0, (s, e) => s + ((e.amount as num).toDouble()));
    }

    final barWidth = 200.0; 

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Category Breakdown',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              ...categoryTotals.entries.map((entry) {
                final percentage = total > 0 ? (entry.value / total * 100) : 0;

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 100,
                        child: pw.Text(entry.key),
                      ),
                      pw.Container(
                        width: barWidth,
                        height: 20,
                        child: pw.Stack(
                          children: [
                            
                            pw.Container(
                              width: barWidth,
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('#F0F0F0'),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                            ),
                            
                            pw.Container(
                              width: barWidth * (percentage / 100),
                              decoration: pw.BoxDecoration(
                                color: _getCategoryColor(entry.key),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Container(
                        width: 80,
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          _formatCurrency(entry.value),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Container(
                        width: 50,
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              pw.Divider(color: PdfColor.fromHex('#E0E0E0')),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    _formatCurrency(total),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                      color: PdfColor.fromHex('#E53E3E'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  PdfColor _getCategoryColor(String category) {
    switch (category) {
      case 'Food':
        return PdfColor.fromHex('#4A90E2');
      case 'Transport':
        return PdfColor.fromHex('#50E3C2');
      case 'Shopping':
        return PdfColor.fromHex('#E5A23A');
      case 'Bills':
        return PdfColor.fromHex('#E53E3E');
      default:
        return PdfColor.fromHex('#999999');
    }
  }



  Future<void> _manageParentAccess() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnackBar("⚠ Login required");
      return;
    }

    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = List.generate(8, (_) {
      return chars[random.nextInt(chars.length)];
    }).join();

    await FirebaseFirestore.instance.collection("monitor_codes").doc(code).set({
      "childUid": uid,
      "createdAt": FieldValue.serverTimestamp(),
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("👨‍👩‍👧 Parent Monitoring Guide"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("For a parent to monitor your expenses:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("1️⃣ Parent must have the SplitMate app installed."),
              const Text("2️⃣ Copy this URL scheme and open it in browser:\n"),
              SelectableText("splitmate://monitor?code=$code",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 14)),
              const SizedBox(height: 10),
              const Text(
                  "3️⃣ The browser will ask to open with SplitMate → Continue."),
              Text("4️⃣ Enter this code inside the app to validate:\n",
                  style: const TextStyle(fontWeight: FontWeight.normal)),
              SelectableText(code,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 24)),
              const SizedBox(height: 10),
              const Text(
                  "✅ Parent can now see either Personal or Group expenses using the toggle in monitoring screen."),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final message = "👨‍👩‍👧 Parent Monitoring Steps:\n\n"
                    "1. Install SplitMate app\n"
                    "2. In browser enter: splitmate://monitor?code=$code\n"
                    "3. Continue to open SplitMate\n"
                    "4. Enter Monitor Code: $code\n\n"
                    "Now you can monitor child’s Personal/Group expenses ✅";
                Share.share(message);
                Navigator.pop(context);
              },
              child: const Text("📤 Share Instructions"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    );
  }
}