import 'package:equatable/equatable.dart';

abstract class TankEvent extends Equatable {
  const TankEvent();

  @override
  List<Object?> get props => [];
}

class LoadTanks extends TankEvent {
  final int storeId;
  final int orderId;

  const LoadTanks({required this.storeId, required this.orderId});

  @override
  List<Object?> get props => [storeId, orderId];
}

class UpdateTankQuantity extends TankEvent {
  final int tankId;
  final String quantity;

  const UpdateTankQuantity({required this.tankId, required this.quantity});

  @override
  List<Object?> get props => [tankId, quantity];
}

class SaveTankQuantities extends TankEvent {}
