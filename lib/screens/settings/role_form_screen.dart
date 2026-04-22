import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/permissions.dart';
import '../../core/utils/extensions.dart';
import '../../core/database/app_database.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/rbac/rbac_providers.dart';

class RoleFormScreen extends ConsumerStatefulWidget {
  final String? roleId;
  const RoleFormScreen({super.key, this.roleId});

  @override
  ConsumerState<RoleFormScreen> createState() => _RoleFormScreenState();
}

class _RoleFormScreenState extends ConsumerState<RoleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Set<String> _selectedPermissions = {};
  bool _isLoading = false;
  bool _isInitialized = false;
  Role? _existingRole;

  bool get _isEditing => widget.roleId != null;
  bool get _isOwnerRole => widget.roleId == 'owner';
  bool get _isSystemRole => _existingRole?.isSystem ?? false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _initFromRole(Role role, List<RbacPermission> rolePerms) {
    if (_isInitialized) return;
    _isInitialized = true;
    _existingRole = role;
    _nameCtrl.text = role.name;
    _descCtrl.text = role.description ?? '';
    _selectedPermissions.addAll(rolePerms.map((p) => p.id));
  }

  @override
  Widget build(BuildContext context) {
    final allPermsAsync = ref.watch(allPermissionsProvider);

    // Load existing role data if editing
    if (_isEditing && !_isInitialized) {
      final rolePermsAsync =
          ref.watch(rolePermissionsProvider(widget.roleId!));
      final rolesAsync =
          ref.watch(availableRolesProvider(ref.watch(currentStoreIdProvider)));

      // Wait for both to load
      if (rolesAsync is AsyncLoading || rolePermsAsync is AsyncLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('...')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      final roles = rolesAsync.valueOrNull ?? [];
      final role = roles.where((r) => r.id == widget.roleId).firstOrNull;
      final rolePerms = rolePermsAsync.valueOrNull ?? [];

      if (role != null) {
        _initFromRole(role, rolePerms);
      }
    }

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
          _isEditing ? 'Edit Role' : 'Tambah Role',
          style: AppTextStyles.heading3,
        ),
        actions: [
          if (_isEditing && !_isSystemRole)
            IconButton(
              icon:
                  const Icon(Icons.delete_rounded, color: AppColors.errorRed),
              tooltip: 'Hapus Role',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: allPermsAsync.when(
        data: (allPerms) => _buildForm(allPerms),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildForm(List<RbacPermission> allPerms) {
    // Group permissions by module
    final grouped = <String, List<RbacPermission>>{};
    for (final perm in allPerms) {
      grouped.putIfAbsent(perm.module, () => []).add(perm);
    }
    final modules = grouped.keys.toList()..sort();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Role Name ──
                  TextFormField(
                    controller: _nameCtrl,
                    readOnly: _isSystemRole,
                    decoration: InputDecoration(
                      labelText: 'Nama Role *',
                      hintText: 'Contoh: Finance, Supervisor',
                      filled: true,
                      fillColor: _isSystemRole
                          ? AppColors.surfaceGrey
                          : Colors.white,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Description ──
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi',
                      hintText: 'Deskripsi singkat role ini',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Owner notice ──
                  if (_isOwnerRole)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      margin:
                          const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                AppColors.warningAmber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.warningAmber, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Owner memiliki semua permission dan tidak bisa di-restrict.',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.warningAmber),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Permissions Header ──
                  Row(
                    children: [
                      const Icon(Icons.security_rounded,
                          size: 20, color: AppColors.primaryOrange),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Permissions',
                          style: AppTextStyles.heading3
                              .copyWith(fontSize: 16)),
                      const Spacer(),
                      if (!_isOwnerRole)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedPermissions.length ==
                                  allPerms.length) {
                                _selectedPermissions.clear();
                              } else {
                                _selectedPermissions.addAll(
                                    allPerms.map((p) => p.id));
                              }
                            });
                          },
                          child: Text(
                            _selectedPermissions.length == allPerms.length
                                ? 'Hapus Semua'
                                : 'Pilih Semua',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primaryOrange),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Permission Modules ──
                  ...modules.map((module) {
                    final perms = grouped[module]!;
                    final allChecked = _isOwnerRole ||
                        perms.every(
                            (p) => _selectedPermissions.contains(p.id));
                    final someChecked = !allChecked &&
                        perms.any(
                            (p) => _selectedPermissions.contains(p.id));

                    return Container(
                      margin:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.borderGrey),
                      ),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Icon(
                            _moduleIcon(module),
                            size: 20,
                            color: _moduleColor(module),
                          ),
                          title: Row(
                            children: [
                              Text(
                                _moduleLabel(module),
                                style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: allChecked
                                      ? AppColors.successGreen
                                          .withOpacity(0.1)
                                      : someChecked
                                          ? AppColors.warningAmber
                                              .withOpacity(0.1)
                                          : AppColors.surfaceGrey,
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_isOwnerRole ? perms.length : perms.where((p) => _selectedPermissions.contains(p.id)).length}/${perms.length}',
                                  style:
                                      AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: allChecked
                                        ? AppColors.successGreen
                                        : someChecked
                                            ? AppColors.warningAmber
                                            : AppColors.textHint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          children: perms.map((perm) {
                            final isChecked = _isOwnerRole ||
                                _selectedPermissions.contains(perm.id);
                            return CheckboxListTile(
                              value: isChecked,
                              activeColor: AppColors.primaryOrange,
                              onChanged: _isOwnerRole
                                  ? null
                                  : (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedPermissions
                                              .add(perm.id);
                                        } else {
                                          _selectedPermissions
                                              .remove(perm.id);
                                        }
                                      });
                                    },
                              title: Text(perm.name,
                                  style: AppTextStyles.bodySmall.copyWith(
                                      fontWeight: FontWeight.w500)),
                              subtitle: perm.description != null
                                  ? Text(perm.description!,
                                      style: AppTextStyles.caption
                                          .copyWith(
                                              color:
                                                  AppColors.textHint))
                                  : null,
                              dense: true,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

        // ── Save Button ──
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        _isEditing ? 'Simpan Perubahan' : 'Buat Role',
                        style: AppTextStyles.buttonText,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(rbacServiceProvider);
      final storeId = ref.read(currentStoreIdProvider);

      if (_isEditing) {
        await service.updateRole(
          id: widget.roleId!,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          permissionIds: _selectedPermissions.toList(),
        );
      } else {
        await service.createCustomRole(
          name: _nameCtrl.text.trim(),
          storeId: storeId,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          permissionIds: _selectedPermissions.toList(),
        );
      }

      // Refresh permission cache globally
      ref.invalidate(permissionCacheProvider);
      ref.invalidate(availableRolesProvider(storeId));
      if (_isEditing) {
        ref.invalidate(rolePermissionsProvider(widget.roleId!));
      }
      final newCache = await ref.read(permissionCacheProvider.future);
      Permissions.updateCache(newCache);

      if (mounted) {
        context.showSnackBar(
            _isEditing ? 'Role berhasil diupdate' : 'Role berhasil dibuat');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Gagal menyimpan: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Role?'),
        content: Text(
          'User dengan role "${_nameCtrl.text}" akan otomatis dipindahkan ke role Cashier. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                final service = ref.read(rbacServiceProvider);
                await service.deleteRole(widget.roleId!);
                ref.invalidate(permissionCacheProvider);
                ref.invalidate(
                    availableRolesProvider(ref.read(currentStoreIdProvider)));
                final newCache =
                    await ref.read(permissionCacheProvider.future);
                Permissions.updateCache(newCache);
                if (mounted) {
                  context.showSnackBar('Role berhasil dihapus');
                  context.pop();
                }
              } catch (e) {
                if (mounted) {
                  context.showSnackBar('Gagal menghapus: $e',
                      isError: true);
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Hapus',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Module display helpers ──

  String _moduleLabel(String module) {
    const labels = {
      'dashboard': 'Dashboard',
      'reports': 'Laporan',
      'master_data': 'Master Data',
      'branches': 'Cabang',
      'users': 'Pengguna',
      'pos': 'POS / Kasir',
      'kitchen': 'Kitchen',
      'inventory': 'Inventory',
      'orders': 'Order',
      'settings': 'Settings',
    };
    return labels[module] ?? module;
  }

  IconData _moduleIcon(String module) {
    const icons = {
      'dashboard': Icons.dashboard_rounded,
      'reports': Icons.assessment_rounded,
      'master_data': Icons.inventory_2_rounded,
      'branches': Icons.store_rounded,
      'users': Icons.people_rounded,
      'pos': Icons.point_of_sale_rounded,
      'kitchen': Icons.restaurant_rounded,
      'inventory': Icons.warehouse_rounded,
      'orders': Icons.receipt_long_rounded,
      'settings': Icons.settings_rounded,
    };
    return icons[module] ?? Icons.extension_rounded;
  }

  Color _moduleColor(String module) {
    const colors = {
      'dashboard': AppColors.primaryOrange,
      'reports': AppColors.infoBlue,
      'master_data': AppColors.successGreen,
      'branches': Color(0xFF8B5CF6),
      'users': AppColors.warningAmber,
      'pos': AppColors.primaryOrange,
      'kitchen': Color(0xFFEC4899),
      'inventory': Color(0xFF6366F1),
      'orders': AppColors.infoBlue,
      'settings': AppColors.textSecondary,
    };
    return colors[module] ?? AppColors.textSecondary;
  }
}
