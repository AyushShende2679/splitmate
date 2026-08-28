import 'package:intl/intl.dart';

String formatRelative(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.isNegative || diff.inMinutes == 0) return 'Just now';
  if (diff.inDays == 0) {
    if (diff.inHours == 0) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(date);
}

String monthName(int month) => const [
  'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
][month - 1];
