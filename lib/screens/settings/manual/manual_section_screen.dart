import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import 'manual_data.dart';
import 'manual_illustrations.dart';

class ManualSectionScreen extends StatefulWidget {
  final String sectionId;
  const ManualSectionScreen({super.key, required this.sectionId});

  @override
  State<ManualSectionScreen> createState() => _ManualSectionScreenState();
}

class _ManualSectionScreenState extends State<ManualSectionScreen> {
  late final PageController _pageController;
  late final ManualSection _section;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _section = manualSections.firstWhere(
      (s) => s.id == widget.sectionId,
      orElse: () => manualSections.first,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = _section.steps;
    final color = _section.color;

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
        title: Text(
          _section.title,
          style: AppTextStyles.heading3.copyWith(color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          // ── Step Indicator ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(steps.length, (i) {
                final isActive = i == _currentPage;
                final isPast = i < _currentPage;
                return GestureDetector(
                  onTap: () => _goToPage(i),
                  child: Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? color
                          : isPast
                              ? color.withValues(alpha: 0.2)
                              : AppColors.borderGrey,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: AppTextStyles.caption.copyWith(
                        color: isActive
                            ? Colors.white
                            : isPast
                                ? color
                                : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),

          // ── PageView ──
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: steps.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) {
                final step = steps[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      // Illustration
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: ManualIllustration.build(step.illustration),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Step badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Langkah ${i + 1}',
                          style: AppTextStyles.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Title
                      Text(
                        step.title,
                        style: AppTextStyles.heading3,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Description
                      Text(
                        step.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Bottom Navigation ──
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.borderGrey),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Previous
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _goToPage(_currentPage - 1),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Sebelumnya'),
                      ),
                    )
                  else
                    const Spacer(),

                  const SizedBox(width: AppSpacing.md),

                  // Next / Done
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < steps.length - 1) {
                          _goToPage(_currentPage + 1);
                        } else {
                          context.pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage < steps.length - 1
                            ? 'Selanjutnya'
                            : 'Selesai',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
