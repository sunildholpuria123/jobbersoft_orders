import 'package:flutter_test/flutter_test.dart';
import 'package:jobbersoft_orders/data/models/store_model.dart';
import 'package:jobbersoft_orders/features/orders/bloc/order_validators.dart';

void main() {
  const store = StoreModel(
    id: 1,
    name: 'Test Store',
    address: 'Test address',
    deliveryOpen: '08:00',
    deliveryClose: '18:00',
  );

  group('OrderValidators.validateStore', () {
    test('requires a selected store', () {
      expect(OrderValidators.validateStore(null), 'Please select a store');
    });

    test('accepts a selected store', () {
      expect(OrderValidators.validateStore(store), isNull);
    });
  });

  group('OrderValidators.validateShipmentDate', () {
    test('requires a date', () {
      expect(
        OrderValidators.validateShipmentDate(null),
        'Please select delivery date',
      );
    });

    test('rejects a date in the past', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        OrderValidators.validateShipmentDate(yesterday),
        'Delivery date cannot be in the past',
      );
    });

    test('accepts today regardless of time', () {
      final todayWithTime = DateTime.now();
      expect(OrderValidators.validateShipmentDate(todayWithTime), isNull);
    });

    test('accepts a future date', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(OrderValidators.validateShipmentDate(tomorrow), isNull);
    });
  });

  group('OrderValidators.validateDeliveryTime', () {
    test('accepts a time within store hours', () {
      expect(
        OrderValidators.validateDeliveryTime(store: store, time: '12:30'),
        isNull,
      );
    });

    test('accepts opening and closing times', () {
      expect(
        OrderValidators.validateDeliveryTime(store: store, time: '08:00'),
        isNull,
      );
      expect(
        OrderValidators.validateDeliveryTime(store: store, time: '18:00'),
        isNull,
      );
    });

    test('rejects a time before opening', () {
      expect(
        OrderValidators.validateDeliveryTime(store: store, time: '07:59'),
        'Delivery time must be between 08:00 and 18:00',
      );
    });

    test('rejects a time after closing', () {
      expect(
        OrderValidators.validateDeliveryTime(store: store, time: '18:01'),
        'Delivery time must be between 08:00 and 18:00',
      );
    });

    test('rejects malformed or out-of-range time values', () {
      expect(
        OrderValidators.validateDeliveryTime(store: store, time: 'abc'),
        'Invalid delivery time',
      );
      expect(
        OrderValidators.validateDeliveryTime(store: store, time: '25:00'),
        'Invalid delivery time',
      );
      expect(
        OrderValidators.validateDeliveryTime(store: store, time: '12:60'),
        'Invalid delivery time',
      );
    });
  });

  group('OrderValidators.validatePoNumber', () {
    test('allows null and up to 20 characters', () {
      expect(OrderValidators.validatePoNumber(null), isNull);
      expect(OrderValidators.validatePoNumber('PO-123'), isNull);
      expect(OrderValidators.validatePoNumber('A' * 20), isNull);
    });

    test('rejects more than 20 characters', () {
      expect(
        OrderValidators.validatePoNumber('A' * 21),
        'PO number cannot exceed 20 characters',
      );
    });
  });
}
