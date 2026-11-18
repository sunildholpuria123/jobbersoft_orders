
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/shipment_wizard_bloc.dart';
import '../bloc/shipment_wizard_event.dart';
import '../bloc/shipment_wizard_state.dart';

class ShipmentReviewStepPage extends StatelessWidget {
  const ShipmentReviewStepPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShipmentWizardBloc, ShipmentWizardState>(
      listener: (context, state) {
        if (state.status == ShipmentWizardStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Shipment ${state.shipmentCode} planned successfully.',
              ),
            ),
          );

          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (state.status == ShipmentWizardStatus.failure) {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              icon: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 36,
              ),
              title: const Text('Could not save shipment'),
              content: const Text(
                'Nothing was saved. Please try again.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Review Shipment')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _ShipmentProgressHeader(),
              const SizedBox(height: 20),
              _row('Date', state.shipmentDate),
              _row(
                'Truck',
                state.selectedTruck?['plate_no']?.toString() ?? '-',
              ),
              _row('Driver', _driverName(state)),
              _row('Terminal', _terminalName(state)),
              _row('BOL Number', state.bolNumber),
              _row('Orders', '${state.selectedOrderIds.length}'),
              _row('Total requested', '${state.totalSelectedGallons} gal'),

              const SizedBox(height: 24),
              _sectionTitle('Order Allocations'),

              ...state.orderLines.map((line) {
                final lineId =
                (line['order_line_id'] as num).toInt();
                final requested =
                (line['requested_gallons'] as num).toInt();
                final allocated =
                state.allocatedForOrderLine(lineId);
                final remaining = requested - allocated;

                return Card(
                  child: ListTile(
                    title: Text(
                      '${line['product_name']} · ${line['order_code']}',
                    ),
                    subtitle: Text(
                      'Requested: $requested gal'
                          '\nAllocated: $allocated gal'
                          '\nRemaining: $remaining gal'
                          '${remaining > 0 ? '\nReason: ${state.partialLoadReasons[lineId] ?? '-'}' : ''}',
                    ),
                  ),
                );
              }),

              const SizedBox(height: 24),
              _sectionTitle('Compartment Loads'),

              ...state.allocations.entries.map((entry) {
                final compartment = state.compartments.firstWhere(
                      (item) =>
                  (item['id'] as num).toInt() == entry.key,
                  orElse: () => <String, Object?>{},
                );

                final loads = entry.value.entries
                    .where((item) => item.value > 0)
                    .toList();

                if (loads.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compartment ${compartment['position'] ?? entry.key}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ...loads.map((load) {
                          final line = state.orderLines.firstWhere(
                                (item) =>
                            (item['order_line_id'] as num).toInt() ==
                                load.key,
                          );

                          return _row(
                            line['product_name'].toString(),
                            '${load.value} gal',
                          );
                        }),
                        _row(
                          'Compartment total',
                          '${state.allocatedForCompartment(entry.key)} gal',
                        ),
                      ],
                    ),
                  ),
                );
              }),

              if (state.exceedsTruckCapacity)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.warning, color: Colors.orange),
                    title: Text('Truck capacity exceeded'),
                    subtitle: Text(
                      'This is a non-blocking capacity warning.',
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: state.status == ShipmentWizardStatus.loading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                      state.status == ShipmentWizardStatus.loading
                          ? null
                          : () {
                        context.read<ShipmentWizardBloc>().add(
                          const PlanShipment(),
                        );
                      },
                      child: state.status == ShipmentWizardStatus.loading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Text('Plan Shipment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _driverName(ShipmentWizardState state) {
    for (final driver in state.availableDrivers) {
      if ((driver['id'] as num).toInt() == state.selectedDriverId) {
        return driver['name'].toString();
      }
    }
    return '-';
  }

  String _terminalName(ShipmentWizardState state) {
    for (final terminal in state.availableTerminals) {
      if ((terminal['id'] as num).toInt() == state.selectedTerminalId) {
        return terminal['name'].toString();
      }
    }
    return '-';
  }
}

class _ShipmentProgressHeader extends StatelessWidget {
  const _ShipmentProgressHeader();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _step('1', 'Orders', primary),
          Expanded(child: Divider(color: primary)),
          _step('2', 'Truck', primary),
          Expanded(child: Divider(color: primary)),
          _step('3', 'Load', primary),
          Expanded(child: Divider(color: primary)),
          _step('4', 'Review', primary, active: true),
        ],
      ),
    );
  }

  Widget _step(
      String number,
      String label,
      Color primary, {
        bool active = false,
      }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: primary,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
