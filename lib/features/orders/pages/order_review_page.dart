import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shipments/widgets/shipment_progress_header.dart';
import '../bloc/order_bloc.dart';
import '../bloc/order_event.dart';
import '../bloc/order_state.dart';

class OrderReviewPage extends StatelessWidget {
  const OrderReviewPage({super.key});

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not selected';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return '${weekdays[date.weekday - 1]}, '
        '${months[date.month - 1]} ${date.day} ${date.year}';
  }

  int _totalGallons(List<Map<String, dynamic>> lines) {
    return lines.fold<int>(
      0,
      (total, line) => total + ((line['total_gallons'] as num?)?.toInt() ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrderBloc, OrderState>(
      listener: (context, state) {
        if (state.status == OrderStatus.success && state.errorCode != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order ${state.errorCode} submitted · will sync when online',
              ),
            ),
          );

          Navigator.of(context).popUntil((route) => route.isFirst);
        }

        if (state.status == OrderStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Unable to submit order'),
            ),
          );
        }
      },
      builder: (context, state) {
        final store = state.selectedStore;
        final total = _totalGallons(state.reviewLines);
        final isSaving = state.status == OrderStatus.saving;

        return Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: const Text('New order'),
            actions: const [
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Draft')),
              ),
            ],
          ),
          body: Column(
            children: [
              const ShipmentProgressHeader(
                currentStep: 3,
                labels: const ['Store & Schedule', 'Tanks', 'Review'],
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'STORE & SCHEDULE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            final navigator = Navigator.of(context);
                            navigator.pop(); // Review → Tanks
                            navigator.pop(); // Tanks → Store & Schedule
                          },
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                    Text(
                      store?.name ?? 'Store not selected',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (store != null) Text(store.address),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatDate(state.shipmentDate)}'
                      ' · ${state.deliveryTime}',
                    ),
                    Text(
                      'PO: ${state.poNumber?.isNotEmpty == true ? state.poNumber : '—'}',
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TANKS',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Edit'),
                        ),
                      ],
                    ),
                    ...state.reviewLines.map((line) {
                      final code = line['product_code'] ?? '';
                      final name = line['product_name'] ?? '';
                      final gallons =
                          (line['total_gallons'] as num?)?.toInt() ?? 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(child: Text('$code $name')),
                            Text(
                              '$gallons gal',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$total gal',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
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
                      onPressed: isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('← Back'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: isSaving
                          ? null
                          : () {
                              context.read<OrderBloc>().add(
                                const SubmitOrder(),
                              );
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
