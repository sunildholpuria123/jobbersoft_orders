enum ShipmentListStatus {
  initial,
  loading,
  loaded,
  failure,
}

class ShipmentListState {
  final ShipmentListStatus status;
  final List<Map<String, Object?>> shipments;
  final String? errorMessage;
  final String? filterStatus;
  final String? filterDate;

  const ShipmentListState({
    this.status = ShipmentListStatus.initial,
    this.shipments = const [],
    this.errorMessage,
    this.filterStatus,
    this.filterDate,
  });

  ShipmentListState copyWith({
    ShipmentListStatus? status,
    List<Map<String, Object?>>? shipments,
    String? errorMessage,
    String? filterStatus,
    String? filterDate,
  }) {
    return ShipmentListState(
      status: status ?? this.status,
      shipments: shipments ?? this.shipments,
      errorMessage: errorMessage,
      filterStatus: filterStatus ?? this.filterStatus,
      filterDate: filterDate ?? this.filterDate,
    );
  }
}