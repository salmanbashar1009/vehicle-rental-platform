import 'package:flutter/material.dart';

/// Reusable desktop sidebar navigation shell with collapsible rail.
class DesktopShell extends StatelessWidget {
  const DesktopShell({
    required this.selectedPath,
    required this.permissions,
    required this.roles,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onNavigate,
    required this.onLogout,
    required this.child,
    super.key,
  });

  final String selectedPath;
  final Set<String> permissions;
  final Set<String> roles;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  final Widget child;

  bool _canAccess(String? perm) =>
      perm == null || roles.contains('owner') || permissions.contains(perm);

  @override
  Widget build(BuildContext context) {
    final navItems = <(String, String, IconData, String?)>[
      ('/dashboard', 'Dashboard', Icons.dashboard_outlined, null),
      ('/live-map', 'Live Fleet Map', Icons.map_outlined, 'tracking.read'),
      ('/notifications', 'Alerts & Incidents', Icons.notifications_active_outlined, null),
      ('/bookings', 'Bookings', Icons.calendar_today_outlined, 'bookings.read'),
      ('/dispatch', 'Dispatch', Icons.alt_route_outlined, 'dispatch.read'),
      ('/finance', 'Finance', Icons.account_balance_wallet_outlined, 'finance.read'),
      ('/vehicles', 'Fleet', Icons.directions_car_outlined, 'fleet.read'),
      ('/maintenance', 'Maintenance & CRM', Icons.build_circle_outlined, 'fleet.read'),
      ('/reports', 'Reports & Reviews', Icons.insights_outlined, 'reports.read'),
      ('/drivers', 'Drivers', Icons.badge_outlined, 'drivers.read'),
      ('/users', 'Users & Roles', Icons.admin_panel_settings_outlined, 'users.read'),
    ].where((item) => _canAccess(item.$4)).toList();

    return Scaffold(
      body: Row(
        children: [
          Material(
            color: const Color(0xFF0F3D7A),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: collapsed ? 76 : 232,
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  child: Row(
                    mainAxisAlignment:
                        collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                    children: [
                      if (!collapsed) ...[
                        const Icon(Icons.local_taxi, color: Colors.white),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'VeloFleet Ops',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      IconButton(
                        onPressed: onToggleCollapse,
                        icon: Icon(
                          collapsed ? Icons.chevron_right : Icons.chevron_left,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final item in navItems)
                        ListTile(
                          selected: selectedPath.startsWith(item.$1),
                          selectedTileColor: Colors.white12,
                          leading: Icon(item.$3, color: Colors.white),
                          title: collapsed
                              ? null
                              : Text(item.$2, style: const TextStyle(color: Colors.white)),
                          onTap: () => onNavigate(item.$1),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white70),
                  title: collapsed
                      ? null
                      : const Text('Sign Out', style: TextStyle(color: Colors.white70)),
                  onTap: onLogout,
                ),
              ],
            ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
