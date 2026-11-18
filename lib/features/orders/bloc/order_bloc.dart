import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/store_model.dart';
import '../../../domain/repositories/order_repository.dart';
import 'order_event.dart';
import 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository repository;

  OrderBloc(this.repository) : super(const OrderState()) {
    on<SearchStores>(_onSearchStores);
    on<CreateOrderDraft>(_onCreateDraft);
    on<RestoreOrderDraft>(_onRestoreDraft);
    on<SaveOrderStepOne>(_onSaveStepOne);
    on<SubmitOrder>(_onSubmitOrder);
    on<LoadOrderReview>(_onLoadOrderReview);
  }

  Future<void> _onSearchStores(
    SearchStores event,
    Emitter<OrderState> emit,
  ) async {
    try {
      final stores = await repository.searchStores(event.query);
      emit(state.copyWith(status: OrderStatus.loaded, stores: stores));
    } catch (e) {
      emit(
        state.copyWith(status: OrderStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  Future<void> _onCreateDraft(
    CreateOrderDraft event,
    Emitter<OrderState> emit,
  ) async {
    // Prevent creating duplicate drafts.
    if (state.orderId != null) return;

    emit(state.copyWith(status: OrderStatus.loading));

    try {
      final orderId = await repository.createDraft(storeId: event.store.id);

      emit(
        state.copyWith(
          status: OrderStatus.success,
          orderId: orderId,
          selectedStore: event.store,
          currentStep: 1,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: OrderStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  Future<void> _onRestoreDraft(
    RestoreOrderDraft event,
    Emitter<OrderState> emit,
  ) async {
    // Restore only when an existing draft ID is provided.
    if (event.orderId == null) return;

    emit(state.copyWith(status: OrderStatus.loading));

    try {
      final draft = await repository.getDraft(event.orderId!);

      if (draft == null) {
        throw Exception('Draft order not found');
      }

      final storeId = draft['store_id'] as int?;
      StoreModel? store;

      if (storeId != null) {
        store = await repository.getStoreById(storeId);
      }

      final dateValue = draft['shipment_date'] as String?;

      emit(
        state.copyWith(
          status: OrderStatus.success,
          orderId: draft['id'] as int,
          selectedStore: store,
          shipmentDate: dateValue == null ? null : DateTime.tryParse(dateValue),
          deliveryTime: draft['delivery_time'] as String? ?? '',
          poNumber: draft['po_number'] as String?,
          currentStep: draft['wizard_step'] as int? ?? 1,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: OrderStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  Future<void> _onSaveStepOne(
    SaveOrderStepOne event,
    Emitter<OrderState> emit,
  ) async {
    emit(state.copyWith(status: OrderStatus.saving));

    try {
      await repository.saveStepOne(
        orderId: event.orderId,
        storeId: event.store.id,
        shipmentDate: event.shipmentDate.toIso8601String().split('T').first,
        deliveryTime: event.deliveryTime,
        poNumber: event.poNumber,
      );

      emit(
        state.copyWith(
          status: OrderStatus.success,
          selectedStore: event.store,
          shipmentDate: event.shipmentDate,
          deliveryTime: event.deliveryTime,
          poNumber: event.poNumber,
          currentStep: 2,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: OrderStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  Future<void> _onSubmitOrder(
    SubmitOrder event,
    Emitter<OrderState> emit,
  ) async {
    final orderId = state.orderId;
    if (orderId == null) return;

    emit(
      state.copyWith(
        status: OrderStatus.saving,
        errorMessage: null,
        errorCode: null,
      ),
    );

    try {
      final orderCode = await repository.submitOrder(orderId);

      emit(state.copyWith(status: OrderStatus.success, errorCode: orderCode));
    } catch (e) {
      emit(
        state.copyWith(status: OrderStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  Future<void> _onLoadOrderReview(
    LoadOrderReview event,
    Emitter<OrderState> emit,
  ) async {
    final orderId = state.orderId;
    if (orderId == null) return;

    emit(state.copyWith(status: OrderStatus.loading));

    try {
      final lines = await repository.getOrderLinesForReview(orderId);

      emit(
        state.copyWith(
          status: OrderStatus.loaded,
          reviewLines: lines,
          currentStep: 3,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: OrderStatus.failure, errorMessage: e.toString()),
      );
    }
  }
}
