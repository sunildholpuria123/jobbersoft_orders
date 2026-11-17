import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _uuid = Uuid();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final path = join(await getDatabasesPath(), 'jobbersoft_orders.db');

    final db = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createV1(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE orders ADD COLUMN po_number TEXT NULL');

          await db.execute(
            'ALTER TABLE shipments ADD COLUMN bol_number TEXT NULL',
          );

          await db.execute('''
        CREATE UNIQUE INDEX idx_shipments_bol_number
        ON shipments(bol_number)
      ''');
        }
      },
    );

    try {
      await _seedIfNeeded(db);
    } catch (_) {
      await db.close();
      rethrow;
    }

    _database = db;
    return db;
  }

  static Future<void> _createV1(Database db) async {
    final statements = <String>[
      '''
      CREATE TABLE stores (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        delivery_open TEXT NOT NULL,
        delivery_close TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE tanks (
        id INTEGER PRIMARY KEY,
        store_id INTEGER NOT NULL REFERENCES stores(id),
        product_id INTEGER NOT NULL REFERENCES products(id),
        capacity_gal INTEGER NOT NULL CHECK(capacity_gal >= 0),
        current_level_gal INTEGER NOT NULL
          CHECK(current_level_gal >= 0 AND current_level_gal <= capacity_gal)
      )
      ''',
      '''
      CREATE TABLE trucks (
        id INTEGER PRIMARY KEY,
        plate_no TEXT NOT NULL UNIQUE,
        active INTEGER NOT NULL CHECK(active IN (0, 1))
      )
      ''',
      '''
      CREATE TABLE compartments (
        id INTEGER PRIMARY KEY,
        truck_id INTEGER NOT NULL REFERENCES trucks(id),
        position INTEGER NOT NULL,
        capacity_gal INTEGER NOT NULL CHECK(capacity_gal > 0),
        UNIQUE(truck_id, position)
      )
      ''',
      '''
      CREATE TABLE drivers (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        license_expiry TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE terminals (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL UNIQUE,
        code TEXT UNIQUE,
        store_id INTEGER REFERENCES stores(id),
        shipment_date TEXT,
        delivery_time TEXT,
        status TEXT NOT NULL DEFAULT 'DRAFT'
          CHECK(status IN ('DRAFT', 'SUBMITTED', 'SCHEDULED', 'CANCELLED')),
        wizard_step INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE order_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
        tank_id INTEGER NOT NULL REFERENCES tanks(id),
        gallons INTEGER NOT NULL DEFAULT 0 CHECK(gallons >= 0),
        UNIQUE(order_id, tank_id)
      )
      ''',
      '''
      CREATE TABLE shipments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL UNIQUE,
        code TEXT UNIQUE,
        shipment_date TEXT NOT NULL,
        truck_id INTEGER REFERENCES trucks(id),
        driver_id INTEGER REFERENCES drivers(id),
        terminal_id INTEGER REFERENCES terminals(id),
        status TEXT NOT NULL DEFAULT 'DRAFT'
          CHECK(status IN ('DRAFT', 'PLANNED', 'CANCELLED')),
        wizard_step INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE shipment_orders (
        shipment_id INTEGER NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
        order_id INTEGER NOT NULL REFERENCES orders(id),
        PRIMARY KEY(shipment_id, order_id)
      )
      ''',
      '''
      CREATE TABLE shipment_loads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shipment_id INTEGER NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
        compartment_id INTEGER NOT NULL REFERENCES compartments(id),
        order_line_id INTEGER NOT NULL REFERENCES order_lines(id),
        gallons INTEGER NOT NULL CHECK(gallons > 0)
      )
      ''',
      '''
      CREATE TABLE outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE app_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
      ''',
      'CREATE INDEX idx_tanks_store ON tanks(store_id)',
      'CREATE INDEX idx_compartments_truck ON compartments(truck_id)',
      'CREATE INDEX idx_orders_date_status ON orders(shipment_date, status)',
      'CREATE INDEX idx_orders_store ON orders(store_id)',
      'CREATE INDEX idx_shipments_date_status ON shipments(shipment_date, status)',
      'CREATE INDEX idx_shipments_truck ON shipments(truck_id)',
      'CREATE INDEX idx_shipments_driver ON shipments(driver_id)',
      'CREATE INDEX idx_loads_shipment ON shipment_loads(shipment_id)',
      'CREATE INDEX idx_loads_line ON shipment_loads(order_line_id)',
      'CREATE INDEX idx_outbox_queue ON outbox(status, created_at, id)',
    ];

    for (final statement in statements) {
      await db.execute(statement);
    }
  }

  static String _dateWithOffset(DateTime base, int offset) {
    final date = DateTime(base.year, base.month, base.day + offset);
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static Future<void> _seedIfNeeded(Database db) async {
    final seedText = await rootBundle.loadString('assets/data/seed.json');
    final seed = jsonDecode(seedText) as Map<String, dynamic>;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'app_meta',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['seed_complete'],
        limit: 1,
      );

      if (existing.isNotEmpty) return;

      final today = DateTime.now();
      final now = DateTime.now().toUtc().toIso8601String();

      Future<void> insertItems(String table, List<dynamic> items) async {
        for (final item in items) {
          final row = Map<String, Object?>.from(item as Map);
          await txn.insert(table, row);
        }
      }

      await insertItems('products', seed['products'] as List);
      await insertItems('stores', seed['stores'] as List);
      await insertItems('tanks', seed['tanks'] as List);

      final trucks = seed['trucks'] as List;
      await insertItems(
        'trucks',
        trucks.map((item) {
          final row = Map<String, Object?>.from(item as Map);
          row['active'] = row['active'] == true ? 1 : 0;
          return row;
        }).toList(),
      );

      await insertItems('compartments', seed['compartments'] as List);

      for (final item in seed['drivers'] as List) {
        final row = Map<String, Object?>.from(item as Map);
        final offset = row.remove('license_expiry_offset_days') as int;
        row['license_expiry'] = _dateWithOffset(today, offset);
        await txn.insert('drivers', row);
      }

      await insertItems('terminals', seed['terminals'] as List);

      final demo = seed['demo_data'] as Map<String, dynamic>;
      final orderIds = <String, int>{};
      final orderLineIds = <String, int>{};

      for (final item in demo['orders'] as List) {
        final order = item as Map<String, dynamic>;
        final code = order['code'] as String;

        final orderId = await txn.insert('orders', {
          'client_id': _uuid.v4(),
          'code': code,
          'store_id': order['store_id'],
          'shipment_date': _dateWithOffset(
            today,
            order['shipment_date_offset_days'] as int,
          ),
          'delivery_time': order['delivery_time'],
          'status': order['status'],
          'wizard_step': 3,
          'created_at': now,
          'updated_at': now,
        });

        orderIds[code] = orderId;

        for (final line in order['lines'] as List) {
          final data = line as Map<String, dynamic>;
          final tankId = data['tank_id'] as int;

          final lineId = await txn.insert('order_lines', {
            'order_id': orderId,
            'tank_id': tankId,
            'gallons': data['gallons'],
          });

          orderLineIds['$code:$tankId'] = lineId;
        }
      }

      for (final item in demo['shipments'] as List) {
        final shipment = item as Map<String, dynamic>;

        final shipmentId = await txn.insert('shipments', {
          'client_id': _uuid.v4(),
          'code': shipment['code'],
          'shipment_date': _dateWithOffset(
            today,
            shipment['shipment_date_offset_days'] as int,
          ),
          'truck_id': shipment['truck_id'],
          'driver_id': shipment['driver_id'],
          'terminal_id': shipment['terminal_id'],
          'status': shipment['status'],
          'wizard_step': 4,
          'created_at': now,
          'updated_at': now,
        });

        final includedOrders = <int>{};

        for (final item in shipment['loads'] as List) {
          final load = item as Map<String, dynamic>;
          final orderCode = load['order_code'] as String;
          final tankId = load['tank_id'] as int;

          final orderId = orderIds[orderCode];
          final lineId = orderLineIds['$orderCode:$tankId'];

          if (orderId == null || lineId == null) {
            throw StateError('Invalid demo shipment load: $orderCode/$tankId');
          }

          includedOrders.add(orderId);

          await txn.insert('shipment_loads', {
            'shipment_id': shipmentId,
            'compartment_id': load['compartment_id'],
            'order_line_id': lineId,
            'gallons': load['gallons'],
          });
        }

        for (final orderId in includedOrders) {
          await txn.insert('shipment_orders', {
            'shipment_id': shipmentId,
            'order_id': orderId,
          });
        }
      }

      await txn.insert('app_meta', {'key': 'seed_complete', 'value': '1'});

      await txn.insert('app_meta', {
        'key': 'seeded_on',
        'value': _dateWithOffset(today, 0),
      });
    });
  }
}
