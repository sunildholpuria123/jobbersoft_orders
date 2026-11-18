import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_change_notifier.dart';

import 'dart:convert';

import 'package:uuid/uuid.dart';

class ShipmentDao {
  final Database database;
  final DatabaseChangeNotifier changeNotifier;

  ShipmentDao(this.database, this.changeNotifier);

  Future<List<Map<String, Object?>>> getShipments({
    String? status,
    String? shipmentDate,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (status != null && status != 'ALL') {
      conditions.add('s.status = ?');
      args.add(status);
    }

    if (shipmentDate != null) {
      conditions.add('s.shipment_date = ?');
      args.add(shipmentDate);
    }

    final whereClause = conditions.isEmpty
        ? ''
        : 'WHERE ${conditions.join(' AND ')}';

    final result = await database.rawQuery('''
      SELECT
        s.id,
        s.code,
        s.shipment_date,
        s.status,
        s.bol_number,
        t.plate_no AS truck_plate,
        terminal.name AS terminal_name,
        d.name AS driver_name,
        COALESCE(order_totals.order_count, 0) AS order_count,
        COALESCE(load_totals.total_gallons, 0) AS total_gallons,
        COALESCE((
          SELECT GROUP_CONCAT(o.code, ', ')
          FROM shipment_orders so
          INNER JOIN orders o ON o.id = so.order_id
          WHERE so.shipment_id = s.id
            AND o.status = 'CANCELLED'
        ), '') AS rejected_order_codes,
        EXISTS (
          SELECT 1
          FROM outbox ob
          WHERE ob.entity_type = 'SHIPMENT'
            AND ob.entity_id = s.id
            AND ob.operation = 'PLAN'
            AND ob.status = 'CONFLICT'
        ) AS has_sync_conflict
      FROM shipments s
      LEFT JOIN trucks t ON t.id = s.truck_id
      LEFT JOIN drivers d ON d.id = s.driver_id
      LEFT JOIN terminals terminal ON terminal.id = s.terminal_id
      LEFT JOIN (
        SELECT
          shipment_id,
          COUNT(*) AS order_count
        FROM shipment_orders
        GROUP BY shipment_id
      ) order_totals ON order_totals.shipment_id = s.id
      LEFT JOIN (
        SELECT
          shipment_id,
          SUM(gallons) AS total_gallons
        FROM shipment_loads
        GROUP BY shipment_id
      ) load_totals ON load_totals.shipment_id = s.id
      $whereClause
      ORDER BY s.shipment_date DESC, s.id DESC
    ''', args);
    for (final shipment in result) {
      if (shipment['code'] == 'S-1007') {
        debugPrint('SHIPMENT CONFLICT DEBUG: $shipment');
      }
    }

    return result;
  }

  Future<List<Map<String, Object?>>> getSubmittedOrdersForDate(
    String shipmentDate,
  ) async {
    return database.rawQuery(
      '''
      SELECT
        o.id,
        o.code,
        o.shipment_date,
        s.name AS store_name,
        COALESCE(SUM(ol.gallons), 0) AS total_gallons
      FROM orders o
      INNER JOIN stores s ON s.id = o.store_id
      INNER JOIN order_lines ol ON ol.order_id = o.id
      WHERE o.status = 'SUBMITTED'
        AND o.shipment_date = ?
      GROUP BY o.id, o.code, o.shipment_date, s.name
      ORDER BY o.code
      ''',
      [shipmentDate],
    );
  }

  Future<List<Map<String, Object?>>> getSelectedProductTotals(
    List<int> orderIds,
  ) async {
    if (orderIds.isEmpty) return [];

    final placeholders = List.filled(orderIds.length, '?').join(',');

    return database.rawQuery('''
      SELECT
        p.id AS product_id,
        p.code AS product_code,
        p.name AS product_name,
        SUM(ol.gallons) AS total_gallons
      FROM order_lines ol
      INNER JOIN tanks t ON t.id = ol.tank_id
      INNER JOIN products p ON p.id = t.product_id
      WHERE ol.order_id IN ($placeholders)
      GROUP BY p.id, p.code, p.name
      ORDER BY p.code
      ''', orderIds);
  }

  Future<List<Map<String, Object?>>> getAvailableTrucks(
    String shipmentDate,
  ) async {
    return database.rawQuery(
      '''
    SELECT
      t.id,
      t.plate_no,
      COUNT(c.id) AS compartment_count,
      COALESCE(SUM(c.capacity_gal), 0) AS total_capacity
    FROM trucks t
    LEFT JOIN compartments c ON c.truck_id = t.id
    WHERE t.active = 1
      AND NOT EXISTS (
        SELECT 1
        FROM shipments s
        WHERE s.truck_id = t.id
          AND s.shipment_date = ?
          AND s.status = 'PLANNED'
      )
    GROUP BY t.id, t.plate_no
    ORDER BY t.plate_no
    ''',
      [shipmentDate],
    );
  }

  Future<List<Map<String, Object?>>> getAvailableDrivers(
    String shipmentDate,
  ) async {
    return database.rawQuery(
      '''
    SELECT
      d.id,
      d.name,
      d.license_expiry
    FROM drivers d
    WHERE d.license_expiry > ?
      AND NOT EXISTS (
        SELECT 1
        FROM shipments s
        WHERE s.driver_id = d.id
          AND s.shipment_date = ?
          AND s.status = 'PLANNED'
      )
    ORDER BY d.name
    ''',
      [shipmentDate, shipmentDate],
    );
  }

  Future<List<Map<String, Object?>>> getTruckCompartments(int truckId) async {
    return database.rawQuery(
      '''
      SELECT
        id,
        truck_id,
        position,
        capacity_gal
      FROM compartments
      WHERE truck_id = ?
      ORDER BY position
      ''',
      [truckId],
    );
  }

  Future<List<Map<String, Object?>>> getSelectedOrderLines(
    List<int> orderIds,
  ) async {
    if (orderIds.isEmpty) return [];

    final placeholders = List.filled(orderIds.length, '?').join(',');

    return database.rawQuery('''
      SELECT
        ol.id AS order_line_id,
        ol.order_id,
        o.code AS order_code,
        s.name AS store_name,
        t.product_id,
        p.code AS product_code,
        p.name AS product_name,
        ol.gallons AS requested_gallons
      FROM order_lines ol
      INNER JOIN orders o ON o.id = ol.order_id
      INNER JOIN stores s ON s.id = o.store_id
      INNER JOIN tanks t ON t.id = ol.tank_id
      INNER JOIN products p ON p.id = t.product_id
      WHERE ol.order_id IN ($placeholders)
        AND ol.gallons > 0
      ORDER BY p.code, o.code
      ''', orderIds);
  }

  // S-4: Load available terminals.
  Future<List<Map<String, Object?>>> getTerminals() async {
    return database.query(
      'terminals',
      columns: ['id', 'name'],
      orderBy: 'name ASC',
    );
  }

  // S-4: Check BOL uniqueness.
  // Exclude the current shipment when editing an existing shipment.
  Future<bool> isBolNumberAvailable(
    String bolNumber, {
    int? excludeShipmentId,
  }) async {
    final conditions = <String>['bol_number = ?'];
    final args = <Object?>[bolNumber];

    if (excludeShipmentId != null) {
      conditions.add('id != ?');
      args.add(excludeShipmentId);
    }

    final result = await database.query(
      'shipments',
      columns: ['id'],
      where: conditions.join(' AND '),
      whereArgs: args,
      limit: 1,
    );

    return result.isEmpty;
  }

  // S-5: Plan shipment atomically.
  Future<String> planShipment({
    required String shipmentDate,
    required int truckId,
    required int driverId,
    required int terminalId,
    required String bolNumber,
    required List<int> orderIds,
    required Map<int, Map<int, int>> allocations,
    bool failAfterLoads = false,
    required Map<int, String> partialLoadReasons,
  }) async {
    if (orderIds.isEmpty) {
      throw StateError('At least one order is required.');
    }

    final bol = bolNumber.trim().toUpperCase();
    if (!RegExp(r'^BOL-\d{5}$').hasMatch(bol)) {
      throw StateError('Invalid BOL number.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final clientId = const Uuid().v4();

    final shipmentCode = await database.transaction((txn) async {
      // Recheck BOL uniqueness inside the transaction.
      final duplicate = await txn.query(
        'shipments',
        columns: ['id'],
        where: 'bol_number = ?',
        whereArgs: [bol],
        limit: 1,
      );

      if (duplicate.isNotEmpty) {
        throw StateError('This BOL number already exists.');
      }

      // Verify selected orders are still SUBMITTED for this date.
      final placeholders = List.filled(orderIds.length, '?').join(',');

      final eligibleOrders = await txn.rawQuery(
        '''
        SELECT id
        FROM orders
        WHERE id IN ($placeholders)
          AND status = 'SUBMITTED'
          AND shipment_date = ?
        ''',
        [...orderIds, shipmentDate],
      );

      if (eligibleOrders.length != orderIds.toSet().length) {
        throw StateError(
          'One or more selected orders are no longer available.',
        );
      }

      // Verify truck and driver are still available.
      final truck = await txn.query(
        'trucks',
        columns: ['id'],
        where: 'id = ? AND active = 1',
        whereArgs: [truckId],
        limit: 1,
      );

      if (truck.isEmpty) {
        throw StateError('Selected truck is not active.');
      }

      final driver = await txn.query(
        'drivers',
        columns: ['id'],
        where: 'id = ? AND license_expiry > ?',
        whereArgs: [driverId, shipmentDate],
        limit: 1,
      );

      if (driver.isEmpty) {
        throw StateError('Selected driver license is expired.');
      }

      final truckBusy = await txn.query(
        'shipments',
        columns: ['id'],
        where: 'truck_id = ? AND shipment_date = ? AND status = ?',
        whereArgs: [truckId, shipmentDate, 'PLANNED'],
        limit: 1,
      );

      if (truckBusy.isNotEmpty) {
        throw StateError('Selected truck is already assigned.');
      }

      final driverBusy = await txn.query(
        'shipments',
        columns: ['id'],
        where: 'driver_id = ? AND shipment_date = ? AND status = ?',
        whereArgs: [driverId, shipmentDate, 'PLANNED'],
        limit: 1,
      );

      if (driverBusy.isNotEmpty) {
        throw StateError('Selected driver is already assigned.');
      }

      // Verify terminal exists.
      final terminal = await txn.query(
        'terminals',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [terminalId],
        limit: 1,
      );

      if (terminal.isEmpty) {
        throw StateError('Selected terminal does not exist.');
      }

      // Validate allocations against compartment and order-line data.

      // Validate allocations against all selected order lines.
      final orderPlaceholders = List.filled(
        orderIds.toSet().length,
        '?',
      ).join(',');

      final selectedLines = await txn.rawQuery('''
      SELECT
        ol.id,
        ol.order_id,
        ol.gallons,
        t.product_id
      FROM order_lines ol
      INNER JOIN tanks t ON t.id = ol.tank_id
      WHERE ol.order_id IN ($orderPlaceholders)
        AND ol.gallons > 0
      ''', orderIds.toSet().toList());

      final lineData = <int, Map<String, Object?>>{
        for (final row in selectedLines) (row['id'] as num).toInt(): row,
      };

      final compartmentIds = allocations.keys.toList();
      final compartmentData = <int, Map<String, Object?>>{};

      if (compartmentIds.isNotEmpty) {
        final placeholders = List.filled(compartmentIds.length, '?').join(',');

        final rows = await txn.rawQuery('''
        SELECT id, truck_id, capacity_gal
        FROM compartments
        WHERE id IN ($placeholders)
        ''', compartmentIds);

        for (final row in rows) {
          compartmentData[(row['id'] as num).toInt()] = row;
        }
      }

      final allocatedPerLine = <int, int>{};

      for (final entry in allocations.entries) {
        final compartmentId = entry.key;
        final compartment = compartmentData[compartmentId];

        if (compartment == null ||
            (compartment['truck_id'] as num).toInt() != truckId) {
          throw StateError('Invalid compartment for selected truck.');
        }

        final capacity = (compartment['capacity_gal'] as num).toInt();
        var compartmentTotal = 0;
        final productsInCompartment = <int>{};

        for (final allocation in entry.value.entries) {
          final gallons = allocation.value;

          if (gallons < 0) {
            throw StateError('Allocated gallons cannot be negative.');
          }
          if (gallons == 0) continue;

          final line = lineData[allocation.key];

          if (line == null) {
            throw StateError('Invalid order line allocation.');
          }

          final requested = (line['gallons'] as num).toInt();
          final productId = (line['product_id'] as num).toInt();

          final previous = allocatedPerLine[allocation.key] ?? 0;
          if (previous + gallons > requested) {
            throw StateError('Allocation exceeds requested gallons.');
          }

          allocatedPerLine[allocation.key] = previous + gallons;
          compartmentTotal += gallons;
          productsInCompartment.add(productId);
        }

        if (productsInCompartment.length > 1) {
          throw StateError('A compartment cannot contain multiple products.');
        }

        if (compartmentTotal > capacity) {
          throw StateError('Compartment capacity exceeded.');
        }
      }

      // Every selected order line must be fully allocated or have a reason.
      for (final entry in lineData.entries) {
        final lineId = entry.key;
        final requested = (entry.value['gallons'] as num).toInt();
        final allocated = allocatedPerLine[lineId] ?? 0;

        if (allocated > requested) {
          throw StateError('Allocation exceeds requested gallons.');
        }

        if (allocated < requested) {
          final reason = partialLoadReasons[lineId]?.trim() ?? '';

          if (reason.length < 5) {
            throw StateError(
              'A partial or zero allocation requires a reason of at least 5 characters.',
            );
          }
        }
      }

      // Create PLANNED shipment.
      final shipmentId = await txn.insert('shipments', {
        'client_id': clientId,
        'shipment_date': shipmentDate,
        'truck_id': truckId,
        'driver_id': driverId,
        'terminal_id': terminalId,
        'bol_number': bol,
        'status': 'PLANNED',
        'wizard_step': 4,
        'created_at': now,
        'updated_at': now,
      });

      final code = 'S-${1000 + shipmentId}';

      await txn.update(
        'shipments',
        {'code': code},
        where: 'id = ?',
        whereArgs: [shipmentId],
      );

      // Link selected orders.
      for (final orderId in orderIds.toSet()) {
        await txn.insert('shipment_orders', {
          'shipment_id': shipmentId,
          'order_id': orderId,
        });
      }

      // Insert positive compartment loads.
      for (final entry in allocations.entries) {
        for (final allocation in entry.value.entries) {
          if (allocation.value <= 0) continue;

          await txn.insert('shipment_loads', {
            'shipment_id': shipmentId,
            'compartment_id': entry.key,
            'order_line_id': allocation.key,
            'gallons': allocation.value,
          });
        }
      }

      // Debug rollback test.
      if (failAfterLoads) {
        throw StateError('Debug: forced shipment save failure.');
      }

      // Schedule all selected orders.
      for (final orderId in orderIds.toSet()) {
        final updated = await txn.update(
          'orders',
          {'status': 'SCHEDULED', 'updated_at': now},
          where: 'id = ? AND status = ?',
          whereArgs: [orderId, 'SUBMITTED'],
        );

        if (updated != 1) {
          throw StateError('Unable to schedule order $orderId.');
        }
      }

      // Add shipment to the outbox.
      final payload = {
        'client_id': clientId,
        'code': code,
        'shipment_date': shipmentDate,
        'truck_id': truckId,
        'driver_id': driverId,
        'terminal_id': terminalId,
        'bol_number': bol,
        'order_ids': orderIds.toSet().toList(),
        'allocations': allocations.map(
          (compartmentId, lines) => MapEntry(
            compartmentId.toString(),
            lines.map(
              (lineId, gallons) => MapEntry(lineId.toString(), gallons),
            ),
          ),
        ),
      };

      await txn.insert('outbox', {
        'client_id': clientId,
        'entity_type': 'SHIPMENT',
        'entity_id': shipmentId,
        'operation': 'PLAN',
        'payload_json': jsonEncode(payload),
        'status': 'PENDING',
        'attempts': 0,
        'created_at': now,
      });

      return code;
    });

    changeNotifier.notifyChanged();
    return shipmentCode;
  }

  // Cancel a planned shipment atomically.
  Future<void> cancelShipment(int shipmentId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final clientId = const Uuid().v4();

    await database.transaction((txn) async {
      // Verify that the shipment exists and is PLANNED.
      final shipments = await txn.query(
        'shipments',
        columns: ['id', 'code', 'client_id'],
        where: 'id = ? AND status = ?',
        whereArgs: [shipmentId, 'PLANNED'],
        limit: 1,
      );

      if (shipments.isEmpty) {
        throw StateError('Only planned shipments can be cancelled.');
      }

      final shipment = shipments.first;

      // Find all orders linked to this shipment.
      final linkedOrders = await txn.query(
        'shipment_orders',
        columns: ['order_id'],
        where: 'shipment_id = ?',
        whereArgs: [shipmentId],
      );

      // Mark shipment as CANCELLED.
      final updatedShipment = await txn.update(
        'shipments',
        {'status': 'CANCELLED', 'updated_at': now},
        where: 'id = ? AND status = ?',
        whereArgs: [shipmentId, 'PLANNED'],
      );

      if (updatedShipment != 1) {
        throw StateError('Unable to cancel shipment.');
      }

      // Restore all linked orders to SUBMITTED.

      // Restore only SCHEDULED orders.
      // Rejected orders must remain CANCELLED.
      for (final row in linkedOrders) {
        final orderId = (row['order_id'] as num).toInt();

        final order = await txn.query(
          'orders',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [orderId],
          limit: 1,
        );

        if (order.isEmpty) {
          throw StateError('Order $orderId does not exist.');
        }

        final orderStatus = order.first['status'];

        if (orderStatus == 'CANCELLED') {
          continue;
        }

        if (orderStatus != 'SCHEDULED') {
          throw StateError(
            'Cannot restore order $orderId with status $orderStatus.',
          );
        }

        await txn.update(
          'orders',
          {'status': 'SUBMITTED', 'updated_at': now},
          where: 'id = ? AND status = ?',
          whereArgs: [orderId, 'SCHEDULED'],
        );
      }

      // Record cancellation in the outbox.
      await txn.insert('outbox', {
        'client_id': clientId,
        'entity_type': 'SHIPMENT',
        'entity_id': shipmentId,
        'operation': 'CANCEL',
        'payload_json': jsonEncode({
          'client_id': shipment['client_id'],
          'shipment_id': shipmentId,
          'shipment_code': shipment['code'],
          'order_ids': linkedOrders.map((row) => row['order_id']).toList(),
        }),
        'status': 'PENDING',
        'attempts': 0,
        'created_at': now,
      });
    });

    changeNotifier.notifyChanged();
  }
}
