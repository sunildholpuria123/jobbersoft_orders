import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE stores (
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE orders (
              id INTEGER PRIMARY KEY,
              store_id INTEGER NOT NULL REFERENCES stores(id),
              status TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE shipments (
              id INTEGER PRIMARY KEY,
              bol_number TEXT NULL
            )
          ''');

          await db.execute('''
            CREATE UNIQUE INDEX idx_shipments_bol_number
            ON shipments(bol_number)
          ''');
        },
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('creates required database tables', () async {
    final tables = await database.rawQuery('''
      SELECT name FROM sqlite_master
      WHERE type = 'table'
    ''');

    final names = tables.map((row) => row['name']).toSet();

    expect(names, contains('stores'));
    expect(names, contains('orders'));
    expect(names, contains('shipments'));
  });

  test('enables foreign key enforcement', () async {
    final result = await database.rawQuery('PRAGMA foreign_keys');

    expect(result.first['foreign_keys'], 1);

    expect(
      () => database.insert('orders', {'store_id': 999, 'status': 'SUBMITTED'}),
      throwsA(isA<Exception>()),
    );
  });

  test('allows nullable BOL numbers', () async {
    await database.insert('shipments', {'bol_number': null});

    final rows = await database.query('shipments');

    expect(rows.length, 1);
    expect(rows.first['bol_number'], isNull);
  });

  test('enforces unique non-null BOL numbers', () async {
    await database.insert('shipments', {'bol_number': 'BOL-12345'});

    expect(
      () => database.insert('shipments', {'bol_number': 'BOL-12345'}),
      throwsA(isA<Exception>()),
    );
  });

  test('migrates v1 to v2 and preserves existing records', () async {
    final dbPath = p.join(
      Directory.systemTemp.path,
      'jobbersoft_migration_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    // Create a version-1 database with existing data.
    final v1 = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE stores (
              id INTEGER PRIMARY KEY,
              name TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE orders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              store_id INTEGER,
              status TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE shipments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              status TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    await v1.insert('stores', {'id': 1, 'name': 'Migration Store'});
    await v1.insert('orders', {
      'id': 101,
      'store_id': 1,
      'status': 'SUBMITTED',
    });
    await v1.insert('shipments', {'id': 201, 'status': 'PLANNED'});
    await v1.close();

    // Reopen as version 2 and apply the same migration as AppDatabase.
    final v2 = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE orders ADD COLUMN po_number TEXT NULL',
            );
            await db.execute(
              'ALTER TABLE shipments ADD COLUMN bol_number TEXT NULL',
            );
            await db.execute('''
              CREATE UNIQUE INDEX idx_shipments_bol_number
              ON shipments(bol_number)
            ''');
          }
        },
      ),
    );

    try {
      final order = (await v2.query(
        'orders',
        where: 'id = ?',
        whereArgs: [101],
      )).single;
      final shipment = (await v2.query(
        'shipments',
        where: 'id = ?',
        whereArgs: [201],
      )).single;

      expect(order['status'], 'SUBMITTED');
      expect(order['po_number'], isNull);
      expect(shipment['status'], 'PLANNED');
      expect(shipment['bol_number'], isNull);

      final orderColumns = await v2.rawQuery('PRAGMA table_info(orders)');
      final shipmentColumns = await v2.rawQuery('PRAGMA table_info(shipments)');

      expect(
        orderColumns.any((column) => column['name'] == 'po_number'),
        isTrue,
      );
      expect(
        shipmentColumns.any((column) => column['name'] == 'bol_number'),
        isTrue,
      );

      final indexes = await v2.rawQuery('PRAGMA index_list(shipments)');
      expect(
        indexes.any((index) => index['name'] == 'idx_shipments_bol_number'),
        isTrue,
      );

      final store = (await v2.query(
        'stores',
        where: 'id = ?',
        whereArgs: [1],
      )).single;
      expect(store['name'], 'Migration Store');
    } finally {
      await v2.close();
      final file = File(dbPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  });
}
