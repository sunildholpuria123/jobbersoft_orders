class TankModel {
  final int id;
  final int storeId;
  final int productId;
  final String productName;
  final String productCode;
  final int capacityGallons;
  final int currentLevelGallons;

  const TankModel({
    required this.id,
    required this.storeId,
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.capacityGallons,
    required this.currentLevelGallons,
  });

  int get ullage => capacityGallons - currentLevelGallons;

  factory TankModel.fromMap(Map<String, Object?> map) {
    return TankModel(
      id: map['id'] as int,
      storeId: map['store_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      productCode: map['product_code'] as String,
      capacityGallons: map['capacity_gal'] as int,
      currentLevelGallons: map['current_level_gal'] as int,
    );
  }
}
