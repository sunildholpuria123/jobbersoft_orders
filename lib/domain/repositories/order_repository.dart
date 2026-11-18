import '../../../data/models/store_model.dart';
import '../../data/models/tank_model.dart';

abstract class OrderRepository {
  Stream<void> watchOrderChanges();

  Future<List<StoreModel>> searchStores(String query);

  Future<StoreModel?> getStoreById(int id);

  Future<int> createDraft({required int storeId});

  Future<void> saveStepOne({
    required int orderId,
    required int storeId,
    required String shipmentDate,
    required String deliveryTime,
    String? poNumber,
  });

  Future<Map<String, Object?>?> getLatestDraft();

  Future<List<TankModel>> getTanksByStore(int storeId);

  Future<void> saveOrderLines({
    required int orderId,
    required Map<int, int> quantities,
  });

  Future<Map<int, int>> getOrderLines(int orderId);

  Future<String> submitOrder(int orderId);

  Future<List<Map<String, dynamic>>> getOrderLinesForReview(int orderId);

  Future<List<Map<String, Object?>>> getOrders({
    String? status,
    String? shipmentDate,
    String? storeQuery,
  });

  Future<Map<String, Object?>?> getDraft(int orderId);

  Future<void> updateWizardStep({
    required int orderId,
    required int step,
  });
}
