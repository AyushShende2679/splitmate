import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/config/app_constants.dart';
import '../../models/budget.dart';
import '../../../models/models.dart';

class HiveService {
  HiveService._();
  static final instance = HiveService._();

  Box get personalBox => Hive.box(AppConstants.boxPersonal);
  Box get groupBox => Hive.box(AppConstants.boxGroup);
  Box get budgetsBox => Hive.box(AppConstants.boxBudgets);
  Box get profileBox => Hive.box(AppConstants.boxProfile);
  Box get settingsBox => Hive.box(AppConstants.boxSettings);

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BudgetAdapter());
    }
    await Hive.openBox(AppConstants.boxBudgets);
  }

  // Personal expenses helpers
  List<PersonalExpense> getPersonalExpenses() {
    return personalBox.values
        .whereType<Map>()
        .map((e) => PersonalExpense.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  double monthlyTotalByCategory(String category, int month, int year) {
    return getPersonalExpenses()
        .where((e) => e.category == category && e.date.month == month && e.date.year == year)
        .fold(0.0, (s, e) => s + e.amount);
  }

  double monthlyTotal(int month, int year) {
    return getPersonalExpenses()
        .where((e) => e.date.month == month && e.date.year == year)
        .fold(0.0, (s, e) => s + e.amount);
  }
}
