
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/shipment_repository.dart';
import 'shipment_list_event.dart';
import 'shipment_list_state.dart';

class ShipmentListBloc
    extends Bloc<ShipmentListEvent, ShipmentListState> {
  final ShipmentRepository repository;
  StreamSubscription<void>? _subscription;

  ShipmentListBloc(this.repository)
      : super(const ShipmentListState()) {
    on<LoadShipments>(_loadShipments);
    on<CancelShipment>(_cancelShipment);

    _subscription = repository.watchShipmentChanges().listen((_) {
      add(
        LoadShipments(
          status: state.filterStatus,
          shipmentDate: state.filterDate,
        ),
      );
    });
  }

  Future<void> _loadShipments(
      LoadShipments event,
      Emitter<ShipmentListState> emit,
      ) async {
    emit(
      state.copyWith(
        status: ShipmentListStatus.loading,
        filterStatus: event.status,
        filterDate: event.shipmentDate,
      ),
    );

    try {
      final shipments = await repository.getShipments(
        status: event.status,
        shipmentDate: event.shipmentDate,
      );

      emit(
        state.copyWith(
          status: ShipmentListStatus.loaded,
          shipments: shipments,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ShipmentListStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _cancelShipment(
      CancelShipment event,
      Emitter<ShipmentListState> emit,
      ) async {
    try {
      await repository.cancelShipment(event.shipmentId);
      // The repository's change notifier triggers the list refresh.
    } catch (e) {
      emit(
        state.copyWith(
          status: ShipmentListStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
