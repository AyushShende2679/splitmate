import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_constants.dart';
import '../../core/utils/currency_helper.dart';
import '../../theme/app_theme.dart';
import '../providers/budget_provider.dart';

class BudgetDialog extends ConsumerStatefulWidget {
  const BudgetDialog({super.key});
  @override
  ConsumerState<BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends ConsumerState<BudgetDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    final budgets = ref.read(budgetsProvider);
    for (final c in AppConstants.defaultCategories) {
      final existing = budgets.where((b) => b.category == c).isEmpty ? null : budgets.firstWhere((b) => b.category == c);
      _controllers[c] = TextEditingController(text: existing != null && existing.limit > 0 ? existing.limit.toStringAsFixed(0) : '');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(budgetsProvider.notifier);
    for (final entry in _controllers.entries) {
      final txt = entry.value.text.trim();
      if (txt.isEmpty) {
        await notifier.deleteBudget(entry.key);
      } else {
        final val = double.tryParse(txt);
        if (val != null && val > 0) {
          await notifier.setBudget(entry.key, val);
        }
      }
    }
    if (mounted) Navigator.pop(context);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Budgets saved'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.watch(budgetsProvider);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Monthly Budgets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
              IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white : const Color(0xFF1E293B)), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: subColor(isDark)),
                const SizedBox(width: 6),
                Expanded(child: Text('Set 0 or empty to remove budget. Alerts at 80% and 100%.', style: TextStyle(fontSize: 12, color: subColor(isDark)))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: AppConstants.defaultCategories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final cat = AppConstants.defaultCategories[i];
                final spent = ref.read(budgetsProvider.notifier).spentForCategory(cat);
                final limit = double.tryParse(_controllers[cat]!.text.trim()) ?? 0;
                final level = budgetAlertLevel(spent, limit > 0 ? limit : 999999);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: level == 2 ? AppTheme.danger.withValues(alpha: 0.3) : level == 1 ? AppTheme.warning.withValues(alpha: 0.3) : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(cat, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                          const SizedBox(height: 2),
                          Text('Spent ${formatCurrency(spent)} this month', style: TextStyle(fontSize: 11, color: subColor(isDark))),
                          if (limit > 0) ...[
                            const SizedBox(height: 6),
                            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (spent / limit).clamp(0.0, 1.0), minHeight: 6, backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(level == 2 ? AppTheme.danger : level == 1 ? AppTheme.warning : AppTheme.success))),
                          ],
                        ]),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _controllers[cat]!,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            prefixText: getCurrencySymbol(),
                            hintText: 'Limit',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Save Budgets', style: TextStyle(fontWeight: FontWeight.bold))),
            ),
          ),
        ],
      ),
    );
  }

  Color subColor(bool isDark) => isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);
}
