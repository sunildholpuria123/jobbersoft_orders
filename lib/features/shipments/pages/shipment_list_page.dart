import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jobbersoft_orders/features/shipments/pages/shipment_orders_step_page.dart';

import '../../../core/di/injection.dart';
import '../bloc/shipment_list_bloc.dart';
import '../bloc/shipment_list_event.dart';
import '../bloc/shipment_list_state.dart';

class ShipmentListPage extends StatelessWidget {
  const ShipmentListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ShipmentListBloc>()..add(LoadShipments()),
      child: const _ShipmentListView(),
    );
  }
}

class _ShipmentListView extends StatelessWidget {
  const _ShipmentListView();

  Future<void> _confirmCancellation(
    BuildContext context,
    Map<String, Object?> shipment,
  ) async {
    final code = shipment['code'] ?? 'this shipment';
    final shipmentId = (shipment['id'] as num).toInt();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel shipment?'),
        content: Text(
          (shipment['has_sync_conflict'] as num?)?.toInt() == 1
              ? 'Cancel the conflicted plan for $code? Orders rejected by sync '
                    'will remain CANCELLED. Other scheduled orders will return '
                    'to SUBMITTED so you can create a new shipment.'
              : 'Are you sure you want to cancel $code? '
                    'Its scheduled orders will return to SUBMITTED status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep shipment'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel shipment'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<ShipmentListBloc>().add(CancelShipment(shipmentId));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cancelling $code...')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipments'),
        actions: [
          IconButton(
            tooltip: 'Refresh shipments',
            onPressed: () {
              context.read<ShipmentListBloc>().add(LoadShipments());
            },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Date:'),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (selected != null && context.mounted) {
                        final date =
                            '${selected.year.toString().padLeft(4, '0')}-'
                            '${selected.month.toString().padLeft(2, '0')}-'
                            '${selected.day.toString().padLeft(2, '0')}';

                        final state = context.read<ShipmentListBloc>().state;

                        context.read<ShipmentListBloc>().add(
                          LoadShipments(
                            status: state.filterStatus,
                            shipmentDate: date,
                          ),
                        );
                      }
                    },
                    child: const Text('Choose date'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: BlocBuilder<ShipmentListBloc, ShipmentListState>(
              builder: (context, state) {
                return Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Planned'),
                      selected: state.filterStatus == 'PLANNED',
                      onSelected: (_) {
                        context.read<ShipmentListBloc>().add(
                          LoadShipments(
                            status: state.filterStatus == 'PLANNED'
                                ? null
                                : 'PLANNED',
                            shipmentDate: state.filterDate,
                          ),
                        );
                      },
                    ),
                    FilterChip(
                      label: const Text('Cancelled'),
                      selected: state.filterStatus == 'CANCELLED',
                      onSelected: (_) {
                        context.read<ShipmentListBloc>().add(
                          LoadShipments(
                            status: state.filterStatus == 'CANCELLED'
                                ? null
                                : 'CANCELLED',
                            shipmentDate: state.filterDate,
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: BlocBuilder<ShipmentListBloc, ShipmentListState>(
              builder: (context, state) {
                if (state.status == ShipmentListStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == ShipmentListStatus.failure) {
                  return Center(
                    child: Text(
                      state.errorMessage ?? 'Unable to load shipments',
                    ),
                  );
                }

                if (state.shipments.isEmpty) {
                  return const Center(child: Text('No shipments found'));
                }

                return ListView.builder(
                  itemCount: state.shipments.length,
                  itemBuilder: (context, index) {
                    final shipment = state.shipments[index];

                    final code = shipment['code'] ?? '—';
                    final status = shipment['status'] ?? 'DRAFT';
                    final truck = shipment['truck_plate'] ?? 'No truck';
                    final driver = shipment['driver_name'] ?? 'No driver';
                    final terminal = shipment['terminal_name'] ?? 'No terminal';
                    final orders = shipment['order_count'] ?? 0;
                    final gallons = shipment['total_gallons'] ?? 0;
                    final bol = shipment['bol_number'] ?? '—';
                    final rejectedOrders =
                        (shipment['rejected_order_codes'] ?? '').toString();
                    final hasSyncConflict =
                        (shipment['has_sync_conflict'] as num?)?.toInt() == 1;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$code',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  '$status',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('$truck · $driver · $terminal'),
                            const SizedBox(height: 6),
                            Text('$orders orders · $gallons gal · BOL $bol'),
                            if (hasSyncConflict) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sync conflict: shipment was rejected.',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onErrorContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (rejectedOrders.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rejected orders: $rejectedOrders',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      'Cancel this plan, then create a new shipment without the rejected orders.',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (status == 'PLANNED') ...[
                              const Divider(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _confirmCancellation(context, shipment),
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    color: Colors.red,
                                  ),
                                  label: Text(
                                    hasSyncConflict
                                        ? 'Cancel & re-plan'
                                        : 'Cancel shipment',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShipmentOrdersStepPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New shipment'),
      ),
    );
  }
}
