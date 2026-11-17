
import 'package:flutter/material.dart';
import 'core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await AppDatabase.instance.database;

  final stores = await db.rawQuery('SELECT COUNT(*) AS total FROM stores');
  final orders = await db.rawQuery('SELECT COUNT(*) AS total FROM orders');
  final shipments = await db.rawQuery('SELECT COUNT(*) AS total FROM shipments');

  debugPrint('Stores: ${stores.first['total']}');
  debugPrint('Orders: ${orders.first['total']}');
  debugPrint('Shipments: ${shipments.first['total']}');

  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('JobberSoft Database Initialized'),
        ),
      ),
    ),
  );
}
