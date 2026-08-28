import 'package:hive_flutter/hive_flutter.dart';
import '../../models/models.dart';

String getCurrencySymbol() {
  final box = Hive.box('user_profile');
  if (box.containsKey('profile')) {
    final p = UserProfile.fromMap(Map<String, dynamic>.from(box.get('profile')));
    return p.currency;
  }
  return '₹';
}

String formatCurrency(double amount, [String? symbol]) {
  final s = symbol ?? getCurrencySymbol();
  return '$s${amount.toStringAsFixed(0)}';
}
