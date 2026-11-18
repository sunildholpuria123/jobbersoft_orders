
import 'package:equatable/equatable.dart';

abstract class ShipmentWizardEvent extends Equatable {
  const ShipmentWizardEvent();

  @override
  List<Object?> get props => [];
}

class LoadShipmentOrders extends ShipmentWizardEvent {
  final String shipmentDate;

  const LoadShipmentOrders(this.shipmentDate);

  @override
  List<Object?> get props => [shipmentDate];
}

class ToggleShipmentOrder extends ShipmentWizardEvent {
  final int orderId;

  const ToggleShipmentOrder(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class ChangeShipmentDate extends ShipmentWizardEvent {
  final String shipmentDate;

  const ChangeShipmentDate(this.shipmentDate);

  @override
  List<Object?> get props => [shipmentDate];
}

class ConfirmShipmentDateChange extends ShipmentWizardEvent {
  final String shipmentDate;

  const ConfirmShipmentDateChange(this.shipmentDate);

  @override
  List<Object?> get props => [shipmentDate];
}

class LoadShipmentResources extends ShipmentWizardEvent {
  const LoadShipmentResources();
}

class SelectShipmentTruck extends ShipmentWizardEvent {
  final int truckId;

  const SelectShipmentTruck(this.truckId);

  @override
  List<Object?> get props => [truckId];
}

class SelectShipmentDriver extends ShipmentWizardEvent {
  final int driverId;

  const SelectShipmentDriver(this.driverId);

  @override
  List<Object?> get props => [driverId];
}

// S-3: Load compartments and selected order lines.
class LoadShipmentAllocationData extends ShipmentWizardEvent {
  const LoadShipmentAllocationData();
}

// Assign one product to a compartment.
class SelectCompartmentProduct extends ShipmentWizardEvent {
  final int compartmentId;
  final int productId;

  const SelectCompartmentProduct({
    required this.compartmentId,
    required this.productId,
  });

  @override
  List<Object?> get props => [compartmentId, productId];
}

// Allocate gallons from an order line to a compartment.
class UpdateLineAllocation extends ShipmentWizardEvent {
  final int compartmentId;
  final int orderLineId;
  final int gallons;

  const UpdateLineAllocation({
    required this.compartmentId,
    required this.orderLineId,
    required this.gallons,
  });

  @override
  List<Object?> get props => [compartmentId, orderLineId, gallons];
}

// Explain partial or zero allocation.
class UpdatePartialLoadReason extends ShipmentWizardEvent {
  final int orderLineId;
  final String reason;

  const UpdatePartialLoadReason({
    required this.orderLineId,
    required this.reason,
  });

  @override
  List<Object?> get props => [orderLineId, reason];
}


class LoadShipmentTerminals extends ShipmentWizardEvent {
  const LoadShipmentTerminals();
}

class SelectShipmentTerminal extends ShipmentWizardEvent {
  final int terminalId;

  const SelectShipmentTerminal(this.terminalId);

  @override
  List<Object?> get props => [terminalId];
}

class UpdateShipmentBolNumber extends ShipmentWizardEvent {
  final String bolNumber;

  const UpdateShipmentBolNumber(this.bolNumber);

  @override
  List<Object?> get props => [bolNumber];
}

class ValidateShipmentBolNumber extends ShipmentWizardEvent {
  final String bolNumber;

  const ValidateShipmentBolNumber(this.bolNumber);

  @override
  List<Object?> get props => [bolNumber];
}


class PlanShipment extends ShipmentWizardEvent {
  const PlanShipment();
}

class ToggleShipmentSaveFailure extends ShipmentWizardEvent {
  final bool enabled;

  const ToggleShipmentSaveFailure(this.enabled);

  @override
  List<Object?> get props => [enabled];
}