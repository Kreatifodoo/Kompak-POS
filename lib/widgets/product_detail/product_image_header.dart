import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';

/// A large product image with a dark gradient overlay at the bottom
/// and the product name rendered on top of the gradient.
///
/// When [imageUrl] is null or empty, a gradient placeholder with a
/// restaurant icon is shown instead.
class ProductImageHeader extends StatelessWidget {
  /// Network URL of the product image. When null a placeholder is rendered.
  final String? imageUrl;

  /// Product name displayed over the gradient overlay.
  final String productName;

  /// Height of the image area. Defaults to 280.
  final double height;

  const ProductImageHeader({
    super.key,
    required this.imageUrl,
    required this.productName,
    this.height = 280,
  });

  /// Generates a consistent gradient from the product name hash.
  List<Color> _placeholderGradient(String name) {
    final hash = name.hashCode;
    const gradients = [
      [Color(0xFFFF9A8B), Color(0xFFFF6A88)],
      [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
      [Color(0xFF84FAB0), Color(0xFF8FD3F4)],
      [Color(0xFFFCCB90), Color(0xFFD57EEB)],
      [Color(0xFF667EEA), Color(0xFF764BA2)],
      [Color(0xFFF6D365), Color(0xFFFDA085)],
      [Color(0xFFA1C4FD), Color(0xFFC2E9FB)],
      [Color(0xFFFA709A), Color(0xFFFEE140)],
    ];
    return gradients[hash.abs() % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final gradientColors = _placeholderGradient(productName);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image or placeholder
          if (hasImage)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _buildPlaceholder(gradientColors),
            )
          else
            _buildPlaceholder(gradientColors),

          // Dark gradient overlay from bottom
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color.fromARGB(180, 26, 26, 46), // darkBackground
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Product name over gradient
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Text(
              productName,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Back button safe area
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.sm,
            left: AppSpacing.sm,
            child: Material(
              color: const Color.fromARGB(100, 0, 0, 0),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          size: 64,
          color: Color.fromARGB(150, 255, 255, 255),
        ),
      ),
    );
  }
}
