/// Parses a user-entered dollar amount into integer cents.
///
/// Accepts `1234`, `1234.5`, `1,234.56`, optional leading `$`.
int parseDollarsToCents(String input) {
  var text = input.trim();
  if (text.isEmpty) {
    throw FormatException('Amount is required');
  }
  if (text.startsWith(r'$')) {
    text = text.substring(1).trim();
  }
  text = text.replaceAll(',', '');
  final negative = text.startsWith('-');
  if (negative) {
    text = text.substring(1).trim();
  }
  if (text.isEmpty || !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
    throw FormatException('Enter a valid amount (e.g. 1250.00)');
  }
  final parts = text.split('.');
  final dollars = int.parse(parts[0]);
  var cents = 0;
  if (parts.length == 2) {
    final frac = parts[1].padRight(2, '0');
    cents = int.parse(frac.substring(0, 2));
  }
  final total = dollars * 100 + cents;
  return negative ? -total : total;
}

String formatCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final dollars = abs ~/ 100;
  final rem = (abs % 100).toString().padLeft(2, '0');
  return '$sign\$$dollars.$rem';
}
