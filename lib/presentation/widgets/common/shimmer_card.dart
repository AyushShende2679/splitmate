import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../theme/app_theme.dart';

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.height = 80});
  final double height;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
      highlightColor: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: isDark ? AppTheme.glassDecoration(borderRadius: 14) : BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        Icon(icon, size: 32, color: isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF94A3B8)),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8)), textAlign: TextAlign.center),
      ]),
    );
  }
}
