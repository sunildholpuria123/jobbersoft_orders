
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jobbersoft_orders/features/shipments/pages/shipment_load_allocation_step_page.dart';

import '../bloc/shipment_wizard_bloc.dart';
import '../bloc/shipment_wizard_event.dart';
import '../bloc/shipment_wizard_state.dart';

class ShipmentTruckDriverStepPage extends StatelessWidget {
  const ShipmentTruckDriverStepPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Shipment')),
      body: BlocBuilder<ShipmentWizardBloc, ShipmentWizardState>(
        builder: (context, state) {
          if (state.status == ShipmentWizardStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == ShipmentWizardStatus.failure) {
            return Center(
              child: Text(state.errorMessage ?? 'Unable to load resources'),
            );
          }

          return Column(
            children: [
              const _ProgressHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Select Truck',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),

                    if (state.availableTrucks.isEmpty)
                      const Text('No available trucks for this date.'),

                    RadioGroup<int>(
                      groupValue: state.selectedTruckId,
                      onChanged: (value) {
                        if (value != null) {
                          context.read<ShipmentWizardBloc>().add(
                            SelectShipmentTruck(value),
                          );
                        }
                      },
                      child: Column(
                        children: state.availableTrucks.map((truck) {
                          final id = (truck['id'] as num).toInt();
                          final capacity =
                              (truck['total_capacity'] as num?)
                                  ?.toInt() ??
                                  0;
                          final compartments =
                              (truck['compartment_count'] as num?)
                                  ?.toInt() ??
                                  0;

                          return Card(
                            child: RadioListTile<int>(
                              value: id,
                              title: Text(
                                truck['plate_no']?.toString() ?? '',
                              ),
                              subtitle: Text(
                                '$compartments compartments · '
                                    '$capacity gal capacity',
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    if (state.exceedsTruckCapacity) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Text(
                          'Selected ${state.totalSelectedGallons} gal exceeds '
                              'truck capacity ${state.selectedTruckCapacity} gal. '
                              'Some lines will need a partial-load reason.',
                          style: const TextStyle(color: Colors.deepOrange),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Text(
                      'Select Driver',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),

                    if (state.selectedTruckId == null)
                      const Text('Select a truck first.'),

                    if (state.selectedTruckId != null &&
                        state.availableDrivers.isEmpty)
                      const Text('No available drivers for this date.'),

                    if (state.selectedTruckId != null)
                      RadioGroup<int>(
                        groupValue: state.selectedDriverId,
                        onChanged: (value) {
                          if (value != null) {
                            context.read<ShipmentWizardBloc>().add(
                              SelectShipmentDriver(value),
                            );
                          }
                        },
                        child: Column(
                          children: state.availableDrivers.map((driver) {
                            final id = (driver['id'] as num).toInt();

                            return Card(
                              child: RadioListTile<int>(
                                value: id,
                                title: Text(
                                  driver['name']?.toString() ?? '',
                                ),
                                subtitle: Text(
                                  'License expiry: '
                                      '${driver['license_expiry'] ?? '-'}',
                                ),
                              ),
                            );
                          }).toList(),
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
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(

                          onPressed: state.selectedTruckId == null ||
                              state.selectedDriverId == null
                              ? null
                              : () {
                            final bloc = context.read<ShipmentWizardBloc>();
                            bloc.add(const LoadShipmentAllocationData());

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: bloc,
                                  child: const ShipmentLoadAllocationStepPage(),
                                ),
                              ),
                            );
                          },

                          child: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _StepIndicator(number: '1', label: 'Orders', active: true),
          Expanded(child: Divider()),
          _StepIndicator(number: '2', label: 'Truck', active: true),
          Expanded(child: Divider()),
          _StepIndicator(number: '3', label: 'Load', active: false),
          Expanded(child: Divider()),
          _StepIndicator(number: '4', label: 'Review', active: false),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final String number;
  final String label;
  final bool active;

  const _StepIndicator({
    required this.number,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor:
          active ? Theme.of(context).colorScheme.primary : Colors.grey,
          child: Text(
            number,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
