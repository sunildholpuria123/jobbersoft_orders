import 'package:equatable/equatable.dart';
import '../../../data/models/tank_model.dart';

enum TankStatus { initial, loading, loaded, saving, success, failure }

class TankState extends Equatable {
  final TankStatus status;
  final int? orderId;
  final List<TankModel> tanks;
  final Map<int, String> quantities;
  final String? error;

  const TankState({
    this.status = TankStatus.initial,
    this.orderId,
    this.tanks = const [],
    this.quantities = const {},
    this.error,
  });

  int get totalGallons => quantities.values.fold(
    0,
    (total, value) => total + (int.tryParse(value) ?? 0),
  );

  TankState copyWith({
    TankStatus? status,
    int? orderId,
    List<TankModel>? tanks,
    Map<int, String>? quantities,
    String? error,
  }) {
    return TankState(
      status: status ?? this.status,
      orderId: orderId ?? this.orderId,
      tanks: tanks ?? this.tanks,
      quantities: quantities ?? this.quantities,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, orderId, tanks, quantities, error];
}
