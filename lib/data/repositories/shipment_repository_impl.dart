import '../../core/database/database_change_notifier.dart';
import '../../domain/repositories/shipment_repository.dart';
import '../dao/shipment_dao.dart';

class ShipmentRepositoryImpl implements ShipmentRepository {
  final ShipmentDao shipmentDao;
  final DatabaseChangeNotifier changeNotifier;

  ShipmentRepositoryImpl({
    required this.shipmentDao,
    required this.changeNotifier,
  });

  @override
  Future<List<Map<String, Object?>>> getShipments({
    String? status,
    String? shipmentDate,
  }) {
    return shipmentDao.getShipments(status: status, shipmentDate: shipmentDate);
  }

  @override
  Stream<void> watchShipmentChanges() {
    return changeNotifier.changes;
  }

  @override
  Future<List<Map<String, Object?>>> getSubmittedOrdersForDate(
    String shipmentDate,
  ) {
    return shipmentDao.getSubmittedOrdersForDate(shipmentDate);
  }

  @override
  Future<List<Map<String, Object?>>> getSelectedProductTotals(
    List<int> orderIds,
  ) {
    return shipmentDao.getSelectedProductTotals(orderIds);
  }

  @override
  Future<List<Map<String, Object?>>> getAvailableTrucks(String shipmentDate) {
    return shipmentDao.getAvailableTrucks(shipmentDate);
  }

  @override
  Future<List<Map<String, Object?>>> getAvailableDrivers(String shipmentDate) {
    return shipmentDao.getAvailableDrivers(shipmentDate);
  }

  @override
  Future<List<Map<String, Object?>>> getTruckCompartments(int truckId) {
    return shipmentDao.getTruckCompartments(truckId);
  }

  @override
  Future<List<Map<String, Object?>>> getSelectedOrderLines(List<int> orderIds) {
    return shipmentDao.getSelectedOrderLines(orderIds);
  }


  @override
  Future<List<Map<String, Object?>>> getTerminals() {
    return shipmentDao.getTerminals();
  }

  @override
  Future<bool> isBolNumberAvailable(
      String bolNumber, {
        int? excludeShipmentId,
      }) {
    return shipmentDao.isBolNumberAvailable(
      bolNumber,
      excludeShipmentId: excludeShipmentId,
    );
  }


  @override
  Future<String> planShipment({
    required String shipmentDate,
    required int truckId,
    required int driverId,
    required int terminalId,
    required String bolNumber,
    required List<int> orderIds,
    required Map<int, Map<int, int>> allocations,
    required Map<int, String> partialLoadReasons,
    bool failAfterLoads = false,
  }) {
    return shipmentDao.planShipment(
      shipmentDate: shipmentDate,
      truckId: truckId,
      driverId: driverId,
      terminalId: terminalId,
      bolNumber: bolNumber,
      orderIds: orderIds,
      allocations: allocations,
      partialLoadReasons: partialLoadReasons,
      failAfterLoads: failAfterLoads,
    );
  }

  @override
  Future<void> cancelShipment(int shipmentId) {
    return shipmentDao.cancelShipment(shipmentId);
  }

}
