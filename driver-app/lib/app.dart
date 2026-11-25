import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import 'package:velofleet_driver/core/config/app_config.dart';
import 'package:velofleet_driver/core/network/dio_client.dart';
import 'package:velofleet_driver/core/storage/local_queue_db.dart';
import 'package:velofleet_driver/core/theme/brand_theme.dart';
import 'package:velofleet_driver/features/assignments/data/driver_operations_repository_impl.dart';
import 'package:velofleet_driver/features/assignments/domain/assignment_models.dart';
import 'package:velofleet_driver/features/assignments/presentation/assignments_bloc.dart';
import 'package:velofleet_driver/features/auth/data/auth_repository_impl.dart';
import 'package:velofleet_driver/features/auth/domain/auth_models.dart';
import 'package:velofleet_driver/features/auth/presentation/auth_bloc.dart';
import 'package:velofleet_driver/features/auth/presentation/login_page.dart';
import 'package:velofleet_driver/features/gps_tracking/presentation/gps_tracking_bloc.dart';
import 'package:velofleet_driver/features/home/presentation/driver_home_page.dart';

/// Root VeloFleet Chauffeur Flutter app with DI, BLoCs, GPS stream, and Light/Dark modes.
class DriverApp extends StatefulWidget {
  const DriverApp({
    super.key,
    required this.client,
    required this.queueDb,
    this.enableHardwareListeners = true,
  });

  final DriverDioClient client;
  final LocalQueueDb queueDb;
  final bool enableHardwareListeners;

  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> {
  bool _darkMode = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<Position>? _posSub;

  @override
  void dispose() {
    _connSub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  void _syncGpsStream(BuildContext context, GpsTrackingState gpsState) {
    if (!widget.enableHardwareListeners) return;
    if (!gpsState.isActive) {
      _posSub?.cancel();
      _posSub = null;
      return;
    }
    final gpsBloc = context.read<GpsTrackingBloc>();
    _posSub ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConfig.movingDistanceFilterM,
      ),
    ).listen(
      (pos) => gpsBloc.add(
        GpsSampleCaptured(
          lat: pos.latitude,
          lng: pos.longitude,
          accuracyM: pos.accuracy,
          speedMps: pos.speed,
          headingDeg: pos.heading,
        ),
      ),
      onError: (_) => gpsBloc.add(const GpsHealthChanged('GPS Interrupted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = DriverAuthRepositoryImpl(widget.client);
    final opsRepo = DriverOperationsRepositoryImpl(widget.client, widget.queueDb);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<DriverDioClient>.value(value: widget.client),
        RepositoryProvider<DriverAuthRepository>.value(value: authRepo),
        RepositoryProvider<DriverOperationsRepository>.value(value: opsRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => DriverAuthBloc(authRepo)..add(const DriverAuthStarted())),
          BlocProvider(create: (_) => AssignmentsBloc(opsRepo)),
          BlocProvider(create: (_) => GpsTrackingBloc(widget.client, widget.queueDb)),
        ],
        child: Builder(
          builder: (context) {
            if (widget.enableHardwareListeners && _connSub == null) {
              _connSub = Connectivity().onConnectivityChanged.listen((results) {
                final online = results.any((r) => r != ConnectivityResult.none);
                if (online && context.mounted) {
                  context.read<AssignmentsBloc>().add(const AssignmentsRefreshed());
                  context.read<GpsTrackingBloc>().add(const GpsBufferFlushRequested());
                }
              });
            }
            return MultiBlocListener(
              listeners: [
                BlocListener<AssignmentsBloc, AssignmentsState>(
                  listener: (context, aState) {
                    final active = aState.activeAssignment;
                    context.read<GpsTrackingBloc>().add(
                      GpsTripWindowEvaluated(
                        assignmentId: active?.assignmentId,
                        tripStatus: active?.trip?.status,
                      ),
                    );
                  },
                ),
                BlocListener<GpsTrackingBloc, GpsTrackingState>(
                  listener: _syncGpsStream,
                ),
              ],
              child: MaterialApp(
                title: 'VeloFleet Chauffeur',
                debugShowCheckedModeBanner: false,
                theme: DriverBrandTheme.light(),
                darkTheme: DriverBrandTheme.dark(),
                themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
                home: BlocBuilder<DriverAuthBloc, DriverAuthState>(
                  builder: (context, state) {
                    if (state is DriverAuthenticated) {
                      return DriverHomePage(
                        darkMode: _darkMode,
                        onToggleDarkMode: (v) => setState(() => _darkMode = v),
                      );
                    }
                    return const DriverLoginPage();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
