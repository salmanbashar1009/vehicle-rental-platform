import 'package:flutter/material.dart';

import 'package:velofleet_driver/app.dart';
import 'package:velofleet_driver/core/network/dio_client.dart';
import 'package:velofleet_driver/core/storage/local_queue_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = DriverDioClient(tokenStore: SecureTokenStore());
  final queueDb = await LocalQueueDb.open();
  runApp(DriverApp(client: client, queueDb: queueDb));
}
