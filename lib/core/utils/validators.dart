class Validators {
  Validators._();

  static String? required(String? value, [String field = 'Field']) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }
    return null;
  }

  static String? price(String? value) {
    if (value == null || value.isEmpty) return 'Price is required';
    final parsed = double.tryParse(value);
    if (parsed == null || parsed < 0) return 'Invalid price';
    return null;
  }

  static String? quantity(String? value) {
    if (value == null || value.isEmpty) return 'Quantity is required';
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0) return 'Invalid quantity';
    return null;
  }

  static String? pin(String? value) {
    if (value == null || value.isEmpty) return 'PIN is required';
    if (value.length < 4 || value.length > 6) return 'PIN must be 4-6 digits';
    if (!RegExp(r'^\d+$').hasMatch(value)) return 'PIN must be numeric';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!regex.hasMatch(value)) return 'Invalid email format';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.length < 8) return 'Phone number too short';
    return null;
  }
}
