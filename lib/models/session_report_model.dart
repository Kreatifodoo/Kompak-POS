class SessionReport {
  final String sessionId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String cashierName;
  final Duration duration;

  final int totalOrders;
  final double totalSales;
  final double totalSubtotal;
  final double totalDiscounts;

  final PaymentMethodBreakdown cashBreakdown;
  final PaymentMethodBreakdown cardBreakdown;
  final PaymentMethodBreakdown qrisBreakdown;
  final PaymentMethodBreakdown transferBreakdown;

  final double openingCash;
  final double cashReceived;
  final double cashChangeGiven;
  final double expectedClosingCash;
  final double? actualClosingCash;
  final double? difference;

  const SessionReport({
    required this.sessionId,
    required this.openedAt,
    this.closedAt,
    required this.cashierName,
    required this.duration,
    required this.totalOrders,
    required this.totalSales,
    required this.totalSubtotal,
    required this.totalDiscounts,
    required this.cashBreakdown,
    required this.cardBreakdown,
    required this.qrisBreakdown,
    required this.transferBreakdown,
    required this.openingCash,
    required this.cashReceived,
    required this.cashChangeGiven,
    required this.expectedClosingCash,
    this.actualClosingCash,
    this.difference,
  });

  List<PaymentMethodBreakdown> get allBreakdowns =>
      [cashBreakdown, cardBreakdown, qrisBreakdown, transferBreakdown];

  List<PaymentMethodBreakdown> get activeBreakdowns =>
      allBreakdowns.where((b) => b.count > 0).toList();
}

class PaymentMethodBreakdown {
  final String method;
  final int count;
  final double totalAmount;
  final double totalChange;

  const PaymentMethodBreakdown({
    required this.method,
    required this.count,
    required this.totalAmount,
    this.totalChange = 0,
  });
}
