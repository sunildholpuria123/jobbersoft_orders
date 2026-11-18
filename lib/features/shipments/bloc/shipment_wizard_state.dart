import 'package:equatable/equatable.dart';

enum ShipmentWizardStatus {
  initial,
  loading,
  loaded,
  failure,
  success,
}
class ShipmentWizardState extends Equatable {
  final ShipmentWizardStatus status;
  final String shipmentDate;
  final List<Map<String, Object?>> availableOrders;
  final Set<int> selectedOrderIds;
  final List<Map<String, Object?>> productTotals;
  final String? pendingDate;
  final String? errorMessage;

  // Step 2 resources
  final List<Map<String, Object?>> availableTrucks;
  final List<Map<String, Object?>> availableDrivers;
  final int? selectedTruckId;
  final int? selectedDriverId;

  // Step 3 resources
  final List<Map<String, Object?>> compartments;
  final List<Map<String, Object?>> orderLines;

  // compartmentId -> productId
  final Map<int, int> compartmentProducts;

  // compartmentId -> orderLineId -> gallons
  final Map<int, Map<int, int>> allocations;

  // orderLineId -> reason
  final Map<int, String> partialLoadReasons;

  // Step 4: Terminal and BOL
  final List<Map<String, Object?>> availableTerminals;
  final int? selectedTerminalId;
  final String bolNumber;
  final bool isBolValid;
  final bool isBolChecking;
  // Step 5: Shipment planning
  final String? shipmentCode;
  final bool failShipmentSaveAfterLoads;

  const ShipmentWizardState({
    this.status = ShipmentWizardStatus.initial,
    required this.shipmentDate,
    this.availableOrders = const [],
    this.selectedOrderIds = const {},
    this.productTotals = const [],
    this.pendingDate,
    this.errorMessage,
    this.availableTrucks = const [],
    this.availableDrivers = const [],
    this.selectedTruckId,
    this.selectedDriverId,
    this.compartments = const [],
    this.orderLines = const [],
    this.compartmentProducts = const {},
    this.allocations = const {},
    this.partialLoadReasons = const {},

    this.availableTerminals = const [],
    this.selectedTerminalId,
    this.bolNumber = '',
    this.isBolValid = false,
    this.isBolChecking = false,
    this.shipmentCode,
    this.failShipmentSaveAfterLoads = false,
  });

  int get totalSelectedGallons {
    return productTotals.fold<int>(
      0,
      (sum, item) => sum + ((item['total_gallons'] as num?)?.toInt() ?? 0),
    );
  }

  Map<String, Object?>? get selectedTruck {
    for (final truck in availableTrucks) {
      if ((truck['id'] as num).toInt() == selectedTruckId) {
        return truck;
      }
    }
    return null;
  }

  int get selectedTruckCapacity =>
      (selectedTruck?['total_capacity'] as num?)?.toInt() ?? 0;

  bool get exceedsTruckCapacity =>
      selectedTruckId != null && totalSelectedGallons > selectedTruckCapacity;

  int allocatedForCompartment(int compartmentId) {
    return (allocations[compartmentId] ?? {}).values.fold<int>(
      0,
      (sum, gallons) => sum + gallons,
    );
  }

  int allocatedForOrderLine(int orderLineId) {
    return allocations.values.fold<int>(
      0,
      (sum, compartmentAllocations) =>
          sum + (compartmentAllocations[orderLineId] ?? 0),
    );
  }

  int remainingForOrderLine(int orderLineId) {
    final line = orderLines.firstWhere(
      (item) => (item['order_line_id'] as num).toInt() == orderLineId,
    );

    final requested = (line['requested_gallons'] as num).toInt();

    return requested - allocatedForOrderLine(orderLineId);
  }

  int requestedForProduct(int productId) {
    return orderLines
        .where((line) => (line['product_id'] as num).toInt() == productId)
        .fold<int>(
          0,
          (sum, line) => sum + (line['requested_gallons'] as num).toInt(),
        );
  }

  int allocatedForProduct(int productId) {
    return orderLines
        .where((line) => (line['product_id'] as num).toInt() == productId)
        .fold<int>(
          0,
          (sum, line) =>
              sum +
              allocatedForOrderLine((line['order_line_id'] as num).toInt()),
        );
  }

  bool get hasValidAllocations {
    if (compartments.isEmpty || orderLines.isEmpty) return false;

    // Validate each compartment.
    for (final compartment in compartments) {
      final compartmentId = (compartment['id'] as num).toInt();
      final capacity = (compartment['capacity_gal'] as num).toInt();
      final allocated = allocatedForCompartment(compartmentId);
      final productId = compartmentProducts[compartmentId];

      if (allocated < 0 || allocated > capacity) return false;

      // Any non-zero allocation requires a selected product.
      if (allocated > 0 && productId == null) return false;

      // Every allocated line must match the compartment product.
      final compartmentAllocations = allocations[compartmentId] ?? {};

      for (final entry in compartmentAllocations.entries) {
        if (entry.value < 0) return false;
        if (entry.value == 0) continue;

        final matchingLines = orderLines.where(
          (line) => (line['order_line_id'] as num).toInt() == entry.key,
        );

        if (matchingLines.isEmpty || productId == null) return false;

        final lineProductId = (matchingLines.first['product_id'] as num)
            .toInt();

        if (lineProductId != productId) return false;
      }
    }

    // Validate requested quantities and partial-load reasons.
    for (final line in orderLines) {
      final lineId = (line['order_line_id'] as num).toInt();
      final requested = (line['requested_gallons'] as num).toInt();
      final allocated = allocatedForOrderLine(lineId);
      final remaining = requested - allocated;
      final reason = partialLoadReasons[lineId]?.trim() ?? '';

      if (requested <= 0 || allocated < 0 || remaining < 0) {
        return false;
      }

      // Zero or partial allocation requires a reason of 5+ characters.
      if (remaining > 0 && reason.length < 5) {
        return false;
      }
    }

    return true;
  }

  ShipmentWizardState copyWith({
    ShipmentWizardStatus? status,
    String? shipmentDate,
    List<Map<String, Object?>>? availableOrders,
    Set<int>? selectedOrderIds,
    List<Map<String, Object?>>? productTotals,
    String? pendingDate,
    bool clearPendingDate = false,
    String? errorMessage,
    List<Map<String, Object?>>? availableTrucks,
    List<Map<String, Object?>>? availableDrivers,
    int? selectedTruckId,
    bool clearSelectedTruck = false,
    int? selectedDriverId,
    bool clearSelectedDriver = false,
    List<Map<String, Object?>>? compartments,
    List<Map<String, Object?>>? orderLines,
    Map<int, int>? compartmentProducts,
    Map<int, Map<int, int>>? allocations,
    Map<int, String>? partialLoadReasons,

    List<Map<String, Object?>>? availableTerminals,
    int? selectedTerminalId,
    bool clearSelectedTerminal = false,
    String? bolNumber,
    bool? isBolValid,
    bool? isBolChecking,
    String? shipmentCode,
    bool? failShipmentSaveAfterLoads,
  }) {
    return ShipmentWizardState(
      status: status ?? this.status,
      shipmentDate: shipmentDate ?? this.shipmentDate,
      availableOrders: availableOrders ?? this.availableOrders,
      selectedOrderIds: selectedOrderIds ?? this.selectedOrderIds,
      productTotals: productTotals ?? this.productTotals,
      pendingDate: clearPendingDate ? null : pendingDate ?? this.pendingDate,
      errorMessage: errorMessage,
      availableTrucks: availableTrucks ?? this.availableTrucks,
      availableDrivers: availableDrivers ?? this.availableDrivers,
      selectedTruckId: clearSelectedTruck
          ? null
          : selectedTruckId ?? this.selectedTruckId,
      selectedDriverId: clearSelectedDriver
          ? null
          : selectedDriverId ?? this.selectedDriverId,
      compartments: compartments ?? this.compartments,
      orderLines: orderLines ?? this.orderLines,
      compartmentProducts: compartmentProducts ?? this.compartmentProducts,
      allocations: allocations ?? this.allocations,
      partialLoadReasons: partialLoadReasons ?? this.partialLoadReasons,

      availableTerminals: availableTerminals ?? this.availableTerminals,
      selectedTerminalId: clearSelectedTerminal
          ? null
          : selectedTerminalId ?? this.selectedTerminalId,
      bolNumber: bolNumber ?? this.bolNumber,
      isBolValid: isBolValid ?? this.isBolValid,
      isBolChecking: isBolChecking ?? this.isBolChecking,
      shipmentCode: shipmentCode ?? this.shipmentCode,
      failShipmentSaveAfterLoads:
      failShipmentSaveAfterLoads ?? this.failShipmentSaveAfterLoads,
    );
  }

  @override
  List<Object?> get props => [
    status,
    shipmentDate,
    availableOrders,
    selectedOrderIds,
    productTotals,
    pendingDate,
    errorMessage,
    availableTrucks,
    availableDrivers,
    selectedTruckId,
    selectedDriverId,
    compartments,
    orderLines,
    compartmentProducts,
    allocations,
    partialLoadReasons,
    availableTerminals,
    selectedTerminalId,
    bolNumber,
    isBolValid,
    isBolChecking,
    shipmentCode,
    failShipmentSaveAfterLoads,
  ];
}
