import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/database/app_database.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';

class CategoryListScreen extends ConsumerStatefulWidget {
  const CategoryListScreen({super.key});

  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    setState(() => _isLoading = true);
    try {
      final service = ref.read(productServiceProvider);
      final cats = await service.getCategories(storeId);
      if (mounted) setState(() { _categories = cats; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showSnackBar('Failed to load categories', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Categories', style: AppTextStyles.heading3),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryOrange,
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) =>
                        _buildCategoryTile(_categories[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_rounded, size: 64, color: AppColors.textHint.withOpacity(0.4)),
          const SizedBox(height: AppSpacing.md),
          Text('No categories yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text('Tap + to add a category', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Category category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _deactivateCategory(category),
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: 'Delete',
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showCategoryDialog(category: category),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getIconData(category.iconName),
                      color: AppColors.primaryOrange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Sort order: ${category.sortOrder}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'cookie': return Icons.cookie_rounded;
      case 'restaurant': return Icons.restaurant_rounded;
      case 'local_cafe': return Icons.local_cafe_rounded;
      case 'eco': return Icons.eco_rounded;
      case 'fastfood': return Icons.fastfood_rounded;
      case 'icecream': return Icons.icecream_rounded;
      case 'cake': return Icons.cake_rounded;
      case 'local_bar': return Icons.local_bar_rounded;
      default: return Icons.category_rounded;
    }
  }

  Future<void> _showCategoryDialog({Category? category}) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final sortController = TextEditingController(text: (category?.sortOrder ?? 0).toString());
    String selectedIcon = category?.iconName ?? 'restaurant';
    final isEditing = category != null;

    final icons = ['restaurant', 'local_cafe', 'cookie', 'eco', 'fastfood', 'icecream', 'cake', 'local_bar'];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Category' : 'Add Category', style: AppTextStyles.heading3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Category Name *'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: sortController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sort Order'),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: icons.map((iconName) {
                  final isSelected = selectedIcon == iconName;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedIcon = iconName),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryOrange.withOpacity(0.2)
                            : AppColors.surfaceGrey,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: AppColors.primaryOrange, width: 2)
                            : null,
                      ),
                      child: Icon(
                        _getIconData(iconName),
                        color: isSelected ? AppColors.primaryOrange : AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) context.showSnackBar('Category name is required', isError: true);
      return;
    }

    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    final service = ref.read(productServiceProvider);
    final sortOrder = int.tryParse(sortController.text) ?? 0;

    try {
      if (isEditing) {
        await service.updateCategory(
          id: category.id,
          storeId: storeId,
          name: name,
          iconName: selectedIcon,
          sortOrder: sortOrder,
        );
        if (mounted) context.showSnackBar('Category updated');
      } else {
        await service.createCategory(
          storeId: storeId,
          name: name,
          iconName: selectedIcon,
          sortOrder: sortOrder,
        );
        if (mounted) context.showSnackBar('Category added');
      }
      _loadCategories();
    } catch (e) {
      if (mounted) context.showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _deactivateCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final service = ref.read(productServiceProvider);
      await service.deactivateCategory(category.id);
      if (mounted) context.showSnackBar('Category deleted');
      _loadCategories();
    } catch (e) {
      if (mounted) context.showSnackBar('Error: $e', isError: true);
    }
  }
}
