import 'package:equatable/equatable.dart';

abstract class OrdersListEvent extends Equatable {
  const OrdersListEvent();

  @override
  List<Object?> get props => [];
}

class LoadOrders extends OrdersListEvent {
  final String? status;
  final String? shipmentDate;
  final String? storeQuery;

  const LoadOrders({this.status, this.shipmentDate, this.storeQuery});

  @override
  List<Object?> get props => [status, shipmentDate, storeQuery];
}
