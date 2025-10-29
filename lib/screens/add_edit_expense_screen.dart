import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // <-- ADDED for Hive access
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'package:splitmate_expense_tracker/screens/services/group_service.dart';

class AddEditExpenseScreen extends StatefulWidget {
  final bool initialIsGroup;
  final dynamic expense;
  final String? groupId;

  const AddEditExpenseScreen({
    super.key,
    required this.initialIsGroup,
    this.expense,
    this.groupId,
  });

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isGroup;
  late bool _isEditing;

  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _category = 'Food';
  DateTime _date = DateTime.now();
  
  
  String _currencySymbol = '₹';
  List<String> _categories = [];
 
  final GroupService _groupService = GroupService();
  List<Map<String, dynamic>> _groupMembers = [];
  List<String> _selectedMemberIds = [];
  bool _isLoadingMembers = false;

  @override
  void initState() {
    super.initState();
    _loadCategories(); 

    _isEditing = widget.expense != null;
    _isGroup = widget.initialIsGroup;

    if (_isEditing) {
      if (widget.expense is GroupExpense) {
        final e = widget.expense as GroupExpense;
        _titleCtrl.text = e.title;
        _amountCtrl.text = e.amount.toString();
        _date = e.date;
        _category = e.category;
      } else if (widget.expense is PersonalExpense) {
        final e = widget.expense as PersonalExpense;
        _titleCtrl.text = e.title;
        _amountCtrl.text = e.amount.toString();
        _date = e.date;
        _category = e.category;
      }
    }

    if (_isGroup && !_isEditing && widget.groupId != null) {
      _fetchGroupMembers();
    }
  }

  

  void _loadCategories() {
    final settingsBox = Hive.box('settings');
    if (settingsBox.containsKey('settings')) {
      final settings = Map<String, dynamic>.from(settingsBox.get('settings'));
      setState(() {
        _categories = List<String>.from(settings['categories'] ?? ['Food', 'Transport', 'Shopping', 'Bills', 'Entertainment', 'Other']);
       
        if (!_categories.contains(_category)) {
          _category = _categories.isNotEmpty ? _categories.first : 'Other';
        }
      });
    } else {
       
      setState(() {
        _categories = ['Food', 'Transport', 'Shopping', 'Bills', 'Entertainment', 'Other'];
      });
    }
  }
  
  Future<void> _fetchGroupMembers() async {
    setState(() => _isLoadingMembers = true);
    final members = await _groupService.getGroupMemberDetails(
        await _groupService.getGroupMemberIds(widget.groupId!));
    setState(() {
      _groupMembers = members;
      _selectedMemberIds = members.map((m) => m['uid'] as String).toList();
      _isLoadingMembers = false;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (res != null) setState(() => _date = res);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    
    if (_isGroup) {
      if (_selectedMemberIds.isEmpty && !_isEditing) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please select at least one member to split with.'),
              backgroundColor: Colors.orange,
          ));
          return;
      }

      String effectiveGroupId;
      if (_isEditing) {
        effectiveGroupId = (widget.expense as GroupExpense).groupId;
      } else {
        effectiveGroupId = widget.groupId ?? '';
      }

      final e = GroupExpense(
        id: _isEditing ? (widget.expense as GroupExpense).id : '',
        groupId: effectiveGroupId,
        title: _titleCtrl.text.trim(),
        amount: amount,
        date: _date,
        category: _category,
        paidBy: '',
        paidById: '',
        splitStatus: 'Split between ${_selectedMemberIds.length} people',
        isSettled: false, 
        settledBy: {},
      );
      
      Navigator.pop(context, {
          'expense': e,
          'splitBetween': _selectedMemberIds,
      });

    } else {
      final e = PersonalExpense(
        id: _isEditing ? (widget.expense as PersonalExpense).id : '',
        title: _titleCtrl.text.trim(),
        amount: amount,
        date: _date,
        category: _category,
      );
      Navigator.pop(context, {'expense': e});
    }
  }


  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('user_profile').listenable(),
      builder: (context, profileBox, _) {

        
        if (profileBox.containsKey('profile')) {
          final profile = UserProfile.fromMap(Map<String, dynamic>.from(profileBox.get('profile')));
          _currencySymbol = profile.currency;
        }
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Expense' : 'Add Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isEditing)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(child: _buildToggleButton('Personal', !_isGroup, () => setState(() => _isGroup = false))),
                      Expanded(child: _buildToggleButton('Group', _isGroup, () => setState(() => _isGroup = true))),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                
                decoration: InputDecoration(labelText: 'Amount ($_currencySymbol)', border: const OutlineInputBorder()),
                
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final d = double.tryParse((v ?? '').trim());
                  if (d == null || d <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              
                onChanged: (v) => setState(() => _category = v ?? 'Food'),
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Date'),
                  child: Text(DateFormat('MMM dd, yyyy').format(_date)),
                ),
              ),
              if (_isGroup && !_isEditing) ...[
                const SizedBox(height: 24),
                Text('Split Between', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _isLoadingMembers
                    ? const Center(child: CircularProgressIndicator())
                    : Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _groupMembers.length,
                          itemBuilder: (context, index) {
                            final member = _groupMembers[index];
                            final memberId = member['uid'] as String;
                            return CheckboxListTile(
                              title: Text(member['username'] ?? 'Unknown User'),
                              value: _selectedMemberIds.contains(memberId),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedMemberIds.add(memberId);
                                  } else {
                                    _selectedMemberIds.remove(memberId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      )
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(_isEditing ? 'Update Expense' : 'Save Expense'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    },
    );
  }

  Widget _buildToggleButton(String text, bool isActive, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isActive ? Theme.of(context).primaryColor : Colors.grey[600])),
      ),
    );
  }
}