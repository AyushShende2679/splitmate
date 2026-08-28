import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/config/app_constants.dart';
import '../../data/models/budget.dart';
import '../../data/repositories/budget_repository.dart';
import '../../models/models.dart';

final budgetRepositoryProvider = Provider((ref) => BudgetRepository());

final budgetsProvider = StateNotifierProvider<BudgetNotifier, List<Budget>>((ref) {
  return BudgetNotifier(ref.read(budgetRepositoryProvider));
});

class BudgetNotifier extends StateNotifier<List<Budget>> {
  final BudgetRepository _repo;
  BudgetNotifier(this._repo) : super([]) {
    _load();
    // listen to hive changes
    Hive.box(AppConstants.boxBudgets).listenable().addListener(_load);
    Hive.box(AppConstants.boxPersonal).listenable().addListener(_notify);
  }

  void _load() {
    state = _repo.getAll();
  }

  void _notify() {
    // trigger rebuild for spent calculation
    state = [...state];
  }

  Future<void> setBudget(String category, double limit) async {
    await _repo.setBudget(category, limit);
    _load();
  }

  Future<void> deleteBudget(String category) async {
    await _repo.deleteBudget(category);
    _load();
  }

  double spentForCategory(String category, {DateTime? date}) {
    final d = date ?? DateTime.now();
    final expenses = Hive.box(AppConstants.boxPersonal).values
        .whereType<Map>()
        .map((e) => PersonalExpense.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => e.date.month == d.month && e.date.year == d.year)
        .toList();
    return expenses.where((e) => e.category == category).fold(0.0, (s, e) => s + e.amount);
  }

  double get totalBudget => state.fold(0.0, (s, b) => s + b.limit);

  double get totalSpent {
    final now = DateTime.now();
    final expenses = Hive.box(AppConstants.boxPersonal).values
        .whereType<Map>()
        .map((e) => PersonalExpense.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => e.date.month == now.month && e.date.year == now.year)
        .toList();
    return expenses.fold(0.0, (s, e) => s + e.amount);
  }

  @override
  void dispose() {
    Hive.box(AppConstants.boxBudgets).listenable().removeListener(_load);
    Hive.box(AppConstants.boxPersonal).listenable().removeListener(_notify);
    super.dispose();
  }
}

// Alert state: 0=ok, 1=warning(>80%), 2=exceeded
int budgetAlertLevel(double spent, double limit) {
  if (limit <= 0) return 0;
  final pct = spent / limit;
  if (pct >= 1.0) return 2;
  if (pct >= 0.8) return 1;
  return 0;
}
