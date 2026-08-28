import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate_expense_tracker/presentation/providers/budget_provider.dart';

void main() {
  group('Budget Alert Level', () {
    test('ok when under 80%', () {
      expect(budgetAlertLevel(100, 1000), 0);
      expect(budgetAlertLevel(799, 1000), 0);
    });
    test('warning at 80%', () {
      expect(budgetAlertLevel(800, 1000), 1);
      expect(budgetAlertLevel(999, 1000), 1);
    });
    test('exceeded at 100%', () {
      expect(budgetAlertLevel(1000, 1000), 2);
      expect(budgetAlertLevel(1500, 1000), 2);
    });
    test('zero limit is ok', () {
      expect(budgetAlertLevel(100, 0), 0);
    });
  });
}
