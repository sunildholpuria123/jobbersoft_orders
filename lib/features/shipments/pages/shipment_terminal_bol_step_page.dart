
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jobbersoft_orders/features/shipments/pages/shipment_review_step_page.dart';

import '../bloc/shipment_wizard_bloc.dart';
import '../bloc/shipment_wizard_event.dart';
import '../bloc/shipment_wizard_state.dart';
import '../widgets/shipment_progress_header.dart';

class ShipmentTerminalBolStepPage extends StatefulWidget {
  const ShipmentTerminalBolStepPage({super.key});

  @override
  State<ShipmentTerminalBolStepPage> createState() =>
      _ShipmentTerminalBolStepPageState();
}

class _ShipmentTerminalBolStepPageState
    extends State<ShipmentTerminalBolStepPage> {
  final TextEditingController _bolController = TextEditingController();

  @override
  void dispose() {
    _bolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShipmentWizardBloc, ShipmentWizardState>(
      listener: (context, state) {
        if (ModalRoute.of(context)?.isCurrent != true) return;
        if (state.errorMessage != null &&
            state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        if (state.status == ShipmentWizardStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Terminal & BOL'),
          ),
          body: Column(
            children: [
              const ShipmentProgressHeader(currentStep: 4),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Shipment Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _summaryRow('Shipment date', state.shipmentDate),
                    _summaryRow(
                      'Truck',
                      state.selectedTruck?['plate_no']?.toString() ?? '-',
                    ),
                    _summaryRow(
                      'Driver',
                      _selectedDriverName(state),
                    ),
                    _summaryRow(
                      'Selected orders',
                      '${state.selectedOrderIds.length}',
                    ),
                    _summaryRow(
                      'Total gallons',
                      '${state.totalSelectedGallons} gal',
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<int>(
                      initialValue: state.availableTerminals.any(
                            (terminal) =>
                        terminal['id'] == state.selectedTerminalId,
                      )
                          ? state.selectedTerminalId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Select terminal *',
                        border: OutlineInputBorder(),
                      ),
                      items: state.availableTerminals.map((terminal) {
                        final id = (terminal['id'] as num).toInt();
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(terminal['name'].toString()),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id != null) {
                          context.read<ShipmentWizardBloc>().add(
                            SelectShipmentTerminal(id),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _bolController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'BOL number *',
                        hintText: 'BOL-12345',
                        border: const OutlineInputBorder(),
                        suffixIcon: state.isBolChecking
                            ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                            : IconButton(
                          icon: const Icon(Icons.verified_outlined),
                          tooltip: 'Validate BOL',
                          onPressed: () {
                            context.read<ShipmentWizardBloc>().add(
                              ValidateShipmentBolNumber(
                                _bolController.text,
                              ),
                            );
                          },
                        ),
                      ),
                      onChanged: (value) {
                        context.read<ShipmentWizardBloc>().add(
                          UpdateShipmentBolNumber(value),
                        );
                      },
                      onSubmitted: (value) {
                        context.read<ShipmentWizardBloc>().add(
                          ValidateShipmentBolNumber(value),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 20),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Debug: Force save failure'),
                      subtitle: const Text(
                        'Fail shipment save after loads are inserted to test rollback.',
                      ),
                      value: state.failShipmentSaveAfterLoads,
                      onChanged: (value) {
                        context.read<ShipmentWizardBloc>().add(
                          ToggleShipmentSaveFailure(value),
                        );
                      },
                    ),
                    if (state.isBolValid)
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 6),
                          Text(
                            'BOL number is available',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Required format: BOL- followed by 5 digits',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
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
                      onPressed: state.selectedTerminalId != null &&
                          state.isBolValid &&
                          !state.isBolChecking
                          ? () {

                        final wizardBloc = context.read<ShipmentWizardBloc>();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: wizardBloc,
                              child: const ShipmentReviewStepPage(),
                            ),
                          ),
                        );

                      }
                          : null,
                      child: const Text('Review'),
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

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
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

  String _selectedDriverName(ShipmentWizardState state) {
    for (final driver in state.availableDrivers) {
      if ((driver['id'] as num).toInt() == state.selectedDriverId) {
        return driver['name'].toString();
      }
    }
    return '-';
  }
}
