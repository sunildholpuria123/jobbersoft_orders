import 'package:flutter_test/flutter_test.dart';
import 'package:jobbersoft_orders/data/models/tank_model.dart';
import 'package:jobbersoft_orders/features/orders/bloc/tank_validators.dart';

void main() {
  const tank = TankModel(
    id: 1,
    storeId: 10,
    productId: 20,
    productName: 'Diesel',
    productCode: 'DSL',
    capacityGallons: 1000,
    currentLevelGallons: 250,
  );

  group('TankValidators.validateQuantity', () {
    test('allows an empty value while the field is untouched', () {
      expect(TankValidators.validateQuantity(tank: tank, value: ''), isNull);
      expect(TankValidators.validateQuantity(tank: tank, value: '   '), isNull);
    });

    test('accepts zero and a valid quantity within ullage', () {
      expect(TankValidators.validateQuantity(tank: tank, value: '0'), isNull);
      expect(TankValidators.validateQuantity(tank: tank, value: '500'), isNull);
      expect(TankValidators.validateQuantity(tank: tank, value: '750'), isNull);
    });

    test('rejects non-integer input', () {
      expect(
        TankValidators.validateQuantity(tank: tank, value: 'abc'),
        'Enter a valid whole number',
      );
      expect(
        TankValidators.validateQuantity(tank: tank, value: '10.5'),
        'Enter a valid whole number',
      );
    });

    test('rejects negative gallons', () {
      expect(
        TankValidators.validateQuantity(tank: tank, value: '-1'),
        'Gallons cannot be negative',
      );
    });

    test('rejects quantity greater than ullage', () {
      expect(
        TankValidators.validateQuantity(tank: tank, value: '751'),
        'Maximum available: 750 gallons',
      );
    });
  });

  group('TankValidators.validateAll', () {
    test('requires at least one tank with positive gallons', () {
      expect(
        TankValidators.validateAll({}),
        'Enter gallons for at least one tank',
      );
      expect(
        TankValidators.validateAll({1: 0, 2: 0}),
        'Enter gallons for at least one tank',
      );
    });

    test('accepts quantities when at least one tank is positive', () {
      expect(TankValidators.validateAll({1: 0, 2: 100}), isNull);
    });
  });

  group('TankValidators.calculateTotal', () {
    test('sums all tank quantities', () {
      expect(TankValidators.calculateTotal({1: 100, 2: 250, 3: 0}), 350);
    });

    test('returns zero for an empty map', () {
      expect(TankValidators.calculateTotal({}), 0);
    });
  });
}
