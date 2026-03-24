enum OrderStatus {
  draft,
  confirmed,
  preparing,
  ready,
  completed,
  cancelled,
  returned;

  String get label {
    switch (this) {
      case draft: return 'Draft';
      case confirmed: return 'Confirmed';
      case preparing: return 'Preparing';
      case ready: return 'Ready';
      case completed: return 'Completed';
      case cancelled: return 'Cancelled';
      case returned: return 'Returned';
    }
  }
}

enum PaymentMethod {
  cash,
  card,
  qris,
  transfer;

  String get label {
    switch (this) {
      case cash: return 'Cash';
      case card: return 'Card';
      case qris: return 'QRIS';
      case transfer: return 'Transfer';
    }
  }
}

enum DiscountType {
  percentage,
  fixed;
}

enum UserRole {
  admin,
  cashier,
  kitchen;
}

enum SyncStatus {
  pending,
  syncing,
  synced,
  failed;
}

enum ExtraType {
  singleSelect,
  multiSelect,
  counter;
}

enum ChargeKategori {
  pajak,
  layanan,
  potongan;

  String get label {
    switch (this) {
      case pajak:
        return 'Pajak';
      case layanan:
        return 'Layanan';
      case potongan:
        return 'Potongan';
    }
  }

  String get dbValue {
    switch (this) {
      case pajak:
        return 'PAJAK';
      case layanan:
        return 'LAYANAN';
      case potongan:
        return 'POTONGAN';
    }
  }

  static ChargeKategori fromDb(String value) =>
      ChargeKategori.values.firstWhere((e) => e.dbValue == value);
}

enum ChargeTipe {
  persentase,
  nominal;

  String get label {
    switch (this) {
      case persentase:
        return 'Persentase (%)';
      case nominal:
        return 'Nominal (Rp)';
    }
  }

  String get dbValue {
    switch (this) {
      case persentase:
        return 'PERSENTASE';
      case nominal:
        return 'NOMINAL';
    }
  }

  static ChargeTipe fromDb(String value) =>
      ChargeTipe.values.firstWhere((e) => e.dbValue == value);
}

enum ChargeIncludeBase {
  subtotal,
  afterPrevious;

  String get label {
    switch (this) {
      case subtotal:
        return 'Dari Subtotal';
      case afterPrevious:
        return 'Setelah Biaya Sebelumnya';
    }
  }

  String get dbValue {
    switch (this) {
      case subtotal:
        return 'SUBTOTAL';
      case afterPrevious:
        return 'AFTER_PREVIOUS';
    }
  }

  static ChargeIncludeBase fromDb(String value) =>
      ChargeIncludeBase.values.firstWhere((e) => e.dbValue == value);
}

enum PromotionTipeProgram {
  otomatis,
  kodeDiskon,
  beliXGratisY;

  String get label {
    switch (this) {
      case otomatis:
        return 'Promosi Otomatis';
      case kodeDiskon:
        return 'Kode Diskon';
      case beliXGratisY:
        return 'Beli X Gratis Y';
    }
  }

  String get dbValue {
    switch (this) {
      case otomatis:
        return 'OTOMATIS';
      case kodeDiskon:
        return 'KODE_DISKON';
      case beliXGratisY:
        return 'BELI_X_GRATIS_Y';
    }
  }

  static PromotionTipeProgram fromDb(String value) =>
      PromotionTipeProgram.values.firstWhere((e) => e.dbValue == value);
}

enum PromotionTipeReward {
  diskonPersentase,
  diskonNominal,
  produkGratis;

  String get label {
    switch (this) {
      case diskonPersentase:
        return 'Diskon Persentase (%)';
      case diskonNominal:
        return 'Diskon Nominal (Rp)';
      case produkGratis:
        return 'Produk Gratis';
    }
  }

  String get dbValue {
    switch (this) {
      case diskonPersentase:
        return 'DISKON_PERSENTASE';
      case diskonNominal:
        return 'DISKON_NOMINAL';
      case produkGratis:
        return 'PRODUK_GRATIS';
    }
  }

  static PromotionTipeReward fromDb(String value) =>
      PromotionTipeReward.values.firstWhere((e) => e.dbValue == value);
}

enum PromotionApplyTo {
  order,
  cheapest,
  specificProduct;

  String get label {
    switch (this) {
      case order:
        return 'Seluruh Order';
      case cheapest:
        return 'Produk Termurah';
      case specificProduct:
        return 'Produk Tertentu';
    }
  }

  String get dbValue {
    switch (this) {
      case order:
        return 'ORDER';
      case cheapest:
        return 'CHEAPEST';
      case specificProduct:
        return 'SPECIFIC_PRODUCT';
    }
  }

  static PromotionApplyTo fromDb(String value) =>
      PromotionApplyTo.values.firstWhere((e) => e.dbValue == value);
}

enum SessionStatus {
  open,
  closed;

  String get label {
    switch (this) {
      case open:
        return 'Open';
      case closed:
        return 'Closed';
    }
  }
}
