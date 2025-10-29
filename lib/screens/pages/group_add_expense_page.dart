import 'package:flutter/material.dart';
import 'package:splitmate_expense_tracker/models/models.dart';
import '../services/group_service.dart';

class GroupAddExpensePage extends StatefulWidget {
  final Group group;

  const GroupAddExpensePage({super.key, required this.group});

  @override
  State<GroupAddExpensePage> createState() => _GroupAddExpensePageState();
}

class _GroupAddExpensePageState extends State<GroupAddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GroupService _groupService = GroupService();
  
  String? _selectedCategory;
  List<String> _selectedMembers = [];
  bool _isLoading = false;

  final List<String> _categories = [
    'Food & Drinks',
    'Transportation',
    'Accommodation',
    'Entertainment',
    'Shopping',
    'Bills',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMembers = List.from(widget.group.members);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addExpense() async {
  if (!_formKey.currentState!.validate()) return;
  if (_selectedMembers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select at least one member')),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    await _groupService.addGroupExpense(
      groupId: widget.group.id,
      title: _titleController.text,
      amount: double.parse(_amountController.text),
      splitBetween: _selectedMembers,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      category: _selectedCategory,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added successfully')),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Group Expense'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Expense Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            const Text(
              'Split Between',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: widget.group.members.map((memberId) {
                  return CheckboxListTile(
                    title: Text(memberId),
                    value: _selectedMembers.contains(memberId),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedMembers.add(memberId);
                        } else {
                          _selectedMembers.remove(memberId);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _addExpense,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}