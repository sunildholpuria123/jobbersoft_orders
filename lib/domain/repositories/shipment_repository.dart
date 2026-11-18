abstract class ShipmentRepository {
  Future<List<Map<String, Object?>>> getShipments({
    String? status,
    String? shipmentDate,
  });

  Stream<void> watchShipmentChanges();

  Future<List<Map<String, Object?>>> getSubmittedOrdersForDate(
      String shipmentDate,
      );

  Future<List<Map<String, Object?>>> getSelectedProductTotals(
      List<int> orderIds,
      );

  Future<List<Map<String, Object?>>> getAvailableTrucks(
      String shipmentDate,
      );

  Future<List<Map<String, Object?>>> getAvailableDrivers(
      String shipmentDate,
      );

  Future<List<Map<String, Object?>>> getTruckCompartments(int truckId);

  Future<List<Map<String, Object?>>> getSelectedOrderLines(
      List<int> orderIds,
      );

  Future<List<Map<String, Object?>>> getTerminals();

  Future<bool> isBolNumberAvailable(
      String bolNumber, {
        int? excludeShipmentId,
      });

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
  });

  Future<void> cancelShipment(int shipmentId);

}