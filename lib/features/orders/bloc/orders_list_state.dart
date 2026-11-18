import 'package:equatable/equatable.dart';

enum OrdersListStatus { initial, loading, loaded, failure }

class OrdersListState extends Equatable {
  final OrdersListStatus status;
  final List<Map<String, Object?>> orders;
  final String? errorMessage;

  const OrdersListState({
    this.status = OrdersListStatus.initial,
    this.orders = const [],
    this.errorMessage,
  });

  OrdersListState copyWith({
    OrdersListStatus? status,
    List<Map<String, Object?>>? orders,
    String? errorMessage,
  }) {
    return OrdersListState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, orders, errorMessage];
}
