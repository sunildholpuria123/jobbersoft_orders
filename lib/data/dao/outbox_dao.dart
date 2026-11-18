import 'dart:convert';

import 'package:sqflite/sqflite.dart';

class OutboxDao {
  OutboxDao(this._database);

  final Database _database;

  Future<List<Map<String, Object?>>> getPendingEvents() async {
    return _database.query(
      'outbox',
      where: "status IN ('PENDING', 'RETRY')",
      orderBy: 'created_at ASC, id ASC',
    );
  }

  Future<void> markSyncing(int id) async {
    await _database.update(
      'outbox',
      {'status': 'SYNCING'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSynced(int id) async {
    await _database.update(
      'outbox',
      {'status': 'SYNCED', 'last_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(
    int id, {
    required int attempts,
    required String error,
  }) async {
    await _database.update(
      'outbox',
      {'status': 'FAILED', 'attempts': attempts, 'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markRetry(
    int id, {
    required int attempts,
    required String error,
  }) async {
    await _database.update(
      'outbox',
      {'status': 'RETRY', 'attempts': attempts, 'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markConflict(int id, {required String error}) async {
    await _database.update(
      'outbox',
      {'status': 'CONFLICT', 'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Map<String, dynamic> decodePayload(String json) {
    return Map<String, dynamic>.from(jsonDecode(json) as Map);
  }

  Future<void> resetInterruptedEvents() async {
    await _database.update('outbox', {
      'status': 'RETRY',
      'last_error': 'Sync interrupted. Retrying.',
    }, where: "status = 'SYNCING'");
  }

  Future<Map<String, int>> getStatusCounts() async {
    final rows = await _database.rawQuery('''
    SELECT status, COUNT(*) AS total
    FROM outbox
    GROUP BY status
  ''');

    final counts = <String, int>{};
    for (final row in rows) {
      counts[row['status'] as String] = (row['total'] as num).toInt();
    }

    return {
      'pending': (counts['PENDING'] ?? 0) + (counts['RETRY'] ?? 0),
      'conflict': counts['CONFLICT'] ?? 0,
      'failed': counts['FAILED'] ?? 0,
      'syncing': counts['SYNCING'] ?? 0,
      'synced': counts['SYNCED'] ?? 0,
    };
  }

  Future<Map<String, dynamic>> buildShipmentPayload(int shipmentId) async {
    final shipments = await _database.query(
      'shipments',
      where: 'id = ?',
      whereArgs: [shipmentId],
      limit: 1,
    );

    if (shipments.isEmpty) {
      throw StateError('Shipment $shipmentId not found.');
    }

    final shipment = shipments.first;

    final loads = await _database.rawQuery(
      '''
    SELECT
      sl.compartment_id,
      o.client_id AS order_client_id,
      ol.tank_id,
      sl.gallons
    FROM shipment_loads sl
    INNER JOIN order_lines ol ON ol.id = sl.order_line_id
    INNER JOIN orders o ON o.id = ol.order_id
    WHERE sl.shipment_id = ?
    ORDER BY sl.id ASC
  ''',
      [shipmentId],
    );

    return {
      'clientId': shipment['client_id'],
      'shipmentDate': shipment['shipment_date'],
      'truckId': shipment['truck_id'],
      'driverId': shipment['driver_id'],
      'terminalId': shipment['terminal_id'],
      'bolNumber': shipment['bol_number'],
      'loads': loads
          .map(
            (load) => {
              'compartmentId': load['compartment_id'],
              'orderClientId': load['order_client_id'],
              'tankId': load['tank_id'],
              'gallons': load['gallons'],
            },
          )
          .toList(),
    };
  }

  Future<String?> getOrderOutboxStatus(String orderClientId) async {
    final rows = await _database.query(
      'outbox',
      columns: ['status'],
      where: '''
      entity_type = ? AND client_id = ? AND operation = ?
    ''',
      whereArgs: ['ORDER', orderClientId, 'SUBMIT'],
      orderBy: 'id DESC',
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first['status'] as String;
  }

  Future<void> markOrderCancelled(String orderClientId) async {
    await _database.update(
      'orders',
      {'status': 'CANCELLED', 'updated_at': DateTime.now().toIso8601String()},
      where: 'client_id = ?',
      whereArgs: [orderClientId],
    );
  }
}
