import 'package:sqflite/sqflite.dart';

import '../../core/database/database_change_notifier.dart';
import '../models/tank_model.dart';

class TankDao {
  final Database database;
  final DatabaseChangeNotifier changeNotifier;

  TankDao(this.database, this.changeNotifier);

  Future<List<TankModel>> getTanksByStore(int storeId) async {
    final result = await database.rawQuery(
      '''
      SELECT
        t.id,
        t.store_id,
        t.product_id,
        p.name AS product_name,
        p.code AS product_code,
        t.capacity_gal,
        t.current_level_gal
      FROM tanks t
      INNER JOIN products p ON p.id = t.product_id
      WHERE t.store_id = ?
      ORDER BY p.name, t.id
    ''',
      [storeId],
    );

    return result.map(TankModel.fromMap).toList();
  }

  Future<void> saveOrderLines({
    required int orderId,
    required Map<int, int> quantities,
  }) async {
    await database.transaction((txn) async {
      await txn.delete(
        'order_lines',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      for (final entry in quantities.entries) {
        if (entry.value <= 0) continue;

        await txn.insert('order_lines', {
          'order_id': orderId,
          'tank_id': entry.key,
          'gallons': entry.value,
        });
      }
    });
    changeNotifier.notifyChanged();
  }

  Future<void> updateWizardStep({
    required int orderId,
    required int step,
  }) async {
    await database.update(
      'orders',
      {
        'wizard_step': step,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND status = ?',
      whereArgs: [orderId, 'DRAFT'],
    );

    changeNotifier.notifyChanged();
  }

  Future<Map<int, int>> getOrderLines(int orderId) async {
    final rows = await database.query(
      'order_lines',
      columns: ['tank_id', 'gallons'],
      where: 'order_id = ?',
      whereArgs: [orderId],
    );

    return {
      for (final row in rows) row['tank_id'] as int: row['gallons'] as int,
    };
  }

  Future<List<Map<String, dynamic>>> getOrderLinesForReview(int orderId) async {
    return database.rawQuery(
      '''
    SELECT
      p.code AS product_code,
      p.name AS product_name,
      SUM(ol.gallons) AS total_gallons
    FROM order_lines ol
    JOIN tanks t ON t.id = ol.tank_id
    JOIN products p ON p.id = t.product_id
    WHERE ol.order_id = ?
    GROUP BY p.id, p.code, p.name
    ORDER BY p.code
  ''',
      [orderId],
    );
  }
}
