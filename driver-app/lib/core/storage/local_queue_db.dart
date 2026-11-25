import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:velofleet_driver/core/config/app_config.dart';

/// Offline queued milestone/completion action stored strictly FIFO.
class QueuedTripAction {
  const QueuedTripAction({
    this.id,
    required this.idempotencyKey,
    required this.assignmentId,
    required this.actionType,
    required this.payload,
    required this.occurredAtUtc,
    this.attempts = 0,
    required this.createdAtMs,
  });

  final int? id;
  final String idempotencyKey;
  final String assignmentId;
  final String actionType;
  final Map<String, dynamic> payload;
  final String occurredAtUtc;
  final int attempts;
  final int createdAtMs;
}

/// Offline buffered GPS breadcrumb awaiting batch transmission.
class QueuedGpsPoint {
  const QueuedGpsPoint({
    this.id,
    required this.assignmentId,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.speedMps,
    this.headingDeg,
    required this.recordedAtUtc,
    this.attempts = 0,
  });

  final int? id;
  final String assignmentId;
  final double lat;
  final double lng;
  final double? accuracyM;
  final double? speedMps;
  final double? headingDeg;
  final String recordedAtUtc;
  final int attempts;

  Map<String, dynamic> toApiJson() => {
    'lat': lat,
    'lng': lng,
    if (accuracyM != null) 'accuracy_m': accuracyM,
    if (speedMps != null) 'speed_mps': speedMps,
    if (headingDeg != null) 'heading_deg': headingDeg,
    'recorded_at': recordedAtUtc,
  };
}

/// Persistent SQLite offline queue for driver trip actions and GPS breadcrumbs.
class LocalQueueDb {
  LocalQueueDb(this._db);

  final Database _db;

  static Future<LocalQueueDb> open({String? dbPath, DatabaseFactory? factory}) async {
    final dbFactory = factory ?? databaseFactory;
    final resolved = dbPath ?? p.join(await dbFactory.getDatabasesPath(), 'velofleet_queue.db');
    final db = await dbFactory.openDatabase(
      resolved,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE pending_trip_actions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              idempotency_key TEXT UNIQUE NOT NULL,
              assignment_id TEXT NOT NULL,
              action_type TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              occurred_at_utc TEXT NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0,
              created_at_ms INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE pending_gps_points (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              assignment_id TEXT NOT NULL,
              lat REAL NOT NULL,
              lng REAL NOT NULL,
              accuracy_m REAL,
              speed_mps REAL,
              heading_deg REAL,
              recorded_at_utc TEXT NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );
    return LocalQueueDb(db);
  }

  Future<void> enqueueTripAction(QueuedTripAction action) async {
    await _db.insert('pending_trip_actions', {
      'idempotency_key': action.idempotencyKey,
      'assignment_id': action.assignmentId,
      'action_type': action.actionType,
      'payload_json': jsonEncode(action.payload),
      'occurred_at_utc': action.occurredAtUtc,
      'attempts': action.attempts,
      'created_at_ms': action.createdAtMs,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<QueuedTripAction>> pendingTripActions() async {
    final rows = await _db.query('pending_trip_actions', orderBy: 'created_at_ms ASC, id ASC');
    return rows
        .map(
          (r) => QueuedTripAction(
            id: r['id'] as int,
            idempotencyKey: r['idempotency_key'] as String,
            assignmentId: r['assignment_id'] as String,
            actionType: r['action_type'] as String,
            payload: jsonDecode(r['payload_json'] as String) as Map<String, dynamic>,
            occurredAtUtc: r['occurred_at_utc'] as String,
            attempts: r['attempts'] as int,
            createdAtMs: r['created_at_ms'] as int,
          ),
        )
        .toList();
  }

  Future<void> deleteTripAction(int id) async {
    await _db.delete('pending_trip_actions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> enqueueGpsPoint(QueuedGpsPoint point) async {
    await _db.insert('pending_gps_points', {
      'assignment_id': point.assignmentId,
      'lat': point.lat,
      'lng': point.lng,
      'accuracy_m': point.accuracyM,
      'speed_mps': point.speedMps,
      'heading_deg': point.headingDeg,
      'recorded_at_utc': point.recordedAtUtc,
      'attempts': point.attempts,
    });
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM pending_gps_points'),
    );
    if (count != null && count > AppConfig.maxBufferedGpsPoints) {
      final excess = count - AppConfig.maxBufferedGpsPoints;
      await _db.rawDelete(
        'DELETE FROM pending_gps_points WHERE id IN '
        '(SELECT id FROM pending_gps_points ORDER BY id ASC LIMIT ?)',
        [excess],
      );
    }
  }

  Future<List<QueuedGpsPoint>> peekGpsBatch({int limit = AppConfig.gpsMaxBatchSize}) async {
    final rows = await _db.query('pending_gps_points', orderBy: 'id ASC', limit: limit);
    return rows
        .map(
          (r) => QueuedGpsPoint(
            id: r['id'] as int,
            assignmentId: r['assignment_id'] as String,
            lat: (r['lat'] as num).toDouble(),
            lng: (r['lng'] as num).toDouble(),
            accuracyM: (r['accuracy_m'] as num?)?.toDouble(),
            speedMps: (r['speed_mps'] as num?)?.toDouble(),
            headingDeg: (r['heading_deg'] as num?)?.toDouble(),
            recordedAtUtc: r['recorded_at_utc'] as String,
            attempts: r['attempts'] as int,
          ),
        )
        .toList();
  }

  Future<void> deleteGpsPoints(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.delete('pending_gps_points', where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<int> bufferedGpsCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM pending_gps_points')) ?? 0;

  Future<void> close() => _db.close();
}
