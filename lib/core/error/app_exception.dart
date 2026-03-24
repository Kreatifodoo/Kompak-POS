abstract class AppException implements Exception {
  final String message;
  final dynamic originalError;

  const AppException(this.message, [this.originalError]);

  @override
  String toString() => '$runtimeType: $message';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.originalError]);
}

class NetworkException extends AppException {
  final int? statusCode;
  const NetworkException(super.message, [super.originalError, this.statusCode]);
}

class PrinterException extends AppException {
  const PrinterException(super.message, [super.originalError]);
}

class SyncException extends AppException {
  const SyncException(super.message, [super.originalError]);
}

class AuthException extends AppException {
  const AuthException(super.message, [super.originalError]);
}

class BarcodeException extends AppException {
  const BarcodeException(super.message, [super.originalError]);
}
