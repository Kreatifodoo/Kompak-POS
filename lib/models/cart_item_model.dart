class CartItem {
  final String productId;
  final String productName;
  final double productPrice;
  final int quantity;
  final Map<String, dynamic> selectedExtras;
  final double lineTotal;
  final String? imageUrl;
  final String? description;
  final String? notes;
  final double? originalPrice; // base price before pricelist
  final double savings; // total savings = (originalPrice - pricelistPrice) * qty
  final bool isCombo;
  final List<ComboSelection> comboSelections; // selections per combo group

  const CartItem({
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    this.selectedExtras = const {},
    required this.lineTotal,
    this.imageUrl,
    this.description,
    this.notes,
    this.originalPrice,
    this.savings = 0,
    this.isCombo = false,
    this.comboSelections = const [],
  });

  /// Total extra price from combo selections
  double get comboExtrasTotal =>
      comboSelections.fold(0.0, (sum, s) => sum + s.extraPrice);

  CartItem copyWith({
    String? productId,
    String? productName,
    double? productPrice,
    int? quantity,
    Map<String, dynamic>? selectedExtras,
    double? lineTotal,
    String? imageUrl,
    String? description,
    String? notes,
    double? originalPrice,
    double? savings,
    bool? isCombo,
    List<ComboSelection>? comboSelections,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productPrice: productPrice ?? this.productPrice,
      quantity: quantity ?? this.quantity,
      selectedExtras: selectedExtras ?? this.selectedExtras,
      lineTotal: lineTotal ?? this.lineTotal,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      originalPrice: originalPrice ?? this.originalPrice,
      savings: savings ?? this.savings,
      isCombo: isCombo ?? this.isCombo,
      comboSelections: comboSelections ?? this.comboSelections,
    );
  }
}

/// Represents a customer's selection within one combo group
class ComboSelection {
  final String groupId;
  final String groupName;
  final String productId;
  final String productName;
  final double extraPrice;

  const ComboSelection({
    required this.groupId,
    required this.groupName,
    required this.productId,
    required this.productName,
    this.extraPrice = 0,
  });

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'groupName': groupName,
        'productId': productId,
        'productName': productName,
        'extraPrice': extraPrice,
      };

  factory ComboSelection.fromJson(Map<String, dynamic> json) {
    return ComboSelection(
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      extraPrice: (json['extraPrice'] as num?)?.toDouble() ?? 0,
    );
  }
}
