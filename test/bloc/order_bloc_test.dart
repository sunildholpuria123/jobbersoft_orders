import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobbersoft_orders/data/models/store_model.dart';
import 'package:jobbersoft_orders/domain/repositories/order_repository.dart';
import 'package:jobbersoft_orders/features/orders/bloc/order_bloc.dart';
import 'package:jobbersoft_orders/features/orders/bloc/order_event.dart';
import 'package:jobbersoft_orders/features/orders/bloc/order_state.dart';

class MockOrderRepository extends Mock implements OrderRepository {}

void main() {
  late MockOrderRepository repository;

  const store = StoreModel(
    id: 1,
    name: 'Test Store',
    address: 'Test address',
    deliveryOpen: '08:00',
    deliveryClose: '18:00',
  );

  setUp(() {
    repository = MockOrderRepository();
  });

  group('OrderBloc - store search', () {
    blocTest<OrderBloc, OrderState>(
      'emits loaded stores when search succeeds',
      build: () {
        when(
          () => repository.searchStores('Test'),
        ).thenAnswer((_) async => [store]);
        return OrderBloc(repository);
      },
      act: (bloc) => bloc.add(const SearchStores('Test')),
      expect: () => [
        isA<OrderState>()
            .having((s) => s.status, 'status', OrderStatus.loaded)
            .having((s) => s.stores, 'stores', [store]),
      ],
      verify: (_) => verify(() => repository.searchStores('Test')).called(1),
    );

    blocTest<OrderBloc, OrderState>(
      'emits failure when store search throws',
      build: () {
        when(
          () => repository.searchStores('bad'),
        ).thenThrow(Exception('Search failed'));
        return OrderBloc(repository);
      },
      act: (bloc) => bloc.add(const SearchStores('bad')),
      expect: () => [
        isA<OrderState>()
            .having((s) => s.status, 'status', OrderStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Search failed'),
            ),
      ],
    );
  });

  group('OrderBloc - draft creation', () {
    blocTest<OrderBloc, OrderState>(
      'creates a draft and selects its store',
      build: () {
        when(
          () => repository.createDraft(storeId: 1),
        ).thenAnswer((_) async => 42);
        return OrderBloc(repository);
      },
      act: (bloc) => bloc.add(const CreateOrderDraft(store)),
      expect: () => [
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.loading,
        ),
        isA<OrderState>()
            .having((s) => s.status, 'status', OrderStatus.success)
            .having((s) => s.orderId, 'orderId', 42)
            .having((s) => s.selectedStore, 'selectedStore', store)
            .having((s) => s.currentStep, 'currentStep', 1),
      ],
      verify: (_) => verify(() => repository.createDraft(storeId: 1)).called(1),
    );

    blocTest<OrderBloc, OrderState>(
      'emits failure when draft creation throws',
      build: () {
        when(
          () => repository.createDraft(storeId: 1),
        ).thenThrow(Exception('Create failed'));
        return OrderBloc(repository);
      },
      act: (bloc) => bloc.add(const CreateOrderDraft(store)),
      expect: () => [
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.loading,
        ),
        isA<OrderState>()
            .having((s) => s.status, 'status', OrderStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Create failed'),
            ),
      ],
    );

    blocTest<OrderBloc, OrderState>(
      'does not create another draft when an order is already active',
      build: () {
        when(
          () => repository.createDraft(storeId: 1),
        ).thenAnswer((_) async => 42);
        return OrderBloc(repository);
      },
      act: (bloc) async {
        bloc.add(const CreateOrderDraft(store));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const CreateOrderDraft(store));
      },
      expect: () => [
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.loading,
        ),
        isA<OrderState>()
            .having((s) => s.orderId, 'orderId', 42)
            .having((s) => s.status, 'status', OrderStatus.success),
      ],
      verify: (_) => verify(() => repository.createDraft(storeId: 1)).called(1),
    );
  });

  group('OrderBloc - draft restoration', () {
    blocTest<OrderBloc, OrderState>(
      'restores a draft and its store details',
      build: () {
        when(() => repository.getDraft(42)).thenAnswer(
          (_) async => {
            'id': 42,
            'store_id': 1,
            'shipment_date': '2026-12-01',
            'delivery_time': '10:30',
            'po_number': 'PO-42',
            'wizard_step': 2,
          },
        );
        when(() => repository.getStoreById(1)).thenAnswer((_) async => store);
        return OrderBloc(repository);
      },
      act: (bloc) => bloc.add(const RestoreOrderDraft(orderId: 42)),
      expect: () => [
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.loading,
        ),
        isA<OrderState>()
            .having((s) => s.status, 'status', OrderStatus.success)
            .having((s) => s.orderId, 'orderId', 42)
            .having((s) => s.selectedStore, 'selectedStore', store)
            .having(
              (s) => s.shipmentDate,
              'shipmentDate',
              DateTime(2026, 12, 1),
            )
            .having((s) => s.deliveryTime, 'deliveryTime', '10:30')
            .having((s) => s.poNumber, 'poNumber', 'PO-42')
            .having((s) => s.currentStep, 'currentStep', 2),
      ],
    );

    blocTest<OrderBloc, OrderState>(
      'emits failure when the requested draft does not exist',
      build: () {
        when(() => repository.getDraft(404)).thenAnswer((_) async => null);
        return OrderBloc(repository);
      },
      act: (bloc) => bloc.add(const RestoreOrderDraft(orderId: 404)),
      expect: () => [
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.loading,
        ),
        isA<OrderState>()
            .having((s) => s.status, 'status', OrderStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Draft order not found'),
            ),
      ],
    );

    blocTest<OrderBloc, OrderState>(
      'ignores restore when no draft ID is supplied',
      build: () => OrderBloc(repository),
      act: (bloc) => bloc.add(const RestoreOrderDraft()),
      expect: () => <OrderState>[],
      verify: (_) => verifyNever(() => repository.getDraft(any())),
    );
  });

  group('OrderBloc - saving step one', () {
    final date = DateTime(2026, 12, 5);

    blocTest<OrderBloc, OrderState>(
      'saves step one and advances to step two',
      build: () {
        when(
          () => repository.saveStepOne(
            orderId: 42,
            storeId: 1,
            shipmentDate: '2026-12-05',
            deliveryTime: '11:00',
            poNumber: 'PO-100',
          ),
        ).thenAnswer((_) async {});
        return OrderBloc(repository);
      },
      act: (bloc) => bloc.add(
        SaveOrderStepOne(
          orderId: 42,
          store: store,
          shipmentDate: date,
          deliveryTime: '11:00',
          poNumber: 'PO-100',
        ),
      ),
      expect: () => [
        isA<OrderState>().having((s) => s.status, 'status', OrderStatus.saving),
        isA<OrderState>()
            .having((s) => s.status, 'status', OrderStatus.success)
            .having((s) => s.selectedStore, 'selectedStore', store)
            .having((s) => s.shipmentDate, 'shipmentDate', date)
            .having((s) => s.deliveryTime, 'deliveryTime', '11:00')
            .having((s) => s.poNumber, 'poNumber', 'PO-100')
            .having((s) => s.currentStep, 'currentStep', 2),
      ],
      verify: (_) => verify(
        () => repository.saveStepOne(
          orderId: 42,
          storeId: 1,
          shipmentDate: '2026-12-05',
          deliveryTime: '11:00',
          poNumber: 'PO-100',
        ),
      ).called(1),
    );

    blocTest<OrderBloc, OrderState>(
      'emits failure when saving step one throws',
      build: () {
        when(
          () => repository.saveStepOne(
            orderId: 42,
            storeId: 1,
            shipmentDate: '2026-12-05',
            deliveryTime: '11:00',
            poNumber: null,
          ),
        ).thenThrow(Exception('Save failed'));
        return OrderBloc(repository);
      },
      act: (bloc) => bloc.add(
        SaveOrderStepOne(
          orderId: 42,
          store: store,
          shipmentDate: date,
          deliveryTime: '11:00',
        ),
      ),
      expect: () => [
        isA<OrderState>().having((s) => s.status, 'status', OrderStatus.saving),
        isA<OrderState>()
            .having((s) => s.status, 'status', OrderStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Save failed'),
            ),
      ],
    );
  });

  group('OrderBloc - review loading', () {
    final lines = <Map<String, dynamic>>[
      {'tank_id': 1, 'product_name': 'Diesel', 'gallons': 250},
    ];

    blocTest<OrderBloc, OrderState>(
      'loads review lines and advances to step three',
      build: () {
        when(
          () => repository.createDraft(storeId: 1),
        ).thenAnswer((_) async => 42);
        when(
          () => repository.getOrderLinesForReview(42),
        ).thenAnswer((_) async => lines);
        return OrderBloc(repository);
      },
      act: (bloc) async {
        bloc.add(const CreateOrderDraft(store));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const LoadOrderReview());
      },
      expect: () => [
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.loading,
        ),
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.success,
        ),
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.loading,
        ),
        isA<OrderState>()
            .having((s) => s.status, 'status', OrderStatus.loaded)
            .having((s) => s.reviewLines, 'reviewLines', lines)
            .having((s) => s.currentStep, 'currentStep', 3),
      ],
    );

    blocTest<OrderBloc, OrderState>(
      'ignores review loading when there is no active order',
      build: () => OrderBloc(repository),
      act: (bloc) => bloc.add(const LoadOrderReview()),
      expect: () => <OrderState>[],
      verify: (_) =>
          verifyNever(() => repository.getOrderLinesForReview(any())),
    );
  });

  group('OrderBloc - order submission', () {
    blocTest<OrderBloc, OrderState>(
      'submits an active order and emits its order code',
      build: () {
        when(
          () => repository.createDraft(storeId: 1),
        ).thenAnswer((_) async => 42);
        when(
          () => repository.submitOrder(42),
        ).thenAnswer((_) async => 'O-1042');
        return OrderBloc(repository);
      },
      act: (bloc) async {
        bloc.add(const CreateOrderDraft(store));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SubmitOrder());
      },
      expect: () => [
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.loading,
        ),
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.success,
        ),
        isA<OrderState>().having((s) => s.status, 'status', OrderStatus.saving),
        isA<OrderState>()
            .having((s) => s.status, 'status', OrderStatus.success)
            .having((s) => s.errorCode, 'errorCode', 'O-1042'),
      ],
    );

    blocTest<OrderBloc, OrderState>(
      'emits failure when submission throws',
      build: () {
        when(
          () => repository.createDraft(storeId: 1),
        ).thenAnswer((_) async => 42);
        when(
          () => repository.submitOrder(42),
        ).thenThrow(Exception('Submit failed'));
        return OrderBloc(repository);
      },
      act: (bloc) async {
        bloc.add(const CreateOrderDraft(store));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SubmitOrder());
      },
      expect: () => [
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.loading,
        ),
        isA<OrderState>().having(
          (s) => s.status,
          'status',
          OrderStatus.success,
        ),
        isA<OrderState>().having((s) => s.status, 'status', OrderStatus.saving),
        isA<OrderState>()
            .having((s) => s.status, 'status', OrderStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Submit failed'),
            ),
      ],
    );

    blocTest<OrderBloc, OrderState>(
      'ignores submission when there is no active order',
      build: () => OrderBloc(repository),
      act: (bloc) => bloc.add(const SubmitOrder()),
      expect: () => <OrderState>[],
      verify: (_) => verifyNever(() => repository.submitOrder(any())),
    );
  });
}
