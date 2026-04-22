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
  owner,
  admin,
  branchManager,
  cashier,
  kitchen;

  String get label {
    switch (this) {
      case owner:
        return 'Owner';
      case admin:
        return 'Admin';
      case branchManager:
        return 'Branch Manager';
      case cashier:
        return 'Cashier';
      case kitchen:
        return 'Kitchen';
    }
  }

  String get dbValue {
    switch (this) {
      case owner:
        return 'owner';
      case admin:
        return 'admin';
      case branchManager:
        return 'branch_manager';
      case cashier:
        return 'cashier';
      case kitchen:
        return 'kitchen';
    }
  }

  static UserRole fromDb(String value) =>
      UserRole.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => UserRole.cashier,
      );
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
      ChargeKategori.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ChargeKategori.pajak,
      );
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
      ChargeTipe.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ChargeTipe.nominal,
      );
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
      ChargeIncludeBase.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ChargeIncludeBase.subtotal,
      );
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
      PromotionTipeProgram.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => PromotionTipeProgram.otomatis,
      );
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
      PromotionTipeReward.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => PromotionTipeReward.diskonNominal,
      );
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
      PromotionApplyTo.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => PromotionApplyTo.order,
      );
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
