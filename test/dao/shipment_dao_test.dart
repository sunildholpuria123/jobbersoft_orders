import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:jobbersoft_orders/core/database/database_change_notifier.dart';
import 'package:jobbersoft_orders/data/dao/shipment_dao.dart';

void main() {
  late Database database;
  late ShipmentDao dao;

  const shipmentDate = '2026-11-20';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('PRAGMA foreign_keys = ON');
    await _createSchema(database);
    await _insertFixture(database);
    dao = ShipmentDao(database, DatabaseChangeNotifier());
  });

  tearDown(() async {
    await database.close();
  });

  group('ShipmentDao availability queries', () {
    test(
      'returns only active trucks not already planned for the date',
      () async {
        final trucks = await dao.getAvailableTrucks(shipmentDate);

        expect(trucks, hasLength(1));
        expect(trucks.single['id'], 1);
        expect(trucks.single['plate_no'], 'TRUCK-001');
        expect(trucks.single['compartment_count'], 2);
        expect(trucks.single['total_capacity'], 15000);
      },
    );

    test(
      'returns drivers with valid licenses who are not already assigned',
      () async {
        final drivers = await dao.getAvailableDrivers(shipmentDate);

        expect(drivers, hasLength(1));
        expect(drivers.single['id'], 1);
        expect(drivers.single['name'], 'Available Driver');
      },
    );

    test(
      'returns submitted orders for the selected date with summed gallons',
      () async {
        final orders = await dao.getSubmittedOrdersForDate(shipmentDate);

        expect(orders, hasLength(2));
        expect(orders[0]['code'], 'O-1001');
        expect(orders[0]['store_name'], 'Central Store');
        expect(orders[0]['total_gallons'], 7000);
        expect(orders[1]['code'], 'O-1002');
        expect(orders[1]['total_gallons'], 3000);
      },
    );

    test('groups selected order gallons by product', () async {
      final totals = await dao.getSelectedProductTotals([1, 2]);

      expect(totals, hasLength(2));
      expect(totals[0]['product_code'], 'DIESEL');
      expect(totals[0]['total_gallons'], 6000);
      expect(totals[1]['product_code'], 'PETROL');
      expect(totals[1]['total_gallons'], 4000);
    });

    test('returns no product totals for an empty order selection', () async {
      expect(await dao.getSelectedProductTotals([]), isEmpty);
    });
  });

  group('ShipmentDao aggregate queries', () {
    test('aggregates shipment order count and total loaded gallons', () async {
      final shipments = await dao.getShipments(
        status: 'PLANNED',
        shipmentDate: shipmentDate,
      );

      expect(shipments, hasLength(1));
      final shipment = shipments.single;
      expect(shipment['code'], 'S-1001');
      expect(shipment['truck_plate'], 'TRUCK-002');
      expect(shipment['driver_name'], 'Busy Driver');
      expect(shipment['terminal_name'], 'North Terminal');
      expect(shipment['order_count'], 2);
      expect(shipment['total_gallons'], 9000);
      expect(shipment['rejected_order_codes'], '');
      expect(shipment['has_sync_conflict'], 0);
    });

    test('filters shipments by status and date', () async {
      final planned = await dao.getShipments(
        status: 'PLANNED',
        shipmentDate: shipmentDate,
      );
      final cancelled = await dao.getShipments(
        status: 'CANCELLED',
        shipmentDate: shipmentDate,
      );

      expect(planned.map((row) => row['code']), ['S-1001']);
      expect(cancelled.map((row) => row['code']), ['S-1002']);
    });

    test('returns compartments in position order', () async {
      final compartments = await dao.getTruckCompartments(1);

      expect(compartments, hasLength(2));
      expect(compartments.map((row) => row['position']), [1, 2]);
    });

    test('loads terminals alphabetically', () async {
      final terminals = await dao.getTerminals();

      expect(terminals.map((row) => row['name']), [
        'North Terminal',
        'South Terminal',
      ]);
    });

    test(
      'checks BOL uniqueness and can exclude the current shipment',
      () async {
        expect(await dao.isBolNumberAvailable('BOL-12345'), isFalse);
        expect(
          await dao.isBolNumberAvailable('BOL-12345', excludeShipmentId: 1),
          isTrue,
        );
        expect(await dao.isBolNumberAvailable('BOL-99999'), isTrue);
      },
    );
  });
}

Future<void> _createSchema(Database db) async {
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
      capacity_gal INTEGER NOT NULL,
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
      status TEXT NOT NULL,
      wizard_step INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      po_number TEXT NULL
    )
    ''',
    '''
    CREATE TABLE order_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL REFERENCES orders(id),
      tank_id INTEGER NOT NULL REFERENCES tanks(id),
      gallons INTEGER NOT NULL CHECK(gallons >= 0),
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
      status TEXT NOT NULL,
      wizard_step INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      bol_number TEXT NULL
    )
    ''',
    '''
    CREATE TABLE shipment_orders (
      shipment_id INTEGER NOT NULL REFERENCES shipments(id),
      order_id INTEGER NOT NULL REFERENCES orders(id),
      PRIMARY KEY(shipment_id, order_id)
    )
    ''',
    '''
    CREATE TABLE shipment_loads (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      shipment_id INTEGER NOT NULL REFERENCES shipments(id),
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
  ];

  for (final statement in statements) {
    await db.execute(statement);
  }
}

Future<void> _insertFixture(Database db) async {
  await db.insert('stores', {
    'id': 1,
    'name': 'Central Store',
    'address': 'Test Road',
    'delivery_open': '08:00',
    'delivery_close': '18:00',
  });

  await db.insert('products', {'id': 1, 'code': 'DIESEL', 'name': 'Diesel'});
  await db.insert('products', {'id': 2, 'code': 'PETROL', 'name': 'Petrol'});

  await db.insert('tanks', {
    'id': 1,
    'store_id': 1,
    'product_id': 1,
    'capacity_gal': 10000,
    'current_level_gal': 1000,
  });
  await db.insert('tanks', {
    'id': 2,
    'store_id': 1,
    'product_id': 2,
    'capacity_gal': 10000,
    'current_level_gal': 1000,
  });

  await db.insert('trucks', {'id': 1, 'plate_no': 'TRUCK-001', 'active': 1});
  await db.insert('trucks', {'id': 2, 'plate_no': 'TRUCK-002', 'active': 1});
  await db.insert('trucks', {'id': 3, 'plate_no': 'TRUCK-003', 'active': 0});

  await db.insert('compartments', {
    'id': 1,
    'truck_id': 1,
    'position': 1,
    'capacity_gal': 7000,
  });
  await db.insert('compartments', {
    'id': 2,
    'truck_id': 1,
    'position': 2,
    'capacity_gal': 8000,
  });
  await db.insert('compartments', {
    'id': 3,
    'truck_id': 2,
    'position': 1,
    'capacity_gal': 10000,
  });

  await db.insert('drivers', {
    'id': 1,
    'name': 'Available Driver',
    'license_expiry': '2027-12-31',
  });
  await db.insert('drivers', {
    'id': 2,
    'name': 'Busy Driver',
    'license_expiry': '2027-12-31',
  });
  await db.insert('drivers', {
    'id': 3,
    'name': 'Expired Driver',
    'license_expiry': '2026-11-19',
  });

  await db.insert('terminals', {'id': 1, 'name': 'North Terminal'});
  await db.insert('terminals', {'id': 2, 'name': 'South Terminal'});

  Future<void> addOrder({
    required int id,
    required String code,
    required String status,
    required String date,
    required int diesel,
    required int petrol,
  }) async {
    await db.insert('orders', {
      'id': id,
      'client_id': 'order-client-$id',
      'code': code,
      'store_id': 1,
      'shipment_date': date,
      'delivery_time': '10:00',
      'status': status,
      'created_at': '2026-11-18T00:00:00Z',
      'updated_at': '2026-11-18T00:00:00Z',
    });
    if (diesel > 0) {
      await db.insert('order_lines', {
        'order_id': id,
        'tank_id': 1,
        'gallons': diesel,
      });
    }
    if (petrol > 0) {
      await db.insert('order_lines', {
        'order_id': id,
        'tank_id': 2,
        'gallons': petrol,
      });
    }
  }

  await addOrder(
    id: 1,
    code: 'O-1001',
    status: 'SUBMITTED',
    date: '2026-11-20',
    diesel: 5000,
    petrol: 2000,
  );
  await addOrder(
    id: 2,
    code: 'O-1002',
    status: 'SUBMITTED',
    date: '2026-11-20',
    diesel: 1000,
    petrol: 2000,
  );
  await addOrder(
    id: 3,
    code: 'O-1003',
    status: 'DRAFT',
    date: '2026-11-20',
    diesel: 9000,
    petrol: 0,
  );
  await addOrder(
    id: 4,
    code: 'O-1004',
    status: 'SUBMITTED',
    date: '2026-11-21',
    diesel: 4000,
    petrol: 0,
  );

  await db.insert('shipments', {
    'id': 1,
    'client_id': 'shipment-client-1',
    'code': 'S-1001',
    'shipment_date': '2026-11-20',
    'truck_id': 2,
    'driver_id': 2,
    'terminal_id': 1,
    'status': 'PLANNED',
    'wizard_step': 4,
    'created_at': '2026-11-18T00:00:00Z',
    'updated_at': '2026-11-18T00:00:00Z',
    'bol_number': 'BOL-12345',
  });
  await db.insert('shipments', {
    'id': 2,
    'client_id': 'shipment-client-2',
    'code': 'S-1002',
    'shipment_date': '2026-11-20',
    'truck_id': 3,
    'driver_id': 3,
    'terminal_id': 2,
    'status': 'CANCELLED',
    'wizard_step': 4,
    'created_at': '2026-11-18T00:00:00Z',
    'updated_at': '2026-11-18T00:00:00Z',
    'bol_number': 'BOL-54321',
  });

  await db.insert('shipment_orders', {'shipment_id': 1, 'order_id': 1});
  await db.insert('shipment_orders', {'shipment_id': 1, 'order_id': 2});

  // Two loads total 9,000 gallons; the aggregate must not multiply rows
  // when shipment_orders is joined.
  await db.insert('shipment_loads', {
    'shipment_id': 1,
    'compartment_id': 3,
    'order_line_id': 1,
    'gallons': 5000,
  });
  await db.insert('shipment_loads', {
    'shipment_id': 1,
    'compartment_id': 3,
    'order_line_id': 2,
    'gallons': 4000,
  });
}
