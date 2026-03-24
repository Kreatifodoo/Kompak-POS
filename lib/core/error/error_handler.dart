import 'app_exception.dart';

class ErrorHandler {
  ErrorHandler._();

  static String getUserMessage(Object error) {
    if (error is DatabaseException) {
      return 'Database error occurred. Please try again.';
    }
    if (error is NetworkException) {
      return 'Network error. Please check your connection.';
    }
    if (error is PrinterException) {
      return 'Printer error: ${error.message}';
    }
    if (error is SyncException) {
      return 'Sync failed. Data will be synced later.';
    }
    if (error is AuthException) {
      return error.message;
    }
    return 'An unexpected error occurred.';
  }
}
