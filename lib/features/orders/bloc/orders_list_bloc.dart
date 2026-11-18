import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/repositories/order_repository.dart';
import 'orders_list_event.dart';
import 'orders_list_state.dart';

class OrdersListBloc extends Bloc<OrdersListEvent, OrdersListState> {
  final OrderRepository repository;

  StreamSubscription<void>? _changesSubscription;

  String _status = 'ALL';
  String? _shipmentDate;
  String? _storeQuery;

  OrdersListBloc(this.repository) : super(const OrdersListState()) {
    on<LoadOrders>(_onLoadOrders);

    _changesSubscription = repository.watchOrderChanges().listen((_) {
      if (!isClosed) {
        add(
          LoadOrders(
            status: _status,
            shipmentDate: _shipmentDate,
            storeQuery: _storeQuery,
          ),
        );
      }
    });
  }

  Future<void> _onLoadOrders(
      LoadOrders event,
      Emitter<OrdersListState> emit,
      ) async {
    _status = event.status ?? 'ALL';
    _shipmentDate = event.shipmentDate;
    _storeQuery = event.storeQuery;

    emit(state.copyWith(status: OrdersListStatus.loading));

    try {
      final orders = await repository.getOrders(
        status: _status,
        shipmentDate: _shipmentDate,
        storeQuery: _storeQuery,
      );

      emit(state.copyWith(
        status: OrdersListStatus.loaded,
        orders: orders,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: OrdersListStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  @override
  Future<void> close() async {
    await _changesSubscription?.cancel();
    return super.close();
  }
}