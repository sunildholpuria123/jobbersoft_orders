import 'package:equatable/equatable.dart';

import '../../../data/models/store_model.dart';

enum OrderStatus { initial, loading, loaded, saving, success, failure }

class OrderState extends Equatable {
  final OrderStatus status;
  final List<StoreModel> stores;
  final StoreModel? selectedStore;
  final int? orderId;
  final DateTime? shipmentDate;
  final String deliveryTime;
  final String? poNumber;
  final int currentStep;
  final String? errorMessage;
  final String? errorCode;
  final List<Map<String, dynamic>> reviewLines;
  const OrderState({
    this.status = OrderStatus.initial,
    this.stores = const [],
    this.selectedStore,
    this.orderId,
    this.shipmentDate,
    this.deliveryTime = '',
    this.poNumber,
    this.currentStep = 1,
    this.errorMessage,
    this.errorCode,
    this.reviewLines = const [],
  });

  OrderState copyWith({
    OrderStatus? status,
    List<StoreModel>? stores,
    StoreModel? selectedStore,
    int? orderId,
    DateTime? shipmentDate,
    String? deliveryTime,
    String? poNumber,
    int? currentStep,
    String? errorMessage,
    String? errorCode,
    List<Map<String, dynamic>>? reviewLines,
  }) {
    return OrderState(
      status: status ?? this.status,
      stores: stores ?? this.stores,
      selectedStore: selectedStore ?? this.selectedStore,
      orderId: orderId ?? this.orderId,
      shipmentDate: shipmentDate ?? this.shipmentDate,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      poNumber: poNumber ?? this.poNumber,
      currentStep: currentStep ?? this.currentStep,
      errorMessage: errorMessage,
      errorCode: errorCode,
      reviewLines: reviewLines ?? this.reviewLines,
    );
  }

  @override
  List<Object?> get props => [
    status,
    stores,
    selectedStore,
    orderId,
    shipmentDate,
    deliveryTime,
    poNumber,
    currentStep,
    errorMessage,
    errorCode,
    reviewLines,
  ];
}
