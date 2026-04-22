/// Role-based access control utility.
/// Backed by database-driven permission cache (RBAC).
/// The static cache is populated on login/restore via [updateCache].
class Permissions {
  Permissions._();

  /// In-memory cache populated by permissionCacheProvider on login.
  /// Key: roleId, Value: set of permissionIds.
  static Map<String, Set<String>> _cache = {};

  /// Called after loading from DB to populate the static cache.
  static void updateCache(Map<String, Set<String>> cache) {
    _cache = cache;
  }

  /// Check if a role has a specific permission.
  /// Owner role always returns true (cannot be restricted).
  static bool _has(String role, String permissionId) {
    if (role == 'owner') return true;
    return _cache[role]?.contains(permissionId) ?? false;
  }

  // ── Public API (same signatures as before, now DB-backed) ──

  static bool canViewDashboard(String role) => _has(role, 'dashboard.view');
  static bool canViewReports(String role) => _has(role, 'reports.view');
  static bool canManageMasterData(String role) =>
      _has(role, 'master_data.manage');
  static bool canManageBranches(String role) => _has(role, 'branches.manage');
  static bool canManageUsers(String role) => _has(role, 'users.manage');
  static bool canAccessPOS(String role) => _has(role, 'pos.access');
  static bool canViewKitchen(String role) => _has(role, 'kitchen.view');
  static bool canViewInventory(String role) => _has(role, 'inventory.view');
  static bool canViewAllBranches(String role) =>
      _has(role, 'branches.view_all');
  static bool canViewSettings(String role) => _has(role, 'settings.view');

  /// Check any arbitrary permission ID (for granular checks).
  static bool hasPermission(String role, String permissionId) =>
      _has(role, permissionId);

  /// Default landing route per role after login.
  /// Uses permission checks to determine appropriate landing page.
  static String defaultRoute(String role) {
    if (_has(role, 'kitchen.view') &&
        !_has(role, 'dashboard.view') &&
        !_has(role, 'pos.access')) {
      return '/kitchen';
    }
    if (_has(role, 'pos.access') && !_has(role, 'dashboard.view')) {
      return '/pos/catalog';
    }
    if (_has(role, 'dashboard.view')) return '/dashboard';
    if (_has(role, 'pos.access')) return '/pos/catalog';
    if (_has(role, 'kitchen.view')) return '/kitchen';
    return '/auth';
  }
}
