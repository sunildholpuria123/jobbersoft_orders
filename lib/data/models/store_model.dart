class StoreModel {
  final int id;
  final String name;
  final String address;
  final String deliveryOpen;
  final String deliveryClose;

  const StoreModel({
    required this.id,
    required this.name,
    required this.address,
    required this.deliveryOpen,
    required this.deliveryClose,
  });

  factory StoreModel.fromMap(Map<String, Object?> map) {
    return StoreModel(
      id: map['id'] as int,
      name: map['name'] as String,
      address: map['address'] as String,
      deliveryOpen: map['delivery_open'] as String,
      deliveryClose: map['delivery_close'] as String,
    );
  }
}
