import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../models/session_report_model.dart';
import '../auth/auth_providers.dart';
import '../core_providers.dart';

/// Watches the active session for the current terminal (or store as fallback).
/// Multi-terminal: uses terminal-scoped session if currentTerminalId is set.
final activeSessionProvider = StreamProvider<PosSession?>((ref) {
  final service = ref.watch(posSessionServiceProvider);
  final terminalId = ref.watch(currentTerminalIdProvider);
  if (terminalId != null) {
    return service.watchActiveSessionForTerminal(terminalId);
  }
  // Fallback for standalone mode (no terminal assigned)
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return Stream.value(null);
  return service.watchActiveSession(storeId);
});

/// Current session ID (derived for easy access)
final activeSessionIdProvider = Provider<String?>((ref) {
  return ref.watch(activeSessionProvider).valueOrNull?.id;
});

/// Session report (fetched on demand)
final sessionReportProvider =
    FutureProvider.family<SessionReport, String>((ref, sessionId) async {
  final service = ref.read(posSessionServiceProvider);
  return service.generateReport(sessionId);
});

/// Session history list
final sessionHistoryProvider = FutureProvider<List<PosSession>>((ref) async {
  final service = ref.read(posSessionServiceProvider);
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  return service.getSessionHistory(storeId);
});
