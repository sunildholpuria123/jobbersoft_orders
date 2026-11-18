import '../../../data/models/store_model.dart';

class OrderValidators {
  static String? validateStore(StoreModel? store) {
    if (store == null) {
      return 'Please select a store';
    }
    return null;
  }

  static String? validateShipmentDate(DateTime? date) {
    if (date == null) {
      return 'Please select delivery date';
    }

    final today = DateTime.now();
    final selected = DateTime(date.year, date.month, date.day);
    final current = DateTime(today.year, today.month, today.day);

    if (selected.isBefore(current)) {
      return 'Delivery date cannot be in the past';
    }

    return null;
  }

  static String? validateDeliveryTime({
    required StoreModel store,
    required String time,
  }) {
    final selected = _toMinutes(time);
    final open = _toMinutes(store.deliveryOpen);
    final close = _toMinutes(store.deliveryClose);

    if (selected == null || open == null || close == null) {
      return 'Invalid delivery time';
    }

    if (selected < open || selected > close) {
      return 'Delivery time must be between '
          '${store.deliveryOpen} and ${store.deliveryClose}';
    }

    return null;
  }

  static String? validatePoNumber(String? value) {
    if (value != null && value.length > 20) {
      return 'PO number cannot exceed 20 characters';
    }
    return null;
  }

  static int? _toMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return hour * 60 + minute;
  }
}
