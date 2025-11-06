import 'package:flutter/material.dart';
import '../services/group_service.dart';
import 'package:splitmate_expense_tracker/models/models.dart';

class AddMemberDialog extends StatefulWidget {
  final Group group;
  const AddMemberDialog({super.key, required this.group});

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _searchController = TextEditingController();
  final GroupService _groupService = GroupService();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _sendingInvite = false;
  String? _inviteSuccess;
  String? _inviteError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isSearching = true;
      _inviteSuccess = null;
      _inviteError = null;
    });
    try {
      final results = await _groupService.searchUsers(query);
      setState(() {
        _searchResults = results.where((user) => !widget.group.members.contains(user['uid'])).toList();
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _sendInvite(Map<String, dynamic> user) async {
    setState(() {
      _sendingInvite = true;
      _inviteSuccess = null;
      _inviteError = null;
    });
    try {
      await _groupService.sendInvitation(widget.group.id, widget.group.name, user['uid'] as String);
      setState(() {
        _inviteSuccess = "Invitation sent to ${user['email']}";
        _inviteError = null;
      });
    } catch (e) {
      setState(() {
        _inviteError = "Failed: $e";
        _inviteSuccess = null;
      });
    } finally {
      setState(() {
        _sendingInvite = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            const Text('Add Member', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by email',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              ),
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) => _searchUsers(v),
            ),
            if (_inviteSuccess != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _inviteSuccess!,
                  style: const TextStyle(color: Colors.green),
                ),
              ),
            if (_inviteError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _inviteError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: (_isSearching)
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          title: Text(user['username'] ?? 'User'),
                          subtitle: Text(user['email'] ?? ""),
                          trailing: ElevatedButton(
                            onPressed: _sendingInvite ? null : () => _sendInvite(user),
                            child: const Text('Invite'),
                          ),
                        );
                      }),
            ),
          ],
        ),
      ),
    );
  }
}