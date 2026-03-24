import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/database/app_database.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';
import 'package:kompak_pos/models/enums.dart';

/// A section that renders dynamic extras selection for a product.
///
/// Each [ProductExtra] is rendered according to its [ExtraType]:
/// - [ExtraType.singleSelect] -- a row of choice chips (radio behaviour).
/// - [ExtraType.multiSelect]  -- a row of filter chips (checkbox behaviour).
/// - [ExtraType.counter]      -- a dropdown with numeric options.
///
/// The currently selected values are tracked externally via [selectedExtras]
/// (keyed by the extra's [ProductExtra.id]) and updates are propagated through
/// [onExtraChanged].
class ExtrasSection extends StatelessWidget {
  /// Available extras for the product, already sorted by [sortOrder].
  final List<ProductExtra> extras;

  /// Map from extra id to its current selection value.
  ///
  /// For single-select: a single `String` option label.
  /// For multi-select:  a `List<String>` of selected option labels.
  /// For counter:       an `int` value.
  final Map<String, dynamic> selectedExtras;

  /// Callback fired when a selection changes.
  /// Provides the extra id and the new value.
  final void Function(String extraId, dynamic value) onExtraChanged;

  const ExtrasSection({
    super.key,
    required this.extras,
    required this.selectedExtras,
    required this.onExtraChanged,
  });

  /// Parses the options JSON stored in the [ProductExtra] record.
  /// Expected format: `["Option A", "Option B", ...]` or
  /// `[{"label":"A","price":1000}, ...]`.
  List<String> _parseOptions(String optionsJson) {
    try {
      final decoded = jsonDecode(optionsJson);
      if (decoded is List) {
        return decoded.map<String>((e) {
          if (e is String) return e;
          if (e is Map && e.containsKey('label')) return e['label'] as String;
          return e.toString();
        }).toList();
      }
    } catch (_) {
      // Fallback to empty list on malformed JSON.
    }
    return [];
  }

  ExtraType _resolveType(String typeString) {
    switch (typeString) {
      case 'multi_select':
        return ExtraType.multiSelect;
      case 'counter':
        return ExtraType.counter;
      case 'single_select':
      default:
        return ExtraType.singleSelect;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (extras.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Customise',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...extras.map((extra) {
          final options = _parseOptions(extra.optionsJson);
          final type = _resolveType(extra.type);

          return Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Extra label with optional required indicator
                Row(
                  children: [
                    Text(
                      extra.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (extra.isRequired) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '*',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.errorRed,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildControl(extra, type, options),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildControl(
    ProductExtra extra,
    ExtraType type,
    List<String> options,
  ) {
    switch (type) {
      case ExtraType.singleSelect:
        return _buildSingleSelect(extra, options);
      case ExtraType.multiSelect:
        return _buildMultiSelect(extra, options);
      case ExtraType.counter:
        return _buildCounter(extra, options);
    }
  }

  Widget _buildSingleSelect(ProductExtra extra, List<String> options) {
    final selected = selectedExtras[extra.id] as String?;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.map((option) {
        final isChosen = selected == option;
        return ChoiceChip(
          label: Text(option),
          selected: isChosen,
          onSelected: (_) => onExtraChanged(extra.id, option),
          labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: isChosen ? FontWeight.w600 : FontWeight.w400,
            color: isChosen ? Colors.white : AppColors.textPrimary,
          ),
          selectedColor: AppColors.primaryOrange,
          backgroundColor: AppColors.surfaceGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isChosen ? AppColors.primaryOrange : AppColors.borderGrey,
            ),
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMultiSelect(ProductExtra extra, List<String> options) {
    final selectedList =
        (selectedExtras[extra.id] as List<String>?) ?? <String>[];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.map((option) {
        final isChosen = selectedList.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isChosen,
          onSelected: (selected) {
            final updated = List<String>.from(selectedList);
            if (selected) {
              updated.add(option);
            } else {
              updated.remove(option);
            }
            onExtraChanged(extra.id, updated);
          },
          labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: isChosen ? FontWeight.w600 : FontWeight.w400,
            color: isChosen ? Colors.white : AppColors.textPrimary,
          ),
          selectedColor: AppColors.primaryOrange,
          backgroundColor: AppColors.surfaceGrey,
          checkmarkColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isChosen ? AppColors.primaryOrange : AppColors.borderGrey,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCounter(ProductExtra extra, List<String> options) {
    // Options for a counter are treated as selectable numeric quantities.
    // Fallback to 0-5 range when options is empty.
    final items = options.isNotEmpty
        ? options
        : List.generate(6, (i) => i.toString());

    final currentValue = selectedExtras[extra.id]?.toString() ?? items.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(currentValue) ? currentValue : items.first,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          items: items
              .map((item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onExtraChanged(extra.id, value);
            }
          },
        ),
      ),
    );
  }
}
