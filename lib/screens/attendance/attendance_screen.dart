import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/core_providers.dart';
import '../../modules/attendance/attendance_providers.dart';
import '../../widgets/common/swipe_button.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  /// Optional user ID — bila diset, halaman ini akan beroperasi
  /// dalam mode multi-user (PIN sudah diverifikasi sebelumnya).
  /// Bila null, halaman fallback ke `currentUserProvider` (kasir login).
  final String? userId;

  const AttendanceScreen({super.key, this.userId});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

enum _AttendanceStep { idle, camera, confirm, submitting }

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with TickerProviderStateMixin {
  _AttendanceStep _step = _AttendanceStep.idle;
  CameraController? _cameraController;
  String? _capturedPhotoPath;
  String? _errorMessage;
  bool _isFrontCamera = true;

  // Active user yang sedang absen (mode multi-user).
  User? _activeUser;
  bool _loadingUser = false;

  // GPS & address data (fetched after photo capture)
  Position? _position;
  String _address = '';
  bool _isLoadingLocation = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _loadActiveUser();
  }

  /// Resolve user yang akan absen:
  /// - Jika `widget.userId` diset → ambil dari DB (mode multi-user/PIN)
  /// - Jika tidak → fallback ke `currentUserProvider`
  Future<void> _loadActiveUser() async {
    setState(() => _loadingUser = true);
    try {
      if (widget.userId != null) {
        final db = ref.read(databaseProvider);
        final user = await db.userDao.getUserById(widget.userId!);
        if (mounted) setState(() => _activeUser = user);
      } else {
        if (mounted) {
          setState(() => _activeUser = ref.read(currentUserProvider));
        }
      }
    } finally {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'Tidak ada kamera tersedia.');
        return;
      }

      // Prefer front camera for selfie
      final frontCameras = cameras
          .where((c) => c.lensDirection == CameraLensDirection.front)
          .toList();
      final selectedCamera =
          frontCameras.isNotEmpty ? frontCameras.first : cameras.first;
      _isFrontCamera =
          selectedCamera.lensDirection == CameraLensDirection.front;

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _errorMessage = 'Gagal membuka kamera: $e');
    }
  }

  Future<void> _onSwipeComplete() async {
    setState(() {
      _step = _AttendanceStep.camera;
      _errorMessage = null;
    });
    _slideController.forward();
    await _initCamera();
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final xFile = await _cameraController!.takePicture();

      // Move to app-specific directory
      final service = ref.read(attendanceServiceProvider);
      final photoDir = await service.getPhotoDirectory();
      final fileName =
          'attendance_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destPath = p.join(photoDir.path, fileName);
      await File(xFile.path).copy(destPath);
      // Delete temp file
      await File(xFile.path).delete().catchError((_) {});

      setState(() {
        _capturedPhotoPath = destPath;
        _step = _AttendanceStep.confirm;
        _isLoadingLocation = true;
      });

      // Dispose camera to free resources
      await _cameraController?.dispose();
      _cameraController = null;

      // Fetch GPS position + reverse geocode in background
      try {
        final service = ref.read(attendanceServiceProvider);
        final pos = await service.getPosition();
        final addr = await service.reverseGeocode(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() {
            _position = pos;
            _address = addr;
            _isLoadingLocation = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _errorMessage = e.toString().replaceFirst('Exception: ', '');
          });
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Gagal mengambil foto: $e');
    }
  }

  Future<void> _retakePhoto() async {
    // Delete the captured photo
    if (_capturedPhotoPath != null) {
      await File(_capturedPhotoPath!).delete().catchError((_) {});
    }
    setState(() {
      _capturedPhotoPath = null;
      _step = _AttendanceStep.camera;
    });
    await _initCamera();
  }

  Future<void> _confirmAttendance() async {
    if (_capturedPhotoPath == null || _position == null) return;

    setState(() {
      _step = _AttendanceStep.submitting;
      _errorMessage = null;
    });

    try {
      final service = ref.read(attendanceServiceProvider);
      // Mode multi-user: gunakan user yang dipilih lewat PIN dialog.
      // Fallback: kasir yang sedang login.
      final user = _activeUser ?? ref.read(currentUserProvider);
      final store = ref.read(currentStoreProvider);
      final terminal = ref.read(currentTerminalProvider);

      if (user == null || store == null) {
        throw Exception('User atau Store tidak ditemukan.');
      }

      final position = _position!;

      // Determine type
      final type = await service.getNextType(user.id, store.id);

      // Record attendance
      await service.recordAttendance(
        type: type,
        userId: user.id,
        storeId: store.id,
        terminalId: terminal?.id,
        photoPath: _capturedPhotoPath!,
        position: position,
      );

      // Refresh providers
      ref.invalidate(todayAttendanceProvider);
      ref.invalidate(nextAttendanceTypeProvider);
      if (widget.userId != null) {
        ref.invalidate(todayAttendanceForUserProvider(widget.userId!));
        ref.invalidate(nextAttendanceTypeForUserProvider(widget.userId!));
      }

      if (mounted) {
        final typeLabel = type == 'clock_in' ? 'Masuk' : 'Pulang';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Absensi $typeLabel berhasil dicatat!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        setState(() {
          _step = _AttendanceStep.idle;
          _capturedPhotoPath = null;
          _position = null;
          _address = '';
        });
        _slideController.reset();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _step = _AttendanceStep.confirm;
      });
    }
  }

  void _cancelFlow() {
    _cameraController?.dispose();
    _cameraController = null;
    if (_capturedPhotoPath != null) {
      File(_capturedPhotoPath!).delete().catchError((_) {});
    }
    setState(() {
      _step = _AttendanceStep.idle;
      _capturedPhotoPath = null;
      _errorMessage = null;
      _position = null;
      _address = '';
      _isLoadingLocation = false;
    });
    _slideController.reset();
  }

  @override
  Widget build(BuildContext context) {
    // Multi-user mode: ambil today + next-type spesifik untuk userId yang aktif.
    final activeUserId = _activeUser?.id;

    final todayAsync = activeUserId != null
        ? ref.watch(todayAttendanceForUserProvider(activeUserId))
        : ref.watch(todayAttendanceProvider);

    final nextTypeAsync = activeUserId != null
        ? ref.watch(nextAttendanceTypeForUserProvider(activeUserId))
        : ref.watch(nextAttendanceTypeProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Absensi', style: AppTextStyles.heading3),
            if (_activeUser != null)
              Text(
                _activeUser!.name,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Riwayat Absensi',
            onPressed: () => context.push('/attendance/history'),
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingUser
            ? const Center(child: CircularProgressIndicator())
            : _activeUser == null
                ? _buildNoUserState()
                : Column(
                    children: [
                      // Status card
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: _buildStatusCard(todayAsync),
                      ),

                      // Main content area
                      Expanded(
                        child: _step == _AttendanceStep.idle
                            ? _buildIdleView(nextTypeAsync)
                            : SlideTransition(
                                position: _slideAnimation,
                                child: _buildActiveFlow(),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildNoUserState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_person_rounded,
                size: 64, color: AppColors.textHint.withOpacity(0.4)),
            const SizedBox(height: AppSpacing.md),
            Text('User belum diverifikasi',
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Silakan kembali dan masukkan PIN untuk memulai absensi.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(AsyncValue<List<Attendance>> todayAsync) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fingerprint_rounded,
                    color: AppColors.primaryOrange, size: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status Hari Ini',
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(Formatters.date(DateTime.now()),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          todayAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return _statusChip('Belum Absen', AppColors.textHint,
                    Icons.remove_circle_outline);
              }
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: records.map((r) {
                  final isIn = r.type == 'clock_in';
                  return _statusChip(
                    '${isIn ? "Masuk" : "Pulang"} ${Formatters.time(r.timestamp)}',
                    isIn ? AppColors.successGreen : AppColors.warningAmber,
                    isIn
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => _statusChip(
                'Error', AppColors.errorRed, Icons.error_outline),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildIdleView(AsyncValue<String> nextTypeAsync) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_rounded,
            size: 80,
            color: AppColors.primaryOrange.withOpacity(0.3),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Geser untuk mulai absensi',
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          nextTypeAsync.when(
            data: (type) {
              final isClockIn = type == 'clock_in';
              return SwipeButton(
                label: isClockIn
                    ? 'Geser untuk Absen Masuk'
                    : 'Geser untuk Absen Pulang',
                icon: isClockIn
                    ? Icons.login_rounded
                    : Icons.logout_rounded,
                // GREEN untuk Clock IN, RED untuk Clock OUT
                color: isClockIn
                    ? AppColors.successGreen
                    : AppColors.errorRed,
                onSwiped: _onSwipeComplete,
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => SwipeButton(
              label: 'Geser untuk Absen',
              onSwiped: _onSwipeComplete,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_errorMessage!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.errorRed),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveFlow() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Camera / Photo preview
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: _step == _AttendanceStep.camera
                  ? _buildCameraPreview()
                  : _step == _AttendanceStep.confirm
                      ? _buildPhotoPreview()
                      : _buildSubmitting(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(_errorMessage!,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.errorRed),
                  textAlign: TextAlign.center),
            ),

          // Action buttons
          if (_step == _AttendanceStep.camera) _buildCameraActions(),
          if (_step == _AttendanceStep.confirm) _buildConfirmActions(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null ||
        !(_cameraController?.value.isInitialized ?? false)) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        // Overlay hint
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isFrontCamera
                    ? 'Posisikan wajah di tengah'
                    : 'Ambil foto',
                style: AppTextStyles.bodySmall
                    .copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPreview() {
    if (_capturedPhotoPath == null) {
      return const Center(child: Text('No photo'));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(_capturedPhotoPath!), fit: BoxFit.cover),
        // Location info overlay at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: _isLoadingLocation
                ? const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Text('Mengambil lokasi...',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_address.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _address,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (_position != null)
                        Row(
                          children: [
                            const Icon(Icons.explore_rounded,
                                color: Colors.white70, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                            if (_position!.isMocked) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('MOCK GPS',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                      if (_position == null && _errorMessage != null)
                        Text(
                          'GPS Error: $_errorMessage',
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 11),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitting() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: AppSpacing.md),
          Text('Menyimpan absensi...',
              style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildCameraActions() {
    return Row(
      children: [
        // Cancel
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _cancelFlow,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: AppColors.primaryOrange, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Batal',
                  style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Capture
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_cameraController?.value.isInitialized ?? false)
                  ? _capturePhoto
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                disabledBackgroundColor: AppColors.borderGrey,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt_rounded,
                      color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Ambil Foto', style: AppTextStyles.buttonText),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmActions() {
    return Row(
      children: [
        // Retake
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _retakePhoto,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: AppColors.primaryOrange, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Ulangi',
                  style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Confirm (disabled while GPS is loading)
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed:
                  (!_isLoadingLocation && _position != null) ? _confirmAttendance : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Konfirmasi', style: AppTextStyles.buttonText),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
