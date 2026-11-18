import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../../core/database/database_change_notifier.dart';

class OrderDao {
  final Database database;
  final DatabaseChangeNotifier changeNotifier;

  OrderDao(this.database, this.changeNotifier);

  static const _uuid = Uuid();

  Future<int> createDraft({required int storeId}) async {
    final now = DateTime.now().toIso8601String();

    final id = await database.insert('orders', {
      'client_id': _uuid.v4(),
      'store_id': storeId,
      'status': 'DRAFT',
      'wizard_step': 1,
      'created_at': now,
      'updated_at': now,
    });

    changeNotifier.notifyChanged();
    return id;
  }

  Future<void> saveStepOne({
    required int orderId,
    required int storeId,
    required String shipmentDate,
    required String deliveryTime,
    String? poNumber,
  }) async {
    await database.update(
      'orders',
      {
        'store_id': storeId,
        'shipment_date': shipmentDate,
        'delivery_time': deliveryTime,
        'po_number': poNumber,
        'wizard_step': 2,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND status = ?',
      whereArgs: [orderId, 'DRAFT'],
    );
    changeNotifier.notifyChanged();
  }

  Future<Map<String, Object?>?> getDraft(int orderId) async {
    final rows = await database.query(
      'orders',
      where: 'id = ? AND status = ?',
      whereArgs: [orderId, 'DRAFT'],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> getLatestDraft() async {
    final rows = await database.query(
      'orders',
      where: 'status = ?',
      whereArgs: ['DRAFT'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getOrders({
    String? status,
    String? shipmentDate,
    String? storeQuery,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (status != null && status != 'ALL') {
      conditions.add('o.status = ?');
      args.add(status);
    }

    if (shipmentDate != null) {
      conditions.add('o.shipment_date = ?');
      args.add(shipmentDate);
    }

    if (storeQuery != null && storeQuery.trim().isNotEmpty) {
      conditions.add('s.name LIKE ?');
      args.add('%${storeQuery.trim()}%');
    }

    final whereClause = conditions.isEmpty
        ? ''
        : 'WHERE ${conditions.join(' AND ')}';

    return database.rawQuery('''
    SELECT
      o.id,
      o.code,
      o.status,
      o.shipment_date,
      o.delivery_time,
      o.wizard_step,
      o.po_number,
      s.name AS store_name,
      s.address AS store_address,
      COALESCE(SUM(ol.gallons), 0) AS total_gallons
    FROM orders o
    LEFT JOIN stores s ON s.id = o.store_id
    LEFT JOIN order_lines ol ON ol.order_id = o.id
    $whereClause
    GROUP BY o.id
    ORDER BY o.created_at DESC
  ''', args);
  }

  Future<String> submitOrder(int orderId) async {
    final result = await database.transaction((txn) async  {
      final orders = await txn.query(
        'orders',
        where: 'id = ? AND status = ?',
        whereArgs: [orderId, 'DRAFT'],
        limit: 1,
      );

      if (orders.isEmpty) {
        throw Exception('Draft order not found or already submitted');
      }

      final order = orders.first;

      final lines = await txn.rawQuery(
        '''
      SELECT
        ol.tank_id,
        ol.gallons,
        p.code AS product_code
      FROM order_lines ol
      JOIN tanks t ON t.id = ol.tank_id
      JOIN products p ON p.id = t.product_id
      WHERE ol.order_id = ? AND ol.gallons > 0
      ''',
        [orderId],
      );

      if (lines.isEmpty) {
        throw Exception('Enter gallons for at least one tank');
      }

      final orderCode = 'O-${1000 + orderId}';
      final now = DateTime.now().toIso8601String();

      final updated = await txn.update(
        'orders',
        {'status': 'SUBMITTED', 'code': orderCode, 'updated_at': now},
        where: 'id = ? AND status = ?',
        whereArgs: [orderId, 'DRAFT'],
      );

      if (updated != 1) {
        throw Exception('Order submission failed');
      }

      final payload = {
        'clientId': order['client_id'],
        'storeId': order['store_id'],
        'shipmentDate': order['shipment_date'],
        'deliveryTime': order['delivery_time'],
        'poNumber': order['po_number'],
        'lines': lines
            .map(
              (line) => {
                'tankId': line['tank_id'],
                'productCode': line['product_code'],
                'gallons': line['gallons'],
              },
            )
            .toList(),
      };

      await txn.insert('outbox', {
        'client_id': order['client_id'],
        'entity_type': 'ORDER',
        'entity_id': orderId,
        'operation': 'SUBMIT',
        'payload_json': jsonEncode(payload),
        'status': 'PENDING',
        'attempts': 0,
        'created_at': now,
      });

      return orderCode;
    });

    changeNotifier.notifyChanged();
    return result;
  }
}
