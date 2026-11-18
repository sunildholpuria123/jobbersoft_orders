import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobbersoft_orders/domain/repositories/shipment_repository.dart';
import 'package:jobbersoft_orders/features/shipments/bloc/shipment_wizard_bloc.dart';
import 'package:jobbersoft_orders/features/shipments/bloc/shipment_wizard_event.dart';
import 'package:jobbersoft_orders/features/shipments/bloc/shipment_wizard_state.dart';

class MockShipmentRepository extends Mock implements ShipmentRepository {}

void main() {
  late MockShipmentRepository repository;

  const date = '2026-12-01';
  const nextDate = '2026-12-02';

  final orders = <Map<String, Object?>>[
    {'id': 1, 'code': 'O-1001', 'total_gallons': 100},
    {'id': 2, 'code': 'O-1002', 'total_gallons': 200},
  ];

  final productTotals = <Map<String, Object?>>[
    {'product_id': 7, 'product_name': 'Diesel', 'total_gallons': 100},
  ];

  final trucks = <Map<String, Object?>>[
    {'id': 10, 'code': 'TR-10', 'total_capacity': 500},
  ];

  final drivers = <Map<String, Object?>>[
    {'id': 20, 'name': 'Test Driver'},
  ];

  final compartments = <Map<String, Object?>>[
    {'id': 30, 'truck_id': 10, 'capacity_gal': 500, 'position': 1},
  ];

  final orderLines = <Map<String, Object?>>[
    {
      'order_line_id': 100,
      'order_id': 1,
      'order_code': 'O-1001',
      'product_id': 7,
      'product_code': 'DSL',
      'requested_gallons': 100,
    },
  ];

  final terminals = <Map<String, Object?>>[
    {'id': 40, 'name': 'Main Terminal'},
  ];

  setUp(() {
    repository = MockShipmentRepository();
  });

  ShipmentWizardBloc buildBloc() =>
      ShipmentWizardBloc(repository: repository, initialDate: date);

  group('ShipmentWizardBloc - order selection', () {
    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'loads submitted orders for the selected date',
      build: () {
        when(
          () => repository.getSubmittedOrdersForDate(date),
        ).thenAnswer((_) async => orders);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadShipmentOrders(date)),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.status,
          'status',
          ShipmentWizardStatus.loading,
        ),
        isA<ShipmentWizardState>()
            .having((s) => s.status, 'status', ShipmentWizardStatus.loaded)
            .having((s) => s.shipmentDate, 'shipmentDate', date)
            .having((s) => s.availableOrders, 'availableOrders', orders)
            .having((s) => s.selectedOrderIds, 'selectedOrderIds', isEmpty),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'emits failure when submitted orders cannot be loaded',
      build: () {
        when(
          () => repository.getSubmittedOrdersForDate(date),
        ).thenThrow(Exception('Orders unavailable'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadShipmentOrders(date)),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.status,
          'status',
          ShipmentWizardStatus.loading,
        ),
        isA<ShipmentWizardState>()
            .having((s) => s.status, 'status', ShipmentWizardStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Orders unavailable'),
            ),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'selects an order and recalculates product totals',
      build: () {
        when(
          () => repository.getSelectedProductTotals([1]),
        ).thenAnswer((_) async => productTotals);
        return buildBloc();
      },
      seed: () =>
          ShipmentWizardState(shipmentDate: date, availableOrders: orders),
      act: (bloc) => bloc.add(const ToggleShipmentOrder(1)),
      expect: () => [
        isA<ShipmentWizardState>()
            .having((s) => s.selectedOrderIds, 'selectedOrderIds', {1})
            .having((s) => s.productTotals, 'productTotals', productTotals)
            .having((s) => s.status, 'status', ShipmentWizardStatus.loaded),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'requests confirmation before changing date when orders are selected',
      build: () => buildBloc(),
      seed: () =>
          ShipmentWizardState(shipmentDate: date, selectedOrderIds: {1}),
      act: (bloc) => bloc.add(const ChangeShipmentDate(nextDate)),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.pendingDate,
          'pendingDate',
          nextDate,
        ),
      ],
      verify: (_) =>
          verifyNever(() => repository.getSubmittedOrdersForDate(nextDate)),
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'loads orders immediately when changing date with no selected orders',
      build: () {
        when(
          () => repository.getSubmittedOrdersForDate(nextDate),
        ).thenAnswer((_) async => orders);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ChangeShipmentDate(nextDate)),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.status,
          'status',
          ShipmentWizardStatus.loading,
        ),
        isA<ShipmentWizardState>()
            .having((s) => s.shipmentDate, 'shipmentDate', nextDate)
            .having((s) => s.status, 'status', ShipmentWizardStatus.loaded),
      ],
    );
  });

  group('ShipmentWizardBloc - truck and driver selection', () {
    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'loads available trucks and drivers',
      build: () {
        when(
          () => repository.getAvailableTrucks(date),
        ).thenAnswer((_) async => trucks);
        when(
          () => repository.getAvailableDrivers(date),
        ).thenAnswer((_) async => drivers);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadShipmentResources()),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.status,
          'status',
          ShipmentWizardStatus.loading,
        ),
        isA<ShipmentWizardState>()
            .having((s) => s.status, 'status', ShipmentWizardStatus.loaded)
            .having((s) => s.availableTrucks, 'availableTrucks', trucks)
            .having((s) => s.availableDrivers, 'availableDrivers', drivers),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'selecting a truck clears driver and previous allocation data',
      build: () => buildBloc(),
      seed: () => ShipmentWizardState(
        shipmentDate: date,
        selectedDriverId: 20,
        compartments: compartments,
        compartmentProducts: {30: 7},
        allocations: {
          30: {100: 50},
        },
      ),
      act: (bloc) => bloc.add(const SelectShipmentTruck(10)),
      expect: () => [
        isA<ShipmentWizardState>()
            .having((s) => s.selectedTruckId, 'selectedTruckId', 10)
            .having((s) => s.selectedDriverId, 'selectedDriverId', isNull)
            .having((s) => s.compartments, 'compartments', isEmpty)
            .having((s) => s.allocations, 'allocations', isEmpty),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'selects a driver',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const SelectShipmentDriver(20)),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.selectedDriverId,
          'selectedDriverId',
          20,
        ),
      ],
    );
  });

  group('ShipmentWizardBloc - allocations', () {
    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'requires a truck and at least one order before loading allocation data',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const LoadShipmentAllocationData()),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Select a truck and at least one order first.',
        ),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'loads compartments and order lines',
      build: () {
        when(
          () => repository.getTruckCompartments(10),
        ).thenAnswer((_) async => compartments);
        when(
          () => repository.getSelectedOrderLines([1]),
        ).thenAnswer((_) async => orderLines);
        return buildBloc();
      },
      seed: () => ShipmentWizardState(
        shipmentDate: date,
        selectedOrderIds: {1},
        selectedTruckId: 10,
      ),
      act: (bloc) => bloc.add(const LoadShipmentAllocationData()),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.status,
          'status',
          ShipmentWizardStatus.loading,
        ),
        isA<ShipmentWizardState>()
            .having((s) => s.status, 'status', ShipmentWizardStatus.loaded)
            .having((s) => s.compartments, 'compartments', compartments)
            .having((s) => s.orderLines, 'orderLines', orderLines),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'selects a product for a compartment',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(
        const SelectCompartmentProduct(compartmentId: 30, productId: 7),
      ),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.compartmentProducts,
          'compartmentProducts',
          {30: 7},
        ),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'rejects negative allocation quantities',
      build: () => buildBloc(),
      seed: () => ShipmentWizardState(
        shipmentDate: date,
        orderLines: orderLines,
        compartments: compartments,
        compartmentProducts: {30: 7},
      ),
      act: (bloc) => bloc.add(
        const UpdateLineAllocation(
          compartmentId: 30,
          orderLineId: 100,
          gallons: -1,
        ),
      ),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Gallons cannot be negative.',
        ),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'rejects allocation when the compartment product does not match',
      build: () => buildBloc(),
      seed: () => ShipmentWizardState(
        shipmentDate: date,
        orderLines: orderLines,
        compartments: compartments,
        compartmentProducts: {30: 99},
      ),
      act: (bloc) => bloc.add(
        const UpdateLineAllocation(
          compartmentId: 30,
          orderLineId: 100,
          gallons: 50,
        ),
      ),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.errorMessage,
          'errorMessage',
          'Select the matching product for this compartment.',
        ),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'accepts a valid allocation and calculates remaining gallons',
      build: () => buildBloc(),
      seed: () => ShipmentWizardState(
        shipmentDate: date,
        orderLines: orderLines,
        compartments: compartments,
        compartmentProducts: {30: 7},
      ),
      act: (bloc) => bloc.add(
        const UpdateLineAllocation(
          compartmentId: 30,
          orderLineId: 100,
          gallons: 60,
        ),
      ),
      expect: () => [
        isA<ShipmentWizardState>()
            .having((s) => s.allocations, 'allocations', {
              30: {100: 60},
            })
            .having(
              (s) => s.allocatedForOrderLine(100),
              'allocatedForOrderLine',
              60,
            ),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'stores a partial load reason',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(
        const UpdatePartialLoadReason(
          orderLineId: 100,
          reason: 'Customer limit',
        ),
      ),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.partialLoadReasons,
          'partialLoadReasons',
          {100: 'Customer limit'},
        ),
      ],
    );
  });

  group('ShipmentWizardBloc - terminal and BOL', () {
    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'loads terminal options',
      build: () {
        when(
          () => repository.getTerminals(),
        ).thenAnswer((_) async => terminals);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const LoadShipmentTerminals()),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.status,
          'status',
          ShipmentWizardStatus.loading,
        ),
        isA<ShipmentWizardState>()
            .having((s) => s.status, 'status', ShipmentWizardStatus.loaded)
            .having(
              (s) => s.availableTerminals,
              'availableTerminals',
              terminals,
            ),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'selects a terminal',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const SelectShipmentTerminal(40)),
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.selectedTerminalId,
          'selectedTerminalId',
          40,
        ),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'normalizes BOL input and resets its validation',
      build: () => buildBloc(),
      seed: () => const ShipmentWizardState(
        shipmentDate: date,
        bolNumber: 'BOL-12345',
        isBolValid: true,
      ),
      act: (bloc) => bloc.add(const UpdateShipmentBolNumber(' bol-54321 ')),
      expect: () => [
        isA<ShipmentWizardState>()
            .having((s) => s.bolNumber, 'bolNumber', 'BOL-54321')
            .having((s) => s.isBolValid, 'isBolValid', false)
            .having((s) => s.isBolChecking, 'isBolChecking', false),
      ],
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'rejects an invalid BOL format without calling repository',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const ValidateShipmentBolNumber('12345')),
      expect: () => [
        isA<ShipmentWizardState>()
            .having((s) => s.bolNumber, 'bolNumber', '12345')
            .having((s) => s.isBolValid, 'isBolValid', false)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Enter BOL in format BOL-12345.',
            ),
      ],
      verify: (_) => verifyNever(() => repository.isBolNumberAvailable(any())),
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'validates an available BOL number',
      build: () {
        when(
          () => repository.isBolNumberAvailable('BOL-12345'),
        ).thenAnswer((_) async => true);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ValidateShipmentBolNumber(' bol-12345 ')),
      expect: () => [
        isA<ShipmentWizardState>()
            .having((s) => s.bolNumber, 'bolNumber', 'BOL-12345')
            .having((s) => s.isBolChecking, 'isBolChecking', true),
        isA<ShipmentWizardState>()
            .having((s) => s.bolNumber, 'bolNumber', 'BOL-12345')
            .having((s) => s.isBolChecking, 'isBolChecking', false)
            .having((s) => s.isBolValid, 'isBolValid', true),
      ],
    );
  });

  group('ShipmentWizardBloc - shipment planning', () {
    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'rejects planning when no order is selected',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const PlanShipment()),
      expect: () => [
        isA<ShipmentWizardState>()
            .having((s) => s.status, 'status', ShipmentWizardStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Select at least one order.',
            ),
      ],
      verify: (_) => verifyNever(
        () => repository.planShipment(
          shipmentDate: any(named: 'shipmentDate'),
          truckId: any(named: 'truckId'),
          driverId: any(named: 'driverId'),
          terminalId: any(named: 'terminalId'),
          bolNumber: any(named: 'bolNumber'),
          orderIds: any(named: 'orderIds'),
          allocations: any(named: 'allocations'),
          partialLoadReasons: any(named: 'partialLoadReasons'),
          failAfterLoads: any(named: 'failAfterLoads'),
        ),
      ),
    );

    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'plans a valid shipment and emits the shipment code',
      build: () {
        when(
          () => repository.planShipment(
            shipmentDate: date,
            truckId: 10,
            driverId: 20,
            terminalId: 40,
            bolNumber: 'BOL-12345',
            orderIds: [1],
            allocations: {
              30: {100: 100},
            },
            partialLoadReasons: {},
            failAfterLoads: false,
          ),
        ).thenAnswer((_) async => 'S-1001');
        return buildBloc();
      },
      seed: () => ShipmentWizardState(
        shipmentDate: date,
        selectedOrderIds: {1},
        selectedTruckId: 10,
        selectedDriverId: 20,
        selectedTerminalId: 40,
        bolNumber: 'BOL-12345',
        isBolValid: true,
        compartments: compartments,
        orderLines: orderLines,
        compartmentProducts: {30: 7},
        allocations: {
          30: {100: 100},
        },
      ),
      act: (bloc) => bloc.add(const PlanShipment()),
      expect: () => [
        isA<ShipmentWizardState>()
            .having((s) => s.status, 'status', ShipmentWizardStatus.loading)
            .having((s) => s.errorMessage, 'errorMessage', isNull),
        isA<ShipmentWizardState>()
            .having((s) => s.status, 'status', ShipmentWizardStatus.success)
            .having((s) => s.shipmentCode, 'shipmentCode', 'S-1001'),
      ],
    );
  });

  group('ShipmentWizardBloc - debug failure toggle', () {
    blocTest<ShipmentWizardBloc, ShipmentWizardState>(
      'enables and disables forced save failure',
      build: () => buildBloc(),
      act: (bloc) async {
        bloc.add(const ToggleShipmentSaveFailure(true));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ToggleShipmentSaveFailure(false));
      },
      expect: () => [
        isA<ShipmentWizardState>().having(
          (s) => s.failShipmentSaveAfterLoads,
          'failShipmentSaveAfterLoads',
          true,
        ),
        isA<ShipmentWizardState>().having(
          (s) => s.failShipmentSaveAfterLoads,
          'failShipmentSaveAfterLoads',
          false,
        ),
      ],
    );
  });
}
