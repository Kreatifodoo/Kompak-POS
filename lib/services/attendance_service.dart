import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import 'telegram_service.dart';

class AttendanceService {
  final AppDatabase _db;
  final TelegramService _telegram;

  AttendanceService({
    required AppDatabase db,
    required TelegramService telegram,
  })  : _db = db,
        _telegram = telegram;

  /// Reverse geocode lat/long to a readable address string
  Future<String> reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // Build address from components, skip empty parts
        final parts = <String>[
          if (p.street != null && p.street!.isNotEmpty) p.street!,
          if (p.subLocality != null && p.subLocality!.isNotEmpty)
            p.subLocality!,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          if (p.subAdministrativeArea != null &&
              p.subAdministrativeArea!.isNotEmpty)
            p.subAdministrativeArea!,
          if (p.administrativeArea != null &&
              p.administrativeArea!.isNotEmpty)
            p.administrativeArea!,
          if (p.postalCode != null && p.postalCode!.isNotEmpty) p.postalCode!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // Geocoding failed (no internet, service unavailable, etc.)
    }
    return ''; // Return empty — UI will fall back to coordinates
  }

  /// Record attendance: save to DB, attempt Telegram send if online
  Future<Attendance> recordAttendance({
    required String type, // 'clock_in' | 'clock_out'
    required String userId,
    required String storeId,
    String? terminalId,
    required String photoPath,
    required Position position,
  }) async {
    // Validate timestamp against last attendance
    await _validateTimestamp(userId);

    final id = const Uuid().v4();
    final now = DateTime.now();

    // Reverse geocode to get address
    final address =
        await reverseGeocode(position.latitude, position.longitude);

    final companion = AttendancesCompanion.insert(
      id: id,
      userId: userId,
      storeId: storeId,
      terminalId: Value(terminalId),
      type: type,
      timestamp: now,
      latitude: position.latitude,
      longitude: position.longitude,
      isMockLocation: Value(position.isMocked),
      address: Value(address),
      photoPath: photoPath,
    );

    await _db.attendanceDao.insertAttendance(companion);

    // Try to send to Telegram immediately if online
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity.any((c) => c != ConnectivityResult.none);

    if (isOnline && _telegram.isEnabled) {
      try {
        final user = await _db.userDao.getUserById(userId);
        final store = await _db.storeDao.getStoreById(storeId);
        await _telegram.sendAttendancePhoto(
          photoPath: photoPath,
          cashierName: user?.name ?? 'Unknown',
          storeName: store?.name ?? 'Kompak Store',
          type: type,
          timestamp: now,
          latitude: position.latitude,
          longitude: position.longitude,
          isMockLocation: position.isMocked,
          address: address,
        );
        await _db.attendanceDao.markSent(id);
      } catch (_) {
        // Will be sent later during close register
      }
    }

    return (await _db.attendanceDao.getLastAttendance(userId))!;
  }

  /// Get GPS position with fake GPS detection
  Future<Position> getPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Layanan lokasi tidak aktif. Aktifkan GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Izin lokasi ditolak permanen. Aktifkan di pengaturan HP.');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Send all pending (unsent) attendance records to Telegram
  Future<int> sendPendingToTelegram() async {
    if (!_telegram.isEnabled) return 0;

    final unsent = await _db.attendanceDao.getUnsent();
    int sentCount = 0;

    for (final record in unsent) {
      try {
        final file = File(record.photoPath);
        if (!await file.exists()) {
          // Photo missing, mark as sent to avoid retry loop
          await _db.attendanceDao.markSent(record.id);
          continue;
        }

        final user = await _db.userDao.getUserById(record.userId);
        final store = await _db.storeDao.getStoreById(record.storeId);

        await _telegram.sendAttendancePhoto(
          photoPath: record.photoPath,
          cashierName: user?.name ?? 'Unknown',
          storeName: store?.name ?? 'Kompak Store',
          type: record.type,
          timestamp: record.timestamp,
          latitude: record.latitude,
          longitude: record.longitude,
          isMockLocation: record.isMockLocation,
          address: record.address,
        );

        await _db.attendanceDao.markSent(record.id);
        sentCount++;
      } catch (_) {
        // Skip this record, try again next time
        break;
      }
    }

    return sentCount;
  }

  /// Delete attendance records + photo files older than [days] days
  Future<int> cleanupOldAttendance({int days = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));

    // 1. Get old records to find photo paths
    final oldRecords = await _db.attendanceDao.getOlderThan(cutoff);

    // 2. Delete physical photo files
    for (final record in oldRecords) {
      try {
        final file = File(record.photoPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore file deletion errors
      }
    }

    // 3. Delete database records
    return await _db.attendanceDao.deleteOlderThan(cutoff);
  }

  /// Validate that the new timestamp is not before the last attendance
  Future<void> _validateTimestamp(String userId) async {
    final last = await _db.attendanceDao.getLastAttendance(userId);
    if (last != null) {
      final now = DateTime.now();
      if (now.isBefore(last.timestamp)) {
        throw Exception(
          'Waktu sistem tidak valid. Pastikan tanggal & jam HP sudah benar.',
        );
      }
    }
  }

  /// Determine the next attendance type based on today's records
  Future<String> getNextType(String userId, String storeId) async {
    final today = await _db.attendanceDao.getTodayAttendance(userId, storeId);
    if (today.isEmpty) return 'clock_in';
    final lastType = today.last.type;
    return lastType == 'clock_in' ? 'clock_out' : 'clock_in';
  }

  /// Get the attendance photo directory
  Future<Directory> getPhotoDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${appDir.path}/attendance_photos');
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }
    return photoDir;
  }
}
