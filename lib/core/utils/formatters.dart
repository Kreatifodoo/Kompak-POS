import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _currencyFormat = NumberFormat('#,##0', 'id_ID');
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _timeFormat = DateFormat('HH:mm');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  static String currency(double amount, {String symbol = 'Rp'}) {
    return '$symbol ${_currencyFormat.format(amount)}';
  }

  static String currencyCompact(double amount) {
    return _currencyFormat.format(amount);
  }

  static String date(DateTime dt) => _dateFormat.format(dt);

  static String time(DateTime dt) => _timeFormat.format(dt);

  static String dateTime(DateTime dt) => _dateTimeFormat.format(dt);

  /// Generate order number with optional terminal code.
  /// e.g. "KP-T1-260324-0001" (with terminal) or "KP260324-0001" (without)
  static String orderNumber(String prefix, int sequence,
      {DateTime? date, String? terminalCode}) {
    final d = date ?? DateTime.now();
    final datePart =
        '${d.year.toString().substring(2)}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    if (terminalCode != null && terminalCode.isNotEmpty) {
      return '$prefix-$terminalCode-$datePart-${sequence.toString().padLeft(4, '0')}';
    }
    return '$prefix$datePart-${sequence.toString().padLeft(4, '0')}';
  }

  /// Extract the date prefix portion from an order number.
  /// e.g. "KP-T1-260324" (with terminal) or "KP260324" (without)
  static String orderDatePrefix(String prefix,
      {DateTime? date, String? terminalCode}) {
    final d = date ?? DateTime.now();
    final datePart =
        '${d.year.toString().substring(2)}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    if (terminalCode != null && terminalCode.isNotEmpty) {
      return '$prefix-$terminalCode-$datePart';
    }
    return '$prefix$datePart';
  }

  static String quantityDisplay(int qty) {
    return qty.toString().padLeft(2, '0');
  }
}
