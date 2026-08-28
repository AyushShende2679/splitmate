class Validators {
  Validators._();
  static String? requiredField(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;
  static String? amount(String? v) {
    final d = double.tryParse((v ?? '').trim());
    if (d == null || d <= 0) return 'Enter a valid amount';
    return null;
  }
}
