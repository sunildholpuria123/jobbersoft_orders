
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/shipment_repository.dart';
import 'shipment_wizard_event.dart';
import 'shipment_wizard_state.dart';

class ShipmentWizardBloc
    extends Bloc<ShipmentWizardEvent, ShipmentWizardState> {
  final ShipmentRepository repository;

  ShipmentWizardBloc({
    required this.repository,
    required String initialDate,
  }) : super(ShipmentWizardState(shipmentDate: initialDate)) {
    on<LoadShipmentOrders>(_loadOrders);
    on<ToggleShipmentOrder>(_toggleOrder);
    on<ChangeShipmentDate>(_changeDate);
    on<ConfirmShipmentDateChange>(_confirmDateChange);
    on<LoadShipmentResources>(_loadResources);
    on<SelectShipmentTruck>(_selectTruck);
    on<SelectShipmentDriver>(_selectDriver);

    // S-3 allocation events
    on<LoadShipmentAllocationData>(_loadAllocationData);
    on<SelectCompartmentProduct>(_selectCompartmentProduct);
    on<UpdateLineAllocation>(_updateLineAllocation);
    on<UpdatePartialLoadReason>(_updatePartialLoadReason);

    // S-4: Terminal and BOL
    on<LoadShipmentTerminals>(_loadTerminals);
    on<SelectShipmentTerminal>(_selectTerminal);
    on<UpdateShipmentBolNumber>(_updateBolNumber);
    on<ValidateShipmentBolNumber>(_validateBolNumber);

    on<PlanShipment>(_planShipment);

    on<ToggleShipmentSaveFailure>((event, emit) {
      emit(state.copyWith(
        failShipmentSaveAfterLoads: event.enabled,
      ));
    });

  }

  Future<void> _loadOrders(
      LoadShipmentOrders event,
      Emitter<ShipmentWizardState> emit,
      ) async {
    emit(state.copyWith(status: ShipmentWizardStatus.loading));

    try {
      final orders =
      await repository.getSubmittedOrdersForDate(event.shipmentDate);

      emit(state.copyWith(
        status: ShipmentWizardStatus.loaded,
        shipmentDate: event.shipmentDate,
        availableOrders: orders,
        selectedOrderIds: {},
        productTotals: [],
        availableTrucks: [],
        availableDrivers: [],
        clearSelectedTruck: true,
        clearSelectedDriver: true,
        clearPendingDate: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ShipmentWizardStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _toggleOrder(
      ToggleShipmentOrder event,
      Emitter<ShipmentWizardState> emit,
      ) async {
    final selected = Set<int>.from(state.selectedOrderIds);

    if (selected.contains(event.orderId)) {
      selected.remove(event.orderId);
    } else {
      selected.add(event.orderId);
    }

    try {
      final totals =
      await repository.getSelectedProductTotals(selected.toList());

      emit(state.copyWith(
        selectedOrderIds: selected,
        productTotals: totals,
        status: ShipmentWizardStatus.loaded,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ShipmentWizardStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _changeDate(
      ChangeShipmentDate event,
      Emitter<ShipmentWizardState> emit,
      ) async {
    if (event.shipmentDate == state.shipmentDate) return;

    if (state.selectedOrderIds.isNotEmpty) {
      emit(state.copyWith(pendingDate: event.shipmentDate));
      return;
    }

    add(LoadShipmentOrders(event.shipmentDate));
  }

  Future<void> _confirmDateChange(
      ConfirmShipmentDateChange event,
      Emitter<ShipmentWizardState> emit,
      ) async {
    add(LoadShipmentOrders(event.shipmentDate));
  }

  Future<void> _loadResources(
      LoadShipmentResources event,
      Emitter<ShipmentWizardState> emit,
      ) async {
    emit(state.copyWith(status: ShipmentWizardStatus.loading));

    try {
      final results = await Future.wait([
        repository.getAvailableTrucks(state.shipmentDate),
        repository.getAvailableDrivers(state.shipmentDate),
      ]);

      emit(state.copyWith(
        status: ShipmentWizardStatus.loaded,
        availableTrucks: results[0],
        availableDrivers: results[1],
        clearSelectedTruck: true,
        clearSelectedDriver: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ShipmentWizardStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  void _selectTruck(
      SelectShipmentTruck event,
      Emitter<ShipmentWizardState> emit,
      ) {
    emit(state.copyWith(
      selectedTruckId: event.truckId,
      clearSelectedDriver: true,
      compartments: [],
      compartmentProducts: {},
      allocations: {},
    ));
  }

  void _selectDriver(
      SelectShipmentDriver event,
      Emitter<ShipmentWizardState> emit,
      ) {
    emit(state.copyWith(selectedDriverId: event.driverId));
  }

  // S-3: Load truck compartments and selected order lines.
  Future<void> _loadAllocationData(
      LoadShipmentAllocationData event,
      Emitter<ShipmentWizardState> emit,
      ) async {
    final truckId = state.selectedTruckId;

    if (truckId == null || state.selectedOrderIds.isEmpty) {
      emit(state.copyWith(
        errorMessage: 'Select a truck and at least one order first.',
      ));
      return;
    }

    emit(state.copyWith(status: ShipmentWizardStatus.loading));

    try {
      final results = await Future.wait([
        repository.getTruckCompartments(truckId),
        repository.getSelectedOrderLines(state.selectedOrderIds.toList()),
      ]);

      emit(state.copyWith(
        status: ShipmentWizardStatus.loaded,
        compartments: results[0],
        orderLines: results[1],
        compartmentProducts: {},
        allocations: {},
        partialLoadReasons: {},
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ShipmentWizardStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  // A compartment can contain only one product.
  void _selectCompartmentProduct(
      SelectCompartmentProduct event,
      Emitter<ShipmentWizardState> emit,
      ) {
    final existingAllocations =
        state.allocations[event.compartmentId] ?? {};

    final hasExistingLoads = existingAllocations.values.any((g) => g > 0);

    if (hasExistingLoads) {
      final incompatible = state.orderLines.any((line) {
        final lineId = line['order_line_id'] as int;
        final productId = line['product_id'] as int;
        final gallons = existingAllocations[lineId] ?? 0;

        return gallons > 0 && productId != event.productId;
      });

      if (incompatible) {
        emit(state.copyWith(
          errorMessage:
          'Remove existing allocations before changing this compartment product.',
        ));
        return;
      }
    }

    final products =
    Map<int, int>.from(state.compartmentProducts);
    products[event.compartmentId] = event.productId;

    emit(state.copyWith(compartmentProducts: products));
  }

  // Validate capacity, product compatibility and requested quantities.
  void _updateLineAllocation(
      UpdateLineAllocation event,
      Emitter<ShipmentWizardState> emit,
      ) {
    if (event.gallons < 0) {
      emit(state.copyWith(errorMessage: 'Gallons cannot be negative.'));
      return;
    }

    final line = state.orderLines.cast<Map<String, Object?>>().firstWhere(
          (item) => item['order_line_id'] == event.orderLineId,
      orElse: () => <String, Object?>{},
    );

    if (line.isEmpty) return;

    final productId = line['product_id'] as int;
    final selectedProduct =
    state.compartmentProducts[event.compartmentId];

    if (event.gallons > 0 && selectedProduct != productId) {
      emit(state.copyWith(
        errorMessage: 'Select the matching product for this compartment.',
      ));
      return;
    }

    final compartment = state.compartments.firstWhere(
          (item) => item['id'] == event.compartmentId,
      orElse: () => <String, Object?>{},
    );

    if (compartment.isEmpty) return;

    final capacity = (compartment['capacity_gal'] as num).toInt();

    final currentCompartmentAllocations =
        state.allocations[event.compartmentId] ?? {};

    final compartmentTotal = currentCompartmentAllocations.entries
        .where((entry) => entry.key != event.orderLineId)
        .fold<int>(0, (sum, entry) => sum + entry.value);

    if (compartmentTotal + event.gallons > capacity) {
      emit(state.copyWith(
        errorMessage: 'Compartment capacity is $capacity gallons.',
      ));
      return;
    }

    final requested = (line['requested_gallons'] as num).toInt();

    var allocatedElsewhere = 0;
    for (final entry in state.allocations.entries) {
      if (entry.key == event.compartmentId) continue;
      allocatedElsewhere += entry.value[event.orderLineId] ?? 0;
    }

    if (allocatedElsewhere + event.gallons > requested) {
      emit(state.copyWith(
        errorMessage: 'Allocation cannot exceed requested gallons ($requested).',
      ));
      return;
    }

    final allAllocations =
    Map<int, Map<int, int>>.from(state.allocations);

    final compartmentAllocations =
    Map<int, int>.from(currentCompartmentAllocations);

    if (event.gallons == 0) {
      compartmentAllocations.remove(event.orderLineId);
    } else {
      compartmentAllocations[event.orderLineId] = event.gallons;
    }

    allAllocations[event.compartmentId] = compartmentAllocations;

    emit(state.copyWith(allocations: allAllocations));
  }

  void _updatePartialLoadReason(
      UpdatePartialLoadReason event,
      Emitter<ShipmentWizardState> emit,
      ) {
    final reasons =
    Map<int, String>.from(state.partialLoadReasons);

    reasons[event.orderLineId] = event.reason;

    emit(state.copyWith(partialLoadReasons: reasons));
  }


  // Load terminal options from SQLite.
  Future<void> _loadTerminals(
      LoadShipmentTerminals event,
      Emitter<ShipmentWizardState> emit,
      ) async {
    emit(state.copyWith(
      status: ShipmentWizardStatus.loading,
    ));

    try {
      final terminals = await repository.getTerminals();

      emit(state.copyWith(
        status: ShipmentWizardStatus.loaded,
        availableTerminals: terminals,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ShipmentWizardStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  void _selectTerminal(
      SelectShipmentTerminal event,
      Emitter<ShipmentWizardState> emit,
      ) {
    emit(state.copyWith(
      selectedTerminalId: event.terminalId,
    ));
  }

  // Update BOL input and reset previous validation.
  void _updateBolNumber(
      UpdateShipmentBolNumber event,
      Emitter<ShipmentWizardState> emit,
      ) {
    emit(state.copyWith(
      bolNumber: event.bolNumber.trim().toUpperCase(),
      isBolValid: false,
      isBolChecking: false,
    ));
  }

  // Validate BOL format and database uniqueness.
  Future<void> _validateBolNumber(
      ValidateShipmentBolNumber event,
      Emitter<ShipmentWizardState> emit,
      ) async {
    final bol = event.bolNumber.trim().toUpperCase();

    final pattern = RegExp(r'^BOL-\d{5}$');

    if (!pattern.hasMatch(bol)) {
      emit(state.copyWith(
        bolNumber: bol,
        isBolValid: false,
        isBolChecking: false,
        errorMessage: 'Enter BOL in format BOL-12345.',
      ));
      return;
    }

    emit(state.copyWith(
      bolNumber: bol,
      isBolChecking: true,
      isBolValid: false,
    ));

    try {
      final available =
      await repository.isBolNumberAvailable(bol);

      emit(state.copyWith(
        bolNumber: bol,
        isBolChecking: false,
        isBolValid: available,
        errorMessage: available
            ? null
            : 'This BOL number already exists.',
      ));
    } catch (e) {
      emit(state.copyWith(
        isBolChecking: false,
        isBolValid: false,
        errorMessage: 'Unable to validate BOL: $e',
      ));
    }
  }

  Future<void> _planShipment(
      PlanShipment event,
      Emitter<ShipmentWizardState> emit,
      ) async {


    debugPrint('========== SHIPMENT DEBUG ==========');

    for (final line in state.orderLines) {
      final lineId = (line['order_line_id'] as num).toInt();

      debugPrint(
        'LINE ID: $lineId | '
            'ORDER: ${line['order_code']} | '
            'PRODUCT: ${line['product_code']} | '
            'PRODUCT ID: ${line['product_id']} | '
            'ALLOCATED: ${state.allocatedForOrderLine(lineId)}',
      );
    }

    for (final entry in state.allocations.entries) {
      debugPrint(
        'COMPARTMENT ${entry.key} => ${entry.value}',
      );
    }

    debugPrint('====================================');


    if (state.selectedOrderIds.isEmpty) {
      emit(state.copyWith(
        status: ShipmentWizardStatus.failure,
        errorMessage: 'Select at least one order.',
      ));
      return;
    }

    if (state.selectedTruckId == null ||
        state.selectedDriverId == null ||
        state.selectedTerminalId == null) {
      emit(state.copyWith(
        status: ShipmentWizardStatus.failure,
        errorMessage: 'Select a truck, driver and terminal.',
      ));
      return;
    }

    if (!state.isBolValid ||
        !RegExp(r'^BOL-\d{5}$').hasMatch(state.bolNumber)) {
      emit(state.copyWith(
        status: ShipmentWizardStatus.failure,
        errorMessage: 'Please validate the BOL number.',
      ));
      return;
    }

    if (!state.hasValidAllocations) {
      emit(state.copyWith(
        status: ShipmentWizardStatus.failure,
        errorMessage: 'Please check compartment allocations and reasons.',
      ));
      return;
    }

    emit(state.copyWith(
      status: ShipmentWizardStatus.loading,
      errorMessage: null,
    ));

    try {
      final code = await repository.planShipment(
        shipmentDate: state.shipmentDate,
        truckId: state.selectedTruckId!,
        driverId: state.selectedDriverId!,
        terminalId: state.selectedTerminalId!,
        bolNumber: state.bolNumber,
        orderIds: state.selectedOrderIds.toList(),
        allocations: state.allocations,
        partialLoadReasons: state.partialLoadReasons,
        failAfterLoads: state.failShipmentSaveAfterLoads,
      );

      emit(state.copyWith(
        status: ShipmentWizardStatus.success,
        shipmentCode: code,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ShipmentWizardStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

}
