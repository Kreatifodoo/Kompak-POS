import 'package:flutter/material.dart';
import '../utils/file_helper.dart' as file_helper;

/// Cross-platform image widget that handles local file paths and network URLs.
/// On mobile: uses Image.file for local paths (dart:io).
/// On web: shows placeholder for local paths (web can't access local filesystem).
class CrossPlatformImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const CrossPlatformImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final defaultError = errorBuilder ??
        (_, __, ___) => const Icon(Icons.image_not_supported_outlined,
            size: 32, color: Colors.grey);

    // Local file path
    if (imageUrl.startsWith('/')) {
      // Use file_helper which has conditional import (dart:io on mobile, stub on web)
      if (file_helper.fileExistsSync(imageUrl)) {
        final provider = file_helper.getFileImageProvider(imageUrl);
        if (provider != null && provider is ImageProvider) {
          return Image(
            image: provider,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: defaultError,
          );
        }
      }
      // File doesn't exist or on web — show placeholder
      return defaultError(context, 'File not available', null);
    }

    // Network URL
    return Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: defaultError,
    );
  }
}
