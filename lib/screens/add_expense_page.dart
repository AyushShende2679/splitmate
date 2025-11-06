import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitmate_expense_tracker/screens/services/group_service.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isGroupExpense = false;
  final TextEditingController _paidByController =
      TextEditingController(text: 'You');
  bool _isSettled = true;

  
  String _currencySymbol = '₹';
  List<String> _categories = [];


  late Box _personalBox;
  late Box _groupBox;

  final GroupService _groupService = GroupService();
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();

    _loadCategories(); 

    _personalBox = Hive.box('personal_expenses');
    _groupBox = Hive.box('group_expenses');
  }

  void _loadCategories() {
    final settingsBox = Hive.box('settings');
    if (settingsBox.containsKey('settings')) {
      final settings = Map<String, dynamic>.from(settingsBox.get('settings'));
      setState(() {
        _categories = List<String>.from(settings['categories'] ??
            [
              'Food',
              'Transport',
              'Shopping',
              'Bills',
              'Entertainment',
              'Other'
            ]);
      });
    } else {
      
      setState(() {
        _categories = [
          'Food',
          'Transport',
          'Shopping',
          'Bills',
          'Entertainment',
          'Other'
        ];
      });
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _ensureSelectedGroup() async {
    if (_selectedGroupId != null && _selectedGroupId!.isNotEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final groups = await _groupService.getUserGroups().first;
      if (groups.isNotEmpty) {
        setState(() => _selectedGroupId = groups.first.id);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveExpense() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to save expenses')),
      );
      return;
    }

    if (_isGroupExpense) {
      await _ensureSelectedGroup();
      if (_selectedGroupId == null || _selectedGroupId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No group found. Create/join a group first.')),
        );
        return;
      }

      final members = await _groupService.getGroupMemberIds(_selectedGroupId!);
      final amount = double.tryParse(_amountController.text) ?? 0.0;

      await _groupService.addGroupExpense(
        groupId: _selectedGroupId!,
        title: _titleController.text.trim(),
        amount: amount,
        splitBetween: members,
        description:
            _noteController.text.isEmpty ? null : _noteController.text.trim(),
        category: _categoryController.text.isNotEmpty
            ? _categoryController.text
            : 'Other',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group expense added!')),
      );
    } else {
      // Personal expense logic
      final expense = PersonalExpense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        amount: double.tryParse(_amountController.text) ?? 0.0,
        date: _selectedDate,
        category: _categoryController.text.isNotEmpty
            ? _categoryController.text
            : 'Other',
      );

      await _personalBox.put(expense.id, expense.toMap());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('personal_expenses')
          .doc(expense.id)
          .set(expense.toMap());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Personal expense saved!')),
      );
    }

    _clearForm();
    if (mounted) Navigator.pop(context);
  }

  void _clearForm() {
    _titleController.clear();
    _amountController.clear();
    _categoryController.clear();
    _noteController.clear();
    _paidByController.text = 'You';
    _isSettled = true;
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('user_profile').listenable(),
      builder: (context, profileBox, _) {
        
        if (profileBox.containsKey('profile')) {
          final profile = UserProfile.fromMap(
              Map<String, dynamic>.from(profileBox.get('profile')));
          _currencySymbol = profile.currency;
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text('Add Expense'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.grey[800],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _isGroupExpense = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isGroupExpense
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_isGroupExpense
                                    ? [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2))
                                      ]
                                    : null,
                              ),
                              child: const Text('Personal',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              setState(() => _isGroupExpense = true);
                              await _ensureSelectedGroup();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isGroupExpense
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _isGroupExpense
                                    ? [
                                        BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2))
                                      ]
                                    : null,
                              ),
                              child: const Text('Group',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                        labelText: 'Expense Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '$_currencySymbol ',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.money),
                    ),
                    
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _categoryController.text.isNotEmpty
                        ? _categoryController.text
                        : null,
                    decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category)),
                  
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                          value: category, child: Text(category));
                    }).toList(),
                   
                    onChanged: (value) {
                      setState(() {
                        _categoryController.text = value ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              DateFormat('MMM dd, yyyy').format(_selectedDate)),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note)),
                  ),
                  if (_isGroupExpense) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _paidByController,
                      decoration: const InputDecoration(
                          labelText: 'Paid By',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Settled'),
                      value: _isSettled,
                      onChanged: (value) {
                        setState(() => _isSettled = value);
                      },
                      activeThumbColor: const Color(0xFF4A90E2),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveExpense,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Add Expense'),
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
}
