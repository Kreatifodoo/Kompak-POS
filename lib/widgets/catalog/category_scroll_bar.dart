import 'package:flutter/material.dart';
import 'package:kompak_pos/core/database/app_database.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';
import 'package:kompak_pos/widgets/catalog/category_chip.dart';

class CategoryScrollBar extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;
  final bool showAllOption;

  const CategoryScrollBar({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    required this.onCategorySelected,
    this.showAllOption = true,
  });

  /// Maps Drift category iconName strings to Material Icons.
  static IconData _resolveIcon(String iconName) {
    const iconMap = <String, IconData>{
      'restaurant': Icons.restaurant,
      'local_cafe': Icons.local_cafe,
      'local_bar': Icons.local_bar,
      'local_pizza': Icons.local_pizza,
      'icecream': Icons.icecream,
      'cake': Icons.cake,
      'lunch_dining': Icons.lunch_dining,
      'ramen_dining': Icons.ramen_dining,
      'set_meal': Icons.set_meal,
      'fastfood': Icons.fastfood,
      'coffee': Icons.coffee,
      'emoji_food_beverage': Icons.emoji_food_beverage,
      'local_drink': Icons.local_drink,
      'bakery_dining': Icons.bakery_dining,
      'rice_bowl': Icons.rice_bowl,
      'breakfast_dining': Icons.breakfast_dining,
      'brunch_dining': Icons.brunch_dining,
      'dinner_dining': Icons.dinner_dining,
      'soup_kitchen': Icons.soup_kitchen,
      'kebab_dining': Icons.kebab_dining,
    };
    return iconMap[iconName] ?? Icons.restaurant;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: categories.length + (showAllOption ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          // "All" chip at position 0 when enabled
          if (showAllOption && index == 0) {
            return CategoryChip(
              icon: Icons.grid_view_rounded,
              label: 'All',
              isSelected: selectedCategoryId == null,
              onTap: () => onCategorySelected(null),
            );
          }

          final categoryIndex = showAllOption ? index - 1 : index;
          final category = categories[categoryIndex];

          return CategoryChip(
            icon: _resolveIcon(category.iconName),
            label: category.name,
            isSelected: selectedCategoryId == category.id,
            onTap: () => onCategorySelected(category.id),
          );
        },
      ),
    );
  }
}
