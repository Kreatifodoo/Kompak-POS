import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/painting.dart';

/// Read file bytes from local path (mobile implementation using dart:io)
Future<Uint8List?> readFileBytes(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
  } catch (_) {}
  return null;
}

/// Check if a file exists at path (mobile implementation)
bool fileExistsSync(String path) {
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}

/// Copy file from source to destination (mobile implementation)
Future<String?> copyFile(String sourcePath, String destPath) async {
  try {
    final file = File(sourcePath);
    final copied = await file.copy(destPath);
    return copied.path;
  } catch (_) {
    return null;
  }
}

/// Create directory recursively (mobile implementation)
Future<bool> createDirectory(String path) async {
  try {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Get a widget-safe image provider from a local file path.
/// Returns a FileImage on mobile.
dynamic getFileImageProvider(String path) {
  return FileImage(File(path));
}
