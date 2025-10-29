import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'package:splitmate_expense_tracker/screens/services/firestore_sync_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late Box _profileBox;
  late Box _personalBox;
  late Box _groupBox;
  late Box _settingsBox;
  
  late UserProfile _profile;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedCurrency = '₹';
  final List<String> _currencies = ['₹', '\$', '€', '£', '¥'];
  
  double _monthlyBudget = 0.0;
  bool _budgetAlerts = true;
  
  bool _dataBackup = true;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  List<String> _expenseCategories = [
    'Food', 'Transport', 'Shopping', 'Entertainment', 
    'Bills', 'Healthcare', 'Education', 'Others'
  ];
  
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  @override
  void initState() {
    super.initState();
    _initializeBoxes();
    _initializeAnimations();
    _loadProfile();
    _loadSettings();
    _loadUserDataFromFirebase();
  }
  
  void _initializeBoxes() {
    _profileBox = Hive.box('user_profile');
    _personalBox = Hive.box('personal_expenses');
    _groupBox = Hive.box('group_expenses');
    _settingsBox = Hive.box('settings');
  }
  
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  Future<void> _ensureProfileFromAuth() async {
    final user = _auth.currentUser;
    if (user == null) return;

    Map<String, dynamic> existing = {};
    if (_profileBox.containsKey('profile')) {
      final raw = _profileBox.get('profile');
      if (raw is Map) existing = Map<String, dynamic>.from(raw);
    }

    final existingName = (existing['name'] ?? '').toString().trim();
    final existingEmail = (existing['email'] ?? '').toString().trim();
    final isDefaultName = existingName.isEmpty || existingName.toLowerCase() == 'user';
    final isDefaultEmail = existingEmail.isEmpty || existingEmail == 'user@example.com';

    String newEmail = existingEmail;
    if (isDefaultEmail && (user.email?.isNotEmpty ?? false)) {
      newEmail = user.email!.trim();
    }

    String newName = existingName;
    final authDisplayName = user.displayName?.trim() ?? '';
    if (isDefaultName) {
      if (authDisplayName.isNotEmpty) {
        newName = authDisplayName;
      } else if (newEmail.isNotEmpty) {
        newName = newEmail.split('@').first;
      }
    }

    final needsUpdate = (newName != existingName) || (newEmail != existingEmail) || (existing['id'] == null || (existing['id'].toString().isEmpty));
    if (needsUpdate) {
      final updated = <String, dynamic>{
        ...existing,
        'id': (existing['id']?.toString().isNotEmpty == true) ? existing['id'].toString() : user.uid,
        'name': newName,
        'email': newEmail,
      };

      await _profileBox.put('profile', updated);
      _profile = UserProfile.fromMap(updated);
      _nameController.text = _profile.name;
      _emailController.text = _profile.email;

      await syncAppDataToFirestore();
    }
  }
  
  void _loadUserDataFromFirebase() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        if (user.email != null && user.email!.isNotEmpty) {
          _emailController.text = user.email!;
        }
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          _nameController.text = user.displayName!;
        }
      });

      await restoreAppDataFromFirestore();
      await _ensureProfileFromAuth();

      _loadProfile();
      _loadSettings();
      if (mounted) setState(() {});
    }
  }
  
  void _loadProfile() {
    if (_profileBox.isNotEmpty && _profileBox.containsKey('profile')) {
      final profileData = _profileBox.get('profile');
      _profile = UserProfile.fromMap(Map<String, dynamic>.from(profileData));
    } else {
      _profile = UserProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'User',
        email: 'user@example.com',
        phone: '+1234567890',
        currency: '₹',
        profileImagePath: '',
      );
      _saveProfileToBox();
    }
    
    _nameController.text = _profile.name;
    _emailController.text = _profile.email;
    _phoneController.text = _profile.phone;
    _selectedCurrency = _profile.currency;
  }
  
  void _loadSettings() {
    if (_settingsBox.containsKey('settings')) {
      final settings = Map<String, dynamic>.from(_settingsBox.get('settings'));
      setState(() {
        _monthlyBudget = settings['monthlyBudget'] ?? 0.0;
        _budgetAlerts = settings['budgetAlerts'] ?? true;
        _dataBackup = settings['dataBackup'] ?? true;
        _expenseCategories = List<String>.from(settings['categories'] ?? _expenseCategories);
      });
    }
  }
  
  Future<void> _saveSettings() async {
    await _settingsBox.put('settings', {
      'monthlyBudget': _monthlyBudget,
      'budgetAlerts': _budgetAlerts,
      'dataBackup': _dataBackup,
      'notificationsEnabled': false,
      'biometricEnabled': false,
      'categories': _expenseCategories,
    });
    await syncAppDataToFirestore();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxHeight: 512,
      maxWidth: 512,
      imageQuality: 85,
    );
    
    if (image != null) {
      final imageBytes = await image.readAsBytes();
      final String base64String = base64Encode(imageBytes);
      
      setState(() {
        _profile = _profile.copyWith(profileImagePath: base64String);
      });
      await _saveProfileToBox();
      await syncAppDataToFirestore();
    }
  }
  
  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = _profile.copyWith(
        name: _nameController.text.trim().isEmpty ? _profile.name : _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? _profile.email : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? _profile.phone : _phoneController.text.trim(),
        currency: _selectedCurrency,
      );

      setState(() => _profile = updatedProfile);
      await _saveProfileToBox();
      await syncAppDataToFirestore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile saved successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
  
  Future<void> _saveProfileToBox() async {
    await _profileBox.put('profile', _profile.toMap());
  }
  
  final Map<String, dynamic> _statsCache = {};
  
  double _getTotalPersonalExpenses() {
    const cacheKey = 'total_personal';
    if (_statsCache.containsKey(cacheKey)) {
      return _statsCache[cacheKey];
    }
    
    final expenses = _personalBox.values
        .whereType<Map>()
        .map((e) => PersonalExpense.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    
    final total = expenses.fold(0.0, (sum, expense) => sum + expense.amount);
    _statsCache[cacheKey] = total;
    return total;
  }
  
  double _getMonthlyExpenses() {
    final now = DateTime.now();
    final cacheKey = 'monthly_${now.month}_${now.year}';
    
    if (_statsCache.containsKey(cacheKey)) {
      return _statsCache[cacheKey];
    }
    
    final expenses = _personalBox.values
        .whereType<Map>()
        .map((e) => PersonalExpense.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .toList();
    
    final total = expenses.fold(0.0, (sum, expense) => sum + expense.amount);
    _statsCache[cacheKey] = total;
    return total;
  }
  
  int _getCategoryCount() {
    const cacheKey = 'category_count';
    if (_statsCache.containsKey(cacheKey)) {
      return _statsCache[cacheKey];
    }
    
    final expenses = _personalBox.values
        .whereType<Map>()
        .map((e) => PersonalExpense.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    
    final categories = expenses.map((e) => e.category).toSet();
    final count = categories.length;
    _statsCache[cacheKey] = count;
    return count;
  }
  
  Future<void> _exportData() async {
    try {
    
      final personalExpenses = _personalBox.values
          .whereType<Map>()
          .map((e) => PersonalExpense.fromMap(Map<String, dynamic>.from(e)))
          .map((e) {
            final map = e.toMap();
  
            if (map['date'] is DateTime) {
              map['date'] = (map['date'] as DateTime).toIso8601String();
            }
            return map;
          })
          .toList();
      
      final groupExpenses = _groupBox.values
          .whereType<Map>()
          .map((e) {
            
            final map = Map<String, dynamic>.from(e);
            
            if (map['date'] is DateTime) {
              map['date'] = (map['date'] as DateTime).toIso8601String();
            }
            return map;
          })
          .toList();
      
      

      final exportData = {
        'profile': _profile.toMap(),
        'personalExpenses': personalExpenses,
        'groupExpenses': groupExpenses,
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      };
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/expense_data_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonString);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My Expense Data Backup',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _showCategoriesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Categories'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _expenseCategories.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_expenseCategories[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _expenseCategories.removeAt(index);
                          });
                          _saveSettings();
                          Navigator.pop(context);
                          _showCategoriesDialog();
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAddCategoryDialog();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _expenseCategories.add(controller.text.trim());
                });
                _saveSettings();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category added')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  void _showBudgetDialog() {
    final budgetController = TextEditingController(text: _monthlyBudget.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Budget Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: budgetController,
              decoration: InputDecoration(
                labelText: 'Monthly Budget',
                prefixText: _selectedCurrency,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Budget Alerts'),
              subtitle: const Text('Get notified when near budget limit'),
              value: _budgetAlerts,
              onChanged: (value) {
                setState(() {
                  _budgetAlerts = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _monthlyBudget = double.tryParse(budgetController.text) ?? 0.0;
              });
              _saveSettings();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Budget settings saved')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete ALL your expenses, profile, and settings from both device and cloud. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _personalBox.clear();
      await _groupBox.clear();
      await _settingsBox.clear();
      await _profileBox.clear();
      _statsCache.clear();

      await clearAppDataFromFirestore();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared (local + cloud)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    
    if (confirm == true && mounted) {
      try {
        await _saveSettings();
        await _auth.signOut();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully'),
            backgroundColor: Color(0xFF50E3C2),
          ),
        );
        
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

 
  ImageProvider? _getProfileImageProvider() {
    final imageData = _profile.profileImagePath;
    if (imageData.isEmpty) {
      return null; 
    }
    
    try {
      // Try to decode as Base64 (new format)
      final imageBytes = base64Decode(imageData);
      return MemoryImage(imageBytes);
    } catch (e) {
      // If it fails, it might be an old file path
      final imageFile = File(imageData);
      if (imageFile.existsSync()) {
        return FileImage(imageFile);
      }
    }
    
    
    return null;
  }
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.grey[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _statsCache.clear();
              setState(() {});
            },
            tooltip: 'Refresh Stats',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                           
                            backgroundImage: _getProfileImageProvider(),
                            child: _profile.profileImagePath.isEmpty
                                ? Icon(Icons.person, size: 50, color: Colors.indigo[700])
                                : null,
                           
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.indigo[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _profile.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _profile.email,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCard(
                          'Total Expenses',
                          '${_profile.currency}${_getTotalPersonalExpenses().toStringAsFixed(0)}',
                          Icons.account_balance_wallet,
                        ),
                        _buildStatCard(
                          'This Month',
                          '${_profile.currency}${_getMonthlyExpenses().toStringAsFixed(0)}',
                          Icons.calendar_month,
                        ),
                        _buildStatCard(
                          'Categories',
                          _getCategoryCount().toString(),
                          Icons.category,
                        ),
                      ],
                    ),
                    if (_monthlyBudget > 0) ...[
                      const SizedBox(height: 16),
                      _buildBudgetProgress(),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (value.trim().length < 10) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: InputDecoration(
                          labelText: 'Currency',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.currency_exchange_outlined),
                        ),
                        items: _currencies.map((currency) {
                          return DropdownMenuItem<String>(
                            value: currency,
                            child: Text(currency, style: const TextStyle(fontSize: 18)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCurrency = value!;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Save Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildProfileOption(
                'Expense Categories',
                Icons.category_outlined,
                _showCategoriesDialog,
                subtitle: '${_expenseCategories.length} categories',
              ),
              
              _buildProfileOption(
                'Budget Settings',
                Icons.savings_outlined,
                _showBudgetDialog,
                subtitle: _monthlyBudget > 0 
                    ? '${_profile.currency}${_monthlyBudget.toStringAsFixed(0)}/month' 
                    : 'Not set',
              ),
              
              _buildProfileOption(
                'Export Data',
                Icons.download_outlined,
                _exportData,
                subtitle: 'Backup your data',
              ),

              _buildProfileOption(
                'Clear All Data',
                Icons.delete_forever_outlined,
                _clearAllData,
                subtitle: 'Delete all expenses',
                isDestructive: true,
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildBudgetProgress() {
    final spent = _getMonthlyExpenses();
    final percentage = _monthlyBudget > 0 ? (spent / _monthlyBudget).clamp(0.0, 1.0) : 0.0;
    final remaining = (_monthlyBudget - spent).clamp(0.0, double.infinity);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monthly Budget',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${_profile.currency}${remaining.toStringAsFixed(0)} left',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: Colors.white30,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage > 0.8 
                    ? Colors.red 
                    : percentage > 0.6 
                        ? Colors.orange 
                        : Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(percentage * 100).toStringAsFixed(0)}% spent',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileOption(
    String title, 
    IconData icon, 
    VoidCallback onTap, {
    String? subtitle,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDestructive 
                        ? Colors.red.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive ? Colors.red : Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDestructive ? Colors.red : Colors.grey[800],
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

