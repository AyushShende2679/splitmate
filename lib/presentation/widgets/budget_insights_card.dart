import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency_helper.dart';
import '../../theme/app_theme.dart';
import '../providers/budget_provider.dart';

class BudgetInsightsCard extends ConsumerWidget {
  const BudgetInsightsCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);
    final notifier = ref.read(budgetsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);

    if (budgets.isEmpty) {
      return _buildBaseCard(
        isDark: isDark,
        onTap: onTap,
        icon: Icons.savings_outlined,
        iconColor: AppTheme.primary,
        title: 'Budget Insights',
        subtitle: 'Tap to set monthly limits',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: const Text('Set Budget', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
        ),
      );
    }

    final totalBudget = notifier.totalBudget;
    final totalSpent = notifier.totalSpent;
    final pct = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    Color progressColor = AppTheme.success;
    if (pct >= 1.0) {
      progressColor = AppTheme.danger;
    } else if (pct >= 0.8) {
      progressColor = AppTheme.warning;
    }

    final level = pct >= 1.0 ? 'Over budget!' : pct >= 0.8 ? 'Near limit' : 'On track';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 130),
        padding: const EdgeInsets.all(16),
        decoration: isDark
            ? AppTheme.glassDecoration(borderRadius: 16)
            : BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.savings_outlined, color: AppTheme.primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Budget Insights', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                    const SizedBox(height: 2),
                    Text('${formatCurrency(totalSpent)} / ${formatCurrency(totalBudget)} • $level', style: TextStyle(fontSize: 11, color: subColor)),
                  ]),
                ),
                Icon(Icons.chevron_right, color: subColor, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0), valueColor: AlwaysStoppedAnimation(progressColor))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${(pct * 100).toStringAsFixed(0)}% used', style: TextStyle(fontSize: 11, color: subColor)),
              Text('${formatCurrency((totalBudget - totalSpent).clamp(0, double.infinity))} left', style: TextStyle(fontSize: 11, color: progressColor, fontWeight: FontWeight.w600)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildBaseCard({required bool isDark, required VoidCallback onTap, required IconData icon, required Color iconColor, required String title, required String subtitle, Widget? trailing}) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 130),
        padding: const EdgeInsets.all(16),
        decoration: isDark
            ? AppTheme.glassDecoration(borderRadius: 16)
            : BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: subColor), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (trailing != null) ...[const SizedBox(height: 10), trailing],
          ],
        ),
      ),
    );
  }
}

class BudgetAlertBanner extends ConsumerWidget {
  const BudgetAlertBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);
    if (budgets.isEmpty) return const SizedBox.shrink();
    final notifier = ref.read(budgetsProvider.notifier);
    // find first exceeded or warning
    for (final b in budgets) {
      final spent = notifier.spentForCategory(b.category);
      final level = budgetAlertLevel(spent, b.limit);
      if (level > 0) {
        final isExceeded = level == 2;
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isExceeded ? AppTheme.danger.withValues(alpha: 0.12) : AppTheme.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isExceeded ? AppTheme.danger.withValues(alpha: 0.3) : AppTheme.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(isExceeded ? Icons.error_outline : Icons.warning_amber_outlined, color: isExceeded ? AppTheme.danger : AppTheme.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isExceeded ? '${b.category} over budget by ${formatCurrency(spent - b.limit)}' : '${b.category} ${((spent / b.limit) * 100).toStringAsFixed(0)}% of budget used',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isExceeded ? AppTheme.danger : AppTheme.warning),
                ),
              ),
            ],
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }
}
