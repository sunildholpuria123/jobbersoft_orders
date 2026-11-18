import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shipments/widgets/shipment_progress_header.dart';
import '../bloc/order_bloc.dart';
import '../bloc/order_event.dart';
import '../bloc/order_state.dart';
import '../bloc/tank_bloc.dart';
import '../bloc/tank_event.dart';
import '../bloc/tank_state.dart';
import 'order_review_page.dart';

class OrderStepTwoPage extends StatefulWidget {
  final int storeId;
  final int orderId;
  final String storeName;

  const OrderStepTwoPage({
    super.key,
    required this.storeId,
    required this.orderId,
    required this.storeName,
  });

  @override
  State<OrderStepTwoPage> createState() => _OrderStepTwoPageState();
}

class _OrderStepTwoPageState extends State<OrderStepTwoPage> {
  bool _attemptedNext = false;
  bool _openingReview = false;

  List<dynamic> _sortedTanks(TankState state) {
    final tanks = [...state.tanks];

    const order = {'REG': 0, 'PREM': 1, 'DSL': 2};

    tanks.sort(
      (a, b) =>
          (order[a.productCode] ?? 99).compareTo(order[b.productCode] ?? 99),
    );

    return tanks;
  }

  String? _quantityError(TankState state, int tankId, int ullage) {
    final value = state.quantities[tankId] ?? '0';
    final quantity = int.tryParse(value);

    if (quantity == null) return 'Enter a whole number';
    if (quantity < 0) return 'Quantity cannot be negative';
    if (quantity > ullage) return 'Max $ullage gal';

    return null;
  }

  bool _quantitiesAreValid(TankState state) {
    if (state.tanks.isEmpty) return false;

    for (final tank in state.tanks) {
      if (_quantityError(state, tank.id, tank.ullage) != null) {
        return false;
      }
    }

    return true;
  }

  void _next(TankState state) {
    setState(() => _attemptedNext = true);

    if (!_quantitiesAreValid(state) || state.totalGallons == 0) {
      return;
    }

    context.read<TankBloc>().add(SaveTankQuantities());
  }

  void _openReview() {
    if (_openingReview || !mounted) return;

    _openingReview = true;

    final orderBloc = context.read<OrderBloc>();

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: orderBloc,
              child: const OrderReviewPage(),
            ),
          ),
        )
        .then((_) {
          _openingReview = false;
        });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderBloc, OrderState>(
      listener: (context, orderState) {
        if (orderState.status == OrderStatus.loaded &&
            orderState.currentStep == 3) {
          _openReview();
        }

        if (orderState.status == OrderStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(orderState.errorMessage ?? 'Unable to load review'),
            ),
          );
        }
      },
      child: BlocListener<TankBloc, TankState>(
        listener: (context, tankState) {
          if (tankState.status == TankStatus.success) {
            context.read<OrderBloc>().add(const LoadOrderReview());
          }

          if (tankState.status == TankStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  tankState.error ?? 'Unable to save tank quantities',
                ),
              ),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'New order · ${widget.storeName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Draft')),
              ),
            ],
          ),
          body: BlocBuilder<TankBloc, TankState>(
            builder: (context, state) {
              if (state.status == TankStatus.loading ||
                  state.status == TankStatus.initial) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.status == TankStatus.failure) {
                return Center(
                  child: Text(state.error ?? 'Unable to load tanks'),
                );
              }

              final tanks = _sortedTanks(state);

              return Column(
                children: [
                  ShipmentProgressHeader(
                    currentStep: 2,
                    labels: const ['Store & Schedule', 'Tanks', 'Review'],
                  ),                  const Divider(height: 1),
                  Expanded(
                    child: tanks.isEmpty
                        ? const Center(child: Text('No tanks available'))
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              const Row(
                                children: [
                                  Expanded(flex: 3, child: Text('Tank')),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Cap',
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Level',
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Ullage',
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              ...tanks.map((tank) {
                                final error = _quantityError(
                                  state,
                                  tank.id,
                                  tank.ullage,
                                );

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              '${tank.productCode}  ${tank.productName}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '${tank.capacityGallons}',
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '${tank.currentLevelGallons}',
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '${tank.ullage}',
                                              textAlign: TextAlign.end,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Text('Gallons'),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              key: ValueKey(tank.id),
                                              initialValue:
                                                  state.quantities[tank.id] ??
                                                  '0',
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10,
                                                    ),
                                                border:
                                                    const OutlineInputBorder(),
                                                errorText: error,
                                              ),
                                              onChanged: (value) {
                                                context.read<TankBloc>().add(
                                                  UpdateTankQuantity(
                                                    tankId: tank.id,
                                                    quantity: value,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Divider(height: 20),
                                    ],
                                  ),
                                );
                              }),
                              if (_attemptedNext && state.totalGallons == 0)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Enter gallons for at least one tank',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Order total',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${state.totalGallons} gal',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('← Back'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed:
                              _quantitiesAreValid(state) &&
                                  state.status != TankStatus.saving
                              ? () => _next(state)
                              : null,
                          child: state.status == TankStatus.saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Next →'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
