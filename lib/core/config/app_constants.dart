// App-wide constants - single source of truth
class AppConstants {
  AppConstants._();

  // Hive boxes
  static const String boxPersonal = 'personal_expenses';
  static const String boxGroup = 'group_expenses';
  static const String boxInvitations = 'group_invitations';
  static const String boxProfile = 'user_profile';
  static const String boxSettings = 'settings';
  static const String boxNotification = 'notification_status';
  static const String boxBudgets = 'budgets';

  // Firestore collections (free tier - minimal reads)
  static const String colUsers = 'users';
  static const String colGroups = 'groups';
  static const String colGroupExpenses = 'group_expenses';
  static const String colInvitations = 'invitations';

  // Budget
  static const List<String> defaultCategories = [
    'Food', 'Transport', 'Shopping', 'Bills', 'Entertainment', 'Other'
  ];
}
