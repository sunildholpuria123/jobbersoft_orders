import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jobbersoft_orders/features/shipments/pages/shipment_truck_driver_step_page.dart';

import '../../../core/di/injection.dart';
import '../bloc/shipment_wizard_bloc.dart';
import '../bloc/shipment_wizard_event.dart';
import '../bloc/shipment_wizard_state.dart';

class ShipmentOrdersStepPage extends StatelessWidget {
  const ShipmentOrdersStepPage({super.key});

  String _dateString(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final initialDate = _dateString(today);

    return BlocProvider(
      create: (_) =>
          getIt<ShipmentWizardBloc>(param1: initialDate)
            ..add(LoadShipmentOrders(initialDate)),
      child: _ShipmentOrdersView(dateString: _dateString),
    );
  }
}

class _ShipmentOrdersView extends StatelessWidget {
  final String Function(DateTime) dateString;

  const _ShipmentOrdersView({required this.dateString});

  Future<void> _selectDate(
    BuildContext context,
    ShipmentWizardState state,
  ) async {
    final current = DateTime.parse(state.shipmentDate);

    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (selected == null || !context.mounted) return;

    context.read<ShipmentWizardBloc>().add(
      ChangeShipmentDate(dateString(selected)),
    );
  }

  Future<void> _confirmDateChange(BuildContext context, String newDate) async {
    final shouldChange = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change shipment date?'),
        content: const Text(
          'Changing the date will clear your selected orders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep date'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Change date'),
          ),
        ],
      ),
    );

    if (shouldChange == true && context.mounted) {
      context.read<ShipmentWizardBloc>().add(
        ConfirmShipmentDateChange(newDate),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ShipmentWizardBloc, ShipmentWizardState>(
      listenWhen: (previous, current) =>
          previous.pendingDate != current.pendingDate &&
          current.pendingDate != null,
      listener: (context, state) {
        _confirmDateChange(context, state.pendingDate!);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New shipment'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: BlocBuilder<ShipmentWizardBloc, ShipmentWizardState>(
          builder: (context, state) {
            if (state.status == ShipmentWizardStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status == ShipmentWizardStatus.failure) {
              return Center(
                child: Text(state.errorMessage ?? 'Unable to load orders'),
              );
            }

            final totalGallons = state.productTotals.fold<int>(
              0,
              (sum, item) =>
                  sum + ((item['total_gallons'] as num?)?.toInt() ?? 0),
            );

            return Column(
              children: [
                const _ShipmentProgress(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Shipment date *',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _selectDate(context, state),
                        icon: const Icon(Icons.calendar_month),
                        label: Text(state.shipmentDate),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Submitted orders for this date '
                        '(${state.availableOrders.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (state.availableOrders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No submitted orders for this date.'),
                        ),
                      ...state.availableOrders.map((order) {
                        final id = (order['id'] as num).toInt();
                        final selected = state.selectedOrderIds.contains(id);
                        final gallons =
                            (order['total_gallons'] as num?)?.toInt() ?? 0;

                        return Card(
                          child: CheckboxListTile(
                            value: selected,
                            onChanged: (_) {
                              context.read<ShipmentWizardBloc>().add(
                                ToggleShipmentOrder(id),
                              );
                            },
                            title: Text(
                              '${order['code'] ?? 'Order'} '
                              '${order['store_name'] ?? ''}',
                            ),
                            subtitle: Text('$gallons gal'),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      const Divider(),
                      Text(
                        'Selected (${state.selectedOrderIds.length}) · '
                        'Product totals',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (state.productTotals.isEmpty)
                        const Text('Select at least one order.'),
                      ...state.productTotals.map((item) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${item['product_code']} · '
                            '${item['product_name']}',
                          ),
                          trailing: Text(
                            '${item['total_gallons']} gal',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Total gallons',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: Text(
                          '$totalGallons gal',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: state.selectedOrderIds.isEmpty
                              ? null
                              : () {
                                  final bloc = context
                                      .read<ShipmentWizardBloc>();

                                  bloc.add(const LoadShipmentResources());

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BlocProvider.value(
                                        value: bloc,
                                        child:
                                            const ShipmentTruckDriverStepPage(),
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('Next →'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShipmentProgress extends StatelessWidget {
  const _ShipmentProgress();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _ProgressItem(label: 'Orders', active: true),
          Expanded(child: Divider()),
          _ProgressItem(label: 'Truck'),
          Expanded(child: Divider()),
          _ProgressItem(label: 'Load'),
          Expanded(child: Divider()),
          _ProgressItem(label: 'Review'),
        ],
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final String label;
  final bool active;

  const _ProgressItem({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          active ? Icons.radio_button_checked : Icons.circle_outlined,
          color: active ? Theme.of(context).colorScheme.primary : Colors.grey,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
