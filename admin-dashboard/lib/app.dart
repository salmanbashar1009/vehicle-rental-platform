import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_client.dart';
import '../../core/theme/brand_theme.dart';
import '../../core/widgets/desktop_shell.dart';
import '../../core/widgets/status_badge.dart';
import '../../features/auth/data/auth_repository_impl.dart';
import '../../features/auth/presentation/auth_bloc.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/bookings/data/booking_repository_impl.dart';
import '../../features/bookings/presentation/booking_bloc.dart';
import '../../features/bookings/presentation/bookings_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/dispatch/data/dispatch_repository_impl.dart';
import '../../features/dispatch/presentation/dispatch_bloc.dart';
import '../../features/dispatch/presentation/dispatch_page.dart';
import '../../features/drivers/presentation/drivers_page.dart';
import '../../features/finance/presentation/finance_cubit.dart';
import '../../features/finance/presentation/finance_page.dart';
import '../../features/fleet/data/fleet_repository_impl.dart';
import '../../features/fleet/presentation/fleet_bloc.dart';
import '../../features/fleet/presentation/vehicles_page.dart';
import '../../features/live_map/presentation/live_map_bloc.dart';
import '../../features/live_map/presentation/live_map_page.dart';
import '../../features/notifications/presentation/notifications_cubit.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/operations/presentation/maintenance_crm_page.dart';
import '../../features/operations/presentation/ops_cubit.dart';
import '../../features/operations/presentation/reports_reviews_page.dart';
import '../../features/users_roles/presentation/users_roles_page.dart';

/// Root VeloFleet Admin Desktop Application.
class VeloFleetAdminApp extends StatefulWidget {
  const VeloFleetAdminApp({super.key});

  @override
  State<VeloFleetAdminApp> createState() => _VeloFleetAdminAppState();
}

class _VeloFleetAdminAppState extends State<VeloFleetAdminApp> {
  late final TokenVault _vault = SecureTokenVault();
  late final ApiClient _api = ApiClient(vault: _vault);
  late final AuthBloc _authBloc = AuthBloc(AuthRepositoryImpl(api: _api, vault: _vault))
    ..add(const AuthRestoreRequested());
  bool _collapsed = false;

  late final GoRouter _router = GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final authState = _authBloc.state;
      final onLogin = state.matchedLocation == '/login';
      if (authState is AuthUnauthenticated && !onLogin) return '/login';
      if (authState is AuthAuthenticated && onLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) {
          final authState = context.watch<AuthBloc>().state;
          if (authState is AuthChecking) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (authState is! AuthAuthenticated) {
            return const LoginPage();
          }
          return DesktopShell(
            selectedPath: state.matchedLocation,
            permissions: authState.user.permissions,
            roles: authState.user.roles,
            collapsed: _collapsed,
            onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
            onNavigate: (path) => context.go(path),
            onLogout: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
            child: child,
          );
        },
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardPage()),
          GoRoute(path: '/live-map', builder: (_, _) => const LiveFleetMapPage()),
          GoRoute(path: '/notifications', builder: (_, _) => const NotificationsPage()),
          GoRoute(path: '/bookings', builder: (_, _) => const BookingsPage()),
          GoRoute(path: '/dispatch', builder: (_, _) => const DispatchPage()),
          GoRoute(path: '/finance', builder: (_, _) => const FinancePage()),
          GoRoute(path: '/vehicles', builder: (_, _) => const VehiclesPage()),
          GoRoute(path: '/maintenance', builder: (_, _) => const MaintenanceCrmPage()),
          GoRoute(path: '/reports', builder: (_, _) => const ReportsAndReviewsPage()),
          GoRoute(path: '/drivers', builder: (_, _) => const DriversPage()),
          GoRoute(path: '/users', builder: (_, _) => const UsersRolesPage()),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _authBloc.close();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(create: (_) => BookingBloc(AdminBookingRepositoryImpl(_api))),
        BlocProvider(create: (_) => FleetBloc(FleetRepositoryImpl(_api))),
        BlocProvider(create: (_) => DriverCubit(DriverRepositoryImpl(_api))),
        BlocProvider(create: (_) => DispatchBloc(DispatchRepositoryImpl(_api))),
        BlocProvider(create: (_) => UsersCubit(_api)),
        BlocProvider(create: (_) => NotificationsCubit(_api)),
        BlocProvider(create: (_) => LiveMapBloc(_api)),
        BlocProvider(create: (_) => FinanceCubit(_api)),
        BlocProvider(create: (_) => OpsCubit(_api)),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (_, _) => _router.refresh(),
        child: MaterialApp.router(
          title: 'VeloFleet Admin Dashboard',
          debugShowCheckedModeBanner: false,
          theme: buildAdminTheme(),
          routerConfig: _router,
        ),
      ),
    );
  }
}
