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

  static String orderNumber(String prefix, int sequence, {DateTime? date}) {
    final d = date ?? DateTime.now();
    final datePart =
        '${d.year.toString().substring(2)}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    return '$prefix$datePart-${sequence.toString().padLeft(4, '0')}';
  }

  /// Extract the date prefix portion from an order number (e.g. "KP240323" from "KP240323-0001")
  static String orderDatePrefix(String prefix, {DateTime? date}) {
    final d = date ?? DateTime.now();
    final datePart =
        '${d.year.toString().substring(2)}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    return '$prefix$datePart';
  }

  static String quantityDisplay(int qty) {
    return qty.toString().padLeft(2, '0');
  }
}
