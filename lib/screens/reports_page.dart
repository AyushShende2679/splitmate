import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  
  String _currencySymbol = '₹';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

 void _loadCurrency() {
    final profileBox = Hive.box('user_profile');
    if (profileBox.containsKey('profile')) {
      final profile = UserProfile.fromMap(Map<String, dynamic>.from(profileBox.get('profile')));
      
      _currencySymbol = profile.currency;
    }
  }
  
  List<PersonalExpense> _getPersonalExpenses(Box box) {
    return box.values
        .whereType<Map>()
        .map((e) => PersonalExpense.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
  
  Map<String, double> _getCategoryTotals(List<PersonalExpense> expenses) {
    final Map<String, double> categoryTotals = {};
    for (final expense in expenses) {
      categoryTotals.update(expense.category, (value) => value + expense.amount, ifAbsent: () => expense.amount);
    }
    return categoryTotals;
  }
  
  Map<String, double> _getMonthlyTotals(List<PersonalExpense> expenses) {
    final Map<String, double> monthlyTotals = {};
    for (final expense in expenses) {
      final monthKey = DateFormat('MMM yyyy').format(expense.date);
      monthlyTotals.update(monthKey, (value) => value + expense.amount, ifAbsent: () => expense.amount);
    }
    return monthlyTotals;
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        Hive.box('personal_expenses').listenable(),
        Hive.box('user_profile').listenable(), 
      ]),
      builder: (context, _) {
        
        _loadCurrency();
        final personalBox = Hive.box('personal_expenses');
        final personalExpenses = _getPersonalExpenses(personalBox);
        
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: const Text('Reports'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.grey[800],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildCard(
                  title: 'Monthly Expenses',
                  child: SizedBox(
                    height: 200,
                    child: _buildMonthlyChart(personalExpenses),
                  ),
                ),
                const SizedBox(height: 24),
                _buildCard(
                  title: 'Category Breakdown',
                  child: SizedBox(
                    height: 200,
                    child: _buildCategoryChart(personalExpenses),
                  ),
                ),
                const SizedBox(height: 24),
                _buildCard(
                  title: 'Trends & Insights',
                  child: _buildTrendsList(personalExpenses),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
  
  Widget _buildMonthlyChart(List<PersonalExpense> expenses) {
    final monthlyTotals = _getMonthlyTotals(expenses);
    if (monthlyTotals.isEmpty) {
      return const Center(child: Text('No data for charts yet.'));
    }
    
    final months = monthlyTotals.keys.toList();
    final values = months.map((month) => monthlyTotals[month]!).toList();
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (values.reduce((a, b) => a > b ? a : b) * 1.2),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < months.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(months[index].split(' ').first, style: const TextStyle(fontSize: 10)),
                  );
                }
                return const Text('');
              },
              reservedSize: 22,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(months.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index],
                color: const Color(0xFF4A90E2),
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }
  
  Widget _buildCategoryChart(List<PersonalExpense> expenses) {
    final categoryTotals = _getCategoryTotals(expenses);
    if (categoryTotals.isEmpty) {
      return const Center(child: Text('No data for charts yet.'));
    }
    
    final total = categoryTotals.values.fold(0.0, (sum, value) => sum + value);
    
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: categoryTotals.entries.map((entry) {
          final percentage = total > 0 ? (entry.value / total) * 100 : 0;
          return PieChartSectionData(
            color: _getCategoryColor(entry.key),
            value: entry.value,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildTrendsList(List<PersonalExpense> expenses) {
    if (expenses.isEmpty) {
      return const Center(child: Text('Not enough data for trends.'));
    }
    
    expenses.sort((a, b) => b.date.compareTo(a.date));
    
    double totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);
    double highestSpending = expenses.fold(0.0, (max, e) => e.amount > max ? e.amount : max);
    final uniqueDays = expenses.map((e) => DateFormat('yyyy-MM-dd').format(e.date)).toSet().length;
    double averageDaily = uniqueDays > 0 ? totalSpent / uniqueDays : 0.0;
    
    return Column(
      children: [
        _buildTrendItem(
          'Highest Single Expense',
          
          '$_currencySymbol${highestSpending.toStringAsFixed(2)}',
   
          Icons.trending_up,
          Colors.red,
        ),
        const SizedBox(height: 12),
        _buildTrendItem(
          'Average Daily Spending',
          
          '$_currencySymbol${averageDaily.toStringAsFixed(2)}',
          
          Icons.show_chart,
          Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildTrendItem(
          'Most Frequent Category',
          _getMostFrequentCategory(expenses),
          Icons.category,
          Colors.green,
        ),
      ],
    );
  }
  
  Widget _buildTrendItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food': return const Color(0xFF4A90E2);
      case 'transport': return const Color(0xFF50E3C2);
      case 'shopping': return const Color(0xFFE5A23A);
      case 'bills': return const Color(0xFFE53E3E);
      case 'entertainment': return const Color(0xFF9C27B0);
      default: return const Color(0xFF607D8B);
    }
  }
  
  String _getMostFrequentCategory(List<PersonalExpense> expenses) {
    if (expenses.isEmpty) return 'None';
    final categoryCount = <String, int>{};
    for (final expense in expenses) {
      categoryCount.update(expense.category, (value) => value + 1, ifAbsent: () => 1);
    }
    
    return categoryCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}