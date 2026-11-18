import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jobbersoft_orders/core/database/database_change_notifier.dart';
import 'package:jobbersoft_orders/data/dao/order_dao.dart';

void main() {
  late Database database;
  late OrderDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createSchema(database);
    dao = OrderDao(database, DatabaseChangeNotifier());
    await _insertFixtures(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('OrderDao draft operations', () {
    test('createDraft creates a DRAFT order at wizard step 1', () async {
      final id = await dao.createDraft(storeId: 1);
      final order = (await database.query(
        'orders',
        where: 'id = ?',
        whereArgs: [id],
      )).single;

      expect(order['store_id'], 1);
      expect(order['status'], 'DRAFT');
      expect(order['wizard_step'], 1);
      expect(order['client_id'], isNotEmpty);
      expect(order['created_at'], isNotNull);
      expect(order['updated_at'], isNotNull);
    });

    test(
      'saveStepOne stores delivery details and advances wizard step',
      () async {
        final id = await dao.createDraft(storeId: 1);

        await dao.saveStepOne(
          orderId: id,
          storeId: 2,
          shipmentDate: '2026-11-20',
          deliveryTime: '09:00-12:00',
          poNumber: 'PO-TEST-01',
        );

        final order = await dao.getDraft(id);
        expect(order, isNotNull);
        expect(order!['store_id'], 2);
        expect(order['shipment_date'], '2026-11-20');
        expect(order['delivery_time'], '09:00-12:00');
        expect(order['po_number'], 'PO-TEST-01');
        expect(order['wizard_step'], 2);
      },
    );

    test('saveStepOne permits a null PO number', () async {
      final id = await dao.createDraft(storeId: 1);
      await dao.saveStepOne(
        orderId: id,
        storeId: 1,
        shipmentDate: '2026-11-20',
        deliveryTime: '13:00-16:00',
      );

      final order = await dao.getDraft(id);
      expect(order!['po_number'], isNull);
    });

    test('getDraft returns null for missing or non-draft orders', () async {
      expect(await dao.getDraft(9999), isNull);

      await database.update(
        'orders',
        {'status': 'SUBMITTED'},
        where: 'id = ?',
        whereArgs: [1],
      );
      expect(await dao.getDraft(1), isNull);
    });

    test('getLatestDraft returns the most recently updated draft', () async {
      await database.update(
        'orders',
        {'updated_at': '2026-11-17T10:00:00'},
        where: 'id = ?',
        whereArgs: [1],
      );
      await database.update(
        'orders',
        {'updated_at': '2026-11-18T10:00:00'},
        where: 'id = ?',
        whereArgs: [2],
      );

      final latest = await dao.getLatestDraft();
      expect(latest!['id'], 2);
    });

    test('getLatestDraft returns null when there are no drafts', () async {
      await database.update('orders', {'status': 'SUBMITTED'});
      expect(await dao.getLatestDraft(), isNull);
    });
  });

  group('OrderDao list queries', () {
    test('getOrders returns store details and summed gallons', () async {
      final orders = await dao.getOrders();

      final order = orders.firstWhere((row) => row['id'] == 1);
      expect(order['store_name'], 'Alpha Fuel');
      expect(order['store_address'], 'Jaipur');
      expect(order['total_gallons'], 7000);
    });

    test('getOrders filters by status', () async {
      final orders = await dao.getOrders(status: 'SUBMITTED');
      expect(orders, hasLength(1));
      expect(orders.single['id'], 3);
    });

    test('getOrders filters by shipment date', () async {
      final orders = await dao.getOrders(shipmentDate: '2026-11-20');
      expect(orders, hasLength(2));
      expect(orders.map((row) => row['id']), containsAll([1, 3]));
    });

    test('getOrders filters by trimmed store name search', () async {
      final orders = await dao.getOrders(storeQuery: '  beta  ');
      expect(orders, hasLength(1));
      expect(orders.single['store_name'], 'Beta Fuel');
    });

    test('ALL status and blank store search do not filter results', () async {
      final all = await dao.getOrders(status: 'ALL', storeQuery: '   ');
      expect(all, hasLength(3));
    });
  });

  group('OrderDao submission transaction', () {
    test('submitOrder updates status and creates API outbox payload', () async {
      final code = await dao.submitOrder(1);

      expect(code, 'O-1001');

      final order = (await database.query(
        'orders',
        where: 'id = ?',
        whereArgs: [1],
      )).single;
      expect(order['status'], 'SUBMITTED');
      expect(order['code'], 'O-1001');

      final outbox = (await database.query(
        'outbox',
        where: 'entity_id = ?',
        whereArgs: [1],
      )).single;
      expect(outbox['client_id'], order['client_id']);
      expect(outbox['entity_type'], 'ORDER');
      expect(outbox['operation'], 'SUBMIT');
      expect(outbox['status'], 'PENDING');
      expect(outbox['attempts'], 0);

      final payload = jsonDecode(outbox['payload_json'] as String);
      expect(payload['clientId'], order['client_id']);
      expect(payload['storeId'], 1);
      expect(payload['shipmentDate'], '2026-11-20');
      expect(payload['deliveryTime'], '09:00-12:00');
      expect(payload['poNumber'], 'PO-1001');
      expect(payload['lines'], [
        {'tankId': 1, 'productCode': 'DIESEL', 'gallons': 5000},
        {'tankId': 2, 'productCode': 'PETROL', 'gallons': 2000},
      ]);
    });

    test('submission without positive tank gallons rolls back', () async {
      await database.delete(
        'order_lines',
        where: 'order_id = ?',
        whereArgs: [2],
      );

      await expectLater(dao.submitOrder(2), throwsA(isA<Exception>()));

      final order = (await database.query(
        'orders',
        where: 'id = ?',
        whereArgs: [2],
      )).single;
      expect(order['status'], 'DRAFT');
      expect(order['code'], isNull);

      final outboxRows = await database.rawQuery(
        'SELECT COUNT(*) AS count FROM outbox WHERE entity_id = 2',
      );
      final outboxCount = outboxRows.single['count'] as int;
      expect(outboxCount, 0);
    });

    test('already submitted order cannot be submitted again', () async {
      await expectLater(dao.submitOrder(3), throwsA(isA<Exception>()));

      final outboxRows = await database.rawQuery(
        'SELECT COUNT(*) AS count FROM outbox WHERE entity_id = 3',
      );
      final outboxCount = outboxRows.single['count'] as int;
      expect(outboxCount, 0);
    });
  });
}

Future<void> _createSchema(Database db) async {
  await db.execute('PRAGMA foreign_keys = ON');

  await db.execute('''
    CREATE TABLE stores (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      address TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY,
      code TEXT NOT NULL UNIQUE
    )
  ''');

  await db.execute('''
    CREATE TABLE tanks (
      id INTEGER PRIMARY KEY,
      product_id INTEGER NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''');

  await db.execute('''
    CREATE TABLE orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id TEXT NOT NULL UNIQUE,
      code TEXT,
      store_id INTEGER NOT NULL,
      status TEXT NOT NULL,
      shipment_date TEXT,
      delivery_time TEXT,
      po_number TEXT,
      wizard_step INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (store_id) REFERENCES stores(id)
    )
  ''');

  await db.execute('''
    CREATE TABLE order_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL,
      tank_id INTEGER NOT NULL,
      gallons INTEGER NOT NULL,
      FOREIGN KEY (order_id) REFERENCES orders(id),
      FOREIGN KEY (tank_id) REFERENCES tanks(id)
    )
  ''');

  await db.execute('''
    CREATE TABLE outbox (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id INTEGER NOT NULL,
      operation TEXT NOT NULL,
      payload_json TEXT NOT NULL,
      status TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
  ''');
}

Future<void> _insertFixtures(Database db) async {
  await db.insert('stores', {
    'id': 1,
    'name': 'Alpha Fuel',
    'address': 'Jaipur',
  });
  await db.insert('stores', {'id': 2, 'name': 'Beta Fuel', 'address': 'Ajmer'});

  await db.insert('products', {'id': 1, 'code': 'DIESEL'});
  await db.insert('products', {'id': 2, 'code': 'PETROL'});
  await db.insert('tanks', {'id': 1, 'product_id': 1});
  await db.insert('tanks', {'id': 2, 'product_id': 2});

  await db.insert('orders', {
    'id': 1,
    'client_id': 'client-order-1',
    'code': null,
    'store_id': 1,
    'status': 'DRAFT',
    'shipment_date': '2026-11-20',
    'delivery_time': '09:00-12:00',
    'po_number': 'PO-1001',
    'wizard_step': 2,
    'created_at': '2026-11-17T08:00:00',
    'updated_at': '2026-11-17T08:00:00',
  });
  await db.insert('orders', {
    'id': 2,
    'client_id': 'client-order-2',
    'code': null,
    'store_id': 2,
    'status': 'DRAFT',
    'shipment_date': '2026-11-21',
    'delivery_time': '13:00-16:00',
    'po_number': null,
    'wizard_step': 2,
    'created_at': '2026-11-17T09:00:00',
    'updated_at': '2026-11-17T09:00:00',
  });
  await db.insert('orders', {
    'id': 3,
    'client_id': 'client-order-3',
    'code': 'O-1003',
    'store_id': 1,
    'status': 'SUBMITTED',
    'shipment_date': '2026-11-20',
    'delivery_time': '09:00-12:00',
    'po_number': null,
    'wizard_step': 3,
    'created_at': '2026-11-17T07:00:00',
    'updated_at': '2026-11-17T07:00:00',
  });

  await db.insert('order_lines', {
    'id': 1,
    'order_id': 1,
    'tank_id': 1,
    'gallons': 5000,
  });
  await db.insert('order_lines', {
    'id': 2,
    'order_id': 1,
    'tank_id': 2,
    'gallons': 2000,
  });
  await db.insert('order_lines', {
    'id': 3,
    'order_id': 2,
    'tank_id': 1,
    'gallons': 0,
  });
  await db.insert('order_lines', {
    'id': 4,
    'order_id': 3,
    'tank_id': 1,
    'gallons': 3000,
  });
}
