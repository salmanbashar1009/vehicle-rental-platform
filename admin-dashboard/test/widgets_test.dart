import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velofleet_admin/core/theme/brand_theme.dart';
import 'package:velofleet_admin/core/widgets/desktop_shell.dart';
import 'package:velofleet_admin/core/widgets/feedback_views.dart';
import 'package:velofleet_admin/core/widgets/fleet_map_view.dart';
import 'package:velofleet_admin/core/widgets/status_badge.dart';

final _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class _MemoryTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(Uint8List.fromList(_transparentPng));
}

void main() {
  group('Admin Dashboard Desktop Widget & RBAC Gate Tests', () {
    testWidgets('DesktopShell hides Users & Roles for Dispatcher and shows it for Owner', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAdminTheme(),
          home: DesktopShell(
            selectedPath: '/dashboard',
            permissions: const {'dispatch.read', 'bookings.read'},
            roles: const {'dispatcher'},
            collapsed: false,
            onToggleCollapse: () {},
            onNavigate: (_) {},
            onLogout: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(find.text('Dispatch'), findsOneWidget);
      expect(find.text('Users & Roles'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAdminTheme(),
          home: DesktopShell(
            selectedPath: '/dashboard',
            permissions: const {},
            roles: const {'owner'},
            collapsed: false,
            onToggleCollapse: () {},
            onNavigate: (_) {},
            onLogout: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(find.text('Users & Roles'), findsOneWidget);
    });

    testWidgets('StatusBadge and EmptyStateView render cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAdminTheme(),
          home: Scaffold(
            body: Column(
              children: [
                const StatusBadge(status: 'confirmed'),
                EmptyStateView(
                  title: 'No bookings',
                  message: 'Reset filters',
                  actionLabel: 'Reset',
                  onAction: () {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('FleetMapView renders flutter_map with OSM attribution', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAdminTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: FleetMapView(tileProvider: _MemoryTileProvider()),
            ),
          ),
        ),
      );
      expect(find.byType(FleetMapView), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    });
  });
}
