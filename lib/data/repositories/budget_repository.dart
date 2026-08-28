import 'package:hive_flutter/hive_flutter.dart';
import '../../core/config/app_constants.dart';
import '../models/budget.dart';
import 'package:uuid/uuid.dart';

class BudgetRepository {
  final Box _box = Hive.box(AppConstants.boxBudgets);
  final _uuid = const Uuid();

  List<Budget> getAll() {
    return _box.values
        .whereType<Map>()
        .map((e) => Budget.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.category.compareTo(b.category));
  }

  Budget? getByCategory(String category) {
    final all = getAll();
    try {
      return all.firstWhere((b) => b.category == category);
    } catch (_) {
      return null;
    }
  }

  Future<void> setBudget(String category, double limit) async {
    if (limit <= 0 || limit > 10000000) throw ArgumentError('Budget must be 1 - 10,000,000');
    if (!AppConstants.defaultCategories.contains(category)) throw ArgumentError('Invalid category');
    final now = DateTime.now();
    final existing = getByCategory(category);
    final id = existing?.id ?? _uuid.v4();
    final budget = Budget(
      id: id,
      category: category,
      limit: limit,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _box.put(id, budget.toMap());
    // SaaS: persist to settings for Firestore rules allow (users/{uid} only) - Phase 4 connection
    final settingsBox = Hive.box(AppConstants.boxSettings);
    final settings = settingsBox.get('settings') is Map ? Map<String, dynamic>.from(settingsBox.get('settings')) : <String, dynamic>{};
    settings['budgets'] = getAll().map((e) => e.toMap()).toList();
    await settingsBox.put('settings', settings);
  }

  Future<void> deleteBudget(String category) async {
    final existing = getByCategory(category);
    if (existing != null) await _box.delete(existing.id);
  }

  // Computes spent for given month/year
  double spentFor(String category, int month, int year, List<dynamic> personalExpenses) {
    return personalExpenses
        .where((e) => (e.category as String) == category && (e.date as DateTime).month == month && (e.date as DateTime).year == year)
        .fold(0.0, (s, e) => s + (e.amount as double));
  }
}
