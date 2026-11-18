import '../../core/database/database_change_notifier.dart';
import '../../domain/repositories/order_repository.dart';
import '../dao/order_dao.dart';
import '../dao/store_dao.dart';
import '../dao/tank_dao.dart';
import '../models/store_model.dart';
import '../models/tank_model.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderDao orderDao;
  final StoreDao storeDao;
  final TankDao tankDao;
  final DatabaseChangeNotifier changeNotifier;
  OrderRepositoryImpl({
    required this.orderDao,
    required this.storeDao,
    required this.tankDao,
    required this.changeNotifier,
  });

  @override
  Stream<void> watchOrderChanges() {
    return changeNotifier.changes;
  }

  @override
  Future<List<StoreModel>> searchStores(String query) {
    return storeDao.searchStores(query);
  }

  @override
  Future<StoreModel?> getStoreById(int id) {
    return storeDao.getStoreById(id);
  }

  @override
  Future<int> createDraft({required int storeId}) {
    return orderDao.createDraft(storeId: storeId);
  }

  @override
  Future<void> saveStepOne({
    required int orderId,
    required int storeId,
    required String shipmentDate,
    required String deliveryTime,
    String? poNumber,
  }) {
    return orderDao.saveStepOne(
      orderId: orderId,
      storeId: storeId,
      shipmentDate: shipmentDate,
      deliveryTime: deliveryTime,
      poNumber: poNumber,
    );
  }

  @override
  Future<Map<String, Object?>?> getLatestDraft() {
    return orderDao.getLatestDraft();
  }

  @override
  Future<List<TankModel>> getTanksByStore(int storeId) {
    return tankDao.getTanksByStore(storeId);
  }

  @override
  Future<void> saveOrderLines({
    required int orderId,
    required Map<int, int> quantities,
  }) {
    return tankDao.saveOrderLines(orderId: orderId, quantities: quantities);
  }

  @override
  Future<Map<int, int>> getOrderLines(int orderId) {
    return tankDao.getOrderLines(orderId);
  }

  @override
  Future<String> submitOrder(int orderId) {
    return orderDao.submitOrder(orderId);
  }

  @override
  Future<List<Map<String, dynamic>>> getOrderLinesForReview(int orderId) {
    return tankDao.getOrderLinesForReview(orderId);
  }

  @override
  Future<List<Map<String, Object?>>> getOrders({
    String? status,
    String? shipmentDate,
    String? storeQuery,
  }) {
    return orderDao.getOrders(
      status: status,
      shipmentDate: shipmentDate,
      storeQuery: storeQuery,
    );
  }

  @override
  Future<Map<String, Object?>?> getDraft(int orderId) {
    return orderDao.getDraft(orderId);
  }

  @override
  Future<void> updateWizardStep({required int orderId, required int step}) {
    return tankDao.updateWizardStep(orderId: orderId, step: step);
  }


}
