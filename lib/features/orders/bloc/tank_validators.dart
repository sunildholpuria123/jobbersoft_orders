import '../../../data/models/tank_model.dart';

class TankValidators {
  static String? validateQuantity({
    required TankModel tank,
    required String value,
  }) {
    if (value.trim().isEmpty) return null;

    final gallons = int.tryParse(value);

    if (gallons == null) {
      return 'Enter a valid whole number';
    }

    if (gallons < 0) {
      return 'Gallons cannot be negative';
    }

    if (gallons > tank.ullage) {
      return 'Maximum available: ${tank.ullage} gallons';
    }

    return null;
  }

  static String? validateAll(Map<int, int> quantities) {
    if (quantities.values.every((gallons) => gallons == 0)) {
      return 'Enter gallons for at least one tank';
    }

    return null;
  }

  static int calculateTotal(Map<int, int> quantities) {
    return quantities.values.fold(0, (total, gallons) => total + gallons);
  }
}
