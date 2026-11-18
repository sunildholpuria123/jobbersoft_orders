
abstract class ShipmentListEvent {}

class LoadShipments extends ShipmentListEvent {
  final String? status;
  final String? shipmentDate;

  LoadShipments({
    this.status,
    this.shipmentDate,
  });
}

class CancelShipment extends ShipmentListEvent {
  final int shipmentId;

  CancelShipment(this.shipmentId);
}
