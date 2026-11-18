import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/order_repository.dart';
import 'tank_event.dart';
import 'tank_state.dart';

class TankBloc extends Bloc<TankEvent, TankState> {
  final OrderRepository repository;

  TankBloc(this.repository) : super(const TankState()) {
    on<LoadTanks>(_loadTanks);
    on<UpdateTankQuantity>(_updateQuantity);
    on<SaveTankQuantities>(_saveQuantities);
  }

  Future<void> _loadTanks(LoadTanks event, Emitter<TankState> emit) async {
    emit(state.copyWith(status: TankStatus.loading));

    try {
      final tanks = await repository.getTanksByStore(event.storeId);
      final saved = await repository.getOrderLines(event.orderId);

      emit(
        state.copyWith(
          status: TankStatus.loaded,
          orderId: event.orderId,
          tanks: tanks,
          quantities: {
            for (final tank in tanks) tank.id: (saved[tank.id] ?? 0).toString(),
          },
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: TankStatus.failure, error: e.toString()));
    }
  }

  Future<void> _updateQuantity(
    UpdateTankQuantity event,
    Emitter<TankState> emit,
  ) async {
    final updated = Map<int, String>.from(state.quantities);
    updated[event.tankId] = event.quantity;

    emit(state.copyWith(status: TankStatus.loaded, quantities: updated));

    final orderId = state.orderId;
    if (orderId == null) return;

    // Persist only when every entered quantity is a valid non-negative integer.
    final quantities = <int, int>{};

    for (final entry in updated.entries) {
      final value = int.tryParse(entry.value);

      if (value == null || value < 0) return;

      quantities[entry.key] = value;
    }

    try {
      await repository.saveOrderLines(orderId: orderId, quantities: quantities);
    } catch (e) {
      emit(
        state.copyWith(
          status: TankStatus.failure,
          error: 'Unable to save draft: $e',
        ),
      );
    }
  }

  Future<void> _saveQuantities(
    SaveTankQuantities event,
    Emitter<TankState> emit,
  ) async {
    final orderId = state.orderId;
    if (orderId == null) return;

    emit(state.copyWith(status: TankStatus.saving));

    try {
      final quantities = <int, int>{};

      for (final entry in state.quantities.entries) {
        final value = int.tryParse(entry.value) ?? 0;
        if (value > 0) quantities[entry.key] = value;
      }

      await repository.saveOrderLines(orderId: orderId, quantities: quantities);
      await repository.updateWizardStep(
        orderId: orderId,
        step: 3,
      );

      emit(state.copyWith(status: TankStatus.success));
    } catch (e) {
      emit(state.copyWith(status: TankStatus.failure, error: e.toString()));
    }
  }
}
