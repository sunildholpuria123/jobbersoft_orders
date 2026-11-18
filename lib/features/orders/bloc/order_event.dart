import 'package:equatable/equatable.dart';

import '../../../data/models/store_model.dart';

abstract class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object?> get props => [];
}

class SearchStores extends OrderEvent {
  final String query;

  const SearchStores(this.query);

  @override
  List<Object?> get props => [query];
}

class CreateOrderDraft extends OrderEvent {
  final StoreModel store;

  const CreateOrderDraft(this.store);

  @override
  List<Object?> get props => [store];
}

class RestoreOrderDraft extends OrderEvent {
  final int? orderId;

  const RestoreOrderDraft({this.orderId});

  @override
  List<Object?> get props => [orderId];
}

class SaveOrderStepOne extends OrderEvent {
  final int orderId;
  final StoreModel store;
  final DateTime shipmentDate;
  final String deliveryTime;
  final String? poNumber;

  const SaveOrderStepOne({
    required this.orderId,
    required this.store,
    required this.shipmentDate,
    required this.deliveryTime,
    this.poNumber,
  });

  @override
  List<Object?> get props => [
    orderId,
    store,
    shipmentDate,
    deliveryTime,
    poNumber,
  ];
}

class SubmitOrder extends OrderEvent {
  const SubmitOrder();
}

class LoadOrderReview extends OrderEvent {
  const LoadOrderReview();
}
