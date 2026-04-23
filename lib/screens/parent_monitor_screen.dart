import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:splitmate_expense_tracker/theme/app_theme.dart';

class ParentMonitorScreen extends StatefulWidget {
  final String childUid;
  const ParentMonitorScreen({super.key, required this.childUid});

  @override
  State<ParentMonitorScreen> createState() => _ParentMonitorScreenState();
}

class _ParentMonitorScreenState extends State<ParentMonitorScreen> {
  bool _isGroupMode = false;

 
  Stream<QuerySnapshot<Map<String, dynamic>>> _personalStream() {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(widget.childUid)
        .collection("personal_expenses")
        .orderBy("date", descending: true)
        .snapshots();
  }

  
  Stream<QuerySnapshot<Map<String, dynamic>>> _groupPaidByStream() {
    return FirebaseFirestore.instance
        .collection("group_expenses")
        .where("paidBy", isEqualTo: widget.childUid)
        .snapshots();
  }

 
  Stream<QuerySnapshot<Map<String, dynamic>>> _groupSharedStream() {
    return FirebaseFirestore.instance
        .collection("group_expenses")
        .where("splitBetween", arrayContains: widget.childUid)
        .snapshots();
  }

 
  Stream<QuerySnapshot<Map<String, dynamic>>> _userGroupSubcollectionStream() {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(widget.childUid)
        .collection("group_expenses")
        .orderBy("date", descending: true)
        .snapshots();
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal is Timestamp) {
      return DateFormat("dd MMM, yyyy").format(dateVal.toDate());
    } else if (dateVal is String) {
      try {
        final parsed = DateTime.parse(dateVal);
        return DateFormat("dd MMM, yyyy").format(parsed);
      } catch (_) {
        return dateVal;
      }
    } else if (dateVal is DateTime) {
      return DateFormat("dd MMM, yyyy").format(dateVal);
    }
    return "—";
  }

  DateTime _getSortDate(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final date = data['date'];

    DateTime? tryConv(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      if (v is DateTime) return v;
      return null;
    }

    return tryConv(createdAt) ??
        tryConv(date) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _buildPersonalList(String currencySymbol) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _personalStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No personal expenses yet.", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))));
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final amount = (data['amount'] ?? 0);
            final title = data['title'] ?? "Untitled";
            final category = data['category'] ?? "Uncategorized";
            final formattedDate = _formatDate(data['date']);

            return Card(
              color: Colors.white.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(Icons.person, color: AppTheme.chartRose),
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: Text("$category • $formattedDate", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                trailing: Text(
                  "$currencySymbol${amount.toString()}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupList(String currencySymbol) {
    
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _groupPaidByStream(),
      builder: (context, snapPaid) {
        if (snapPaid.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final paidDocs = snapPaid.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _groupSharedStream(),
          builder: (context, snapShared) {
            final sharedDocs = snapShared.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _userGroupSubcollectionStream(),
              builder: (context, snapUserGroup) {
                final userGroupDocs = snapUserGroup.data?.docs ?? [];

                
                final Map<String, Map<String, dynamic>> merged = {};
                for (final d in paidDocs) {
                  merged[d.id] = d.data();
                }
                for (final d in sharedDocs) {
                  merged[d.id] = d.data();
                }

                
                for (final d in userGroupDocs) {
                  final m = Map<String, dynamic>.from(d.data());
                  
                  merged[d.id] = m;
                }

                if (merged.isEmpty) {
                 
                  return Center(child: Text("No group expenses yet.", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))));
                }

                final items = merged.entries.toList()
                  ..sort((a, b) =>
                      _getSortDate(b.value).compareTo(_getSortDate(a.value)));

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final data = items[index].value;
                    final amount = (data['amount'] ?? 0);
                    final title = data['title'] ?? "Untitled";
                    final category = data['category'] ?? "Uncategorized";
                    final formattedDate = data.containsKey('createdAt')
                        ? _formatDate(data['createdAt'])
                        : _formatDate(data['date']);

                    return Card(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Icon(Icons.group, color: AppTheme.chartBlue),
                        title: Text(title,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                        subtitle: Text("$category • $formattedDate", style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                        trailing: Text(
                          "$currencySymbol${amount.toString()}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(widget.childUid)
            .snapshots(),
        builder: (context, userSnap) {
          String childCurrency = '₹'; 
          if (userSnap.hasData && userSnap.data!.exists) {
            childCurrency = userSnap.data!.data()?['currency'] ?? '₹';
          }
          return Scaffold(
                  appBar: AppBar(
              title: const Text("Monitoring Expenses"),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: Icon(_isGroupMode ? Icons.group : Icons.person),
                  onPressed: () => setState(() => _isGroupMode = !_isGroupMode),
                  tooltip: _isGroupMode ? "Show Personal" : "Show Group",
                ),
              ],
            ),
            body: _isGroupMode
                ? _buildGroupList(childCurrency)
                : _buildPersonalList(childCurrency),
          );
        });
  }
}
