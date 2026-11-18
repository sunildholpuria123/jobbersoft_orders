
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jobbersoft_orders/features/shipments/pages/shipment_terminal_bol_step_page.dart';

import '../bloc/shipment_wizard_bloc.dart';
import '../bloc/shipment_wizard_event.dart';
import '../bloc/shipment_wizard_state.dart';
import '../widgets/shipment_progress_header.dart';

class ShipmentLoadAllocationStepPage extends StatelessWidget {
  const ShipmentLoadAllocationStepPage({super.key});

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
            title: const Text('Allocate Loads'),
          ),
          body: Column(
            children: [
              const ShipmentProgressHeader(currentStep: 3),
              Expanded(
                child: state.compartments.isEmpty
                    ? const Center(
                  child: Text('No compartments available.'),
                )
                    : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummary(context, state),
                    const SizedBox(height: 16),
                    ...state.compartments.map(
                          (compartment) =>
                          _buildCompartment(
                            context,
                            state,
                            compartment,
                          ),
                    ),
                    const SizedBox(height: 16),
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

                      onPressed: state.hasValidAllocations
                          ? () {
                        final bloc = context.read<ShipmentWizardBloc>();

                        bloc.add(const LoadShipmentTerminals());

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: bloc,
                              child: const ShipmentTerminalBolStepPage(),
                            ),
                          ),
                        );
                      }
                          : null,

                      child: const Text('Next'),
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


  Widget _buildSummary(
      BuildContext context,
      ShipmentWizardState state,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Allocation Summary',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Selected orders: ${state.selectedOrderIds.length}'),
            Text('Total requested: ${state.totalSelectedGallons} gal'),
            const SizedBox(height: 8),
            ...state.orderLines.map((line) {
              final lineId = line['order_line_id'] as int;
              final requested =
              (line['requested_gallons'] as num).toInt();
              final allocated = state.allocatedForOrderLine(lineId);
              final remaining = requested - allocated;
              final needsReason = allocated < requested;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${line['product_code']} · ${line['order_code']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Allocated: $allocated / $requested gal · '
                          'Remaining: $remaining gal',
                    ),
                    if (needsReason) ...[
                      const SizedBox(height: 6),
                      TextFormField(
                        key: ValueKey('summary-reason-$lineId'),
                        initialValue:
                        state.partialLoadReasons[lineId] ?? '',
                        decoration: InputDecoration(
                          labelText: allocated == 0
                              ? 'Reason for zero allocation'
                              : 'Reason for partial allocation',
                          hintText: 'Enter at least 5 characters',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          context.read<ShipmentWizardBloc>().add(
                            UpdatePartialLoadReason(
                              orderLineId: lineId,
                              reason: value,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCompartment(
      BuildContext context,
      ShipmentWizardState state,
      Map<String, Object?> compartment,
      ) {
    final compartmentId = compartment['id'] as int;
    final capacity = (compartment['capacity_gal'] as num).toInt();
    final selectedProduct =
    state.compartmentProducts[compartmentId];
    final allocated =
    state.allocatedForCompartment(compartmentId);
    final products = state.productTotals;

    final selectedProductExists = products.any(
          (p) => p['product_id'] == selectedProduct,
    );

    final matchingLines = selectedProduct == null
        ? <Map<String, Object?>>[]
        : state.orderLines.where((line) {
      return line['product_id'] == selectedProduct;
    }).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compartment ${compartment['position']}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text('Capacity: $capacity gal'),
            Text('Allocated: $allocated gal'),
            if (allocated > capacity)
              const Text(
                'Capacity exceeded',
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue:
              selectedProductExists ? selectedProduct : null,
              decoration: const InputDecoration(
                labelText: 'Select product',
                border: OutlineInputBorder(),
              ),
              items: products.map((product) {
                final id = product['product_id'] as int;
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(
                    '${product['product_code']} - '
                        '${product['product_name']}',
                  ),
                );
              }).toList(),
              onChanged: (productId) {
                if (productId == null) return;
                context.read<ShipmentWizardBloc>().add(
                  SelectCompartmentProduct(
                    compartmentId: compartmentId,
                    productId: productId,
                  ),
                );
              },
            ),
            if (selectedProduct != null) ...[
              const SizedBox(height: 12),
              ...matchingLines.map(
                    (line) => _buildOrderLine(
                  context,
                  state,
                  compartmentId,
                  line,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderLine(
      BuildContext context,
      ShipmentWizardState state,
      int compartmentId,
      Map<String, Object?> line,
      ) {
    final lineId = line['order_line_id'] as int;
    final requested = (line['requested_gallons'] as num).toInt();
    final currentAllocation =
        state.allocations[compartmentId]?[lineId] ?? 0;
    final totalAllocated = state.allocatedForOrderLine(lineId);
    final remaining = requested - totalAllocated;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${line['order_code']} · ${line['store_name']}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'Requested: $requested gal | '
                'Allocated: $totalAllocated gal | '
                'Remaining: $remaining gal',
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('allocation-$compartmentId-$lineId'),
            initialValue:
            currentAllocation == 0 ? '' : '$currentAllocation',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Gallons to allocate',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              final gallons = int.tryParse(value) ?? 0;
              context.read<ShipmentWizardBloc>().add(
                UpdateLineAllocation(
                  compartmentId: compartmentId,
                  orderLineId: lineId,
                  gallons: gallons,
                ),
              );
            },
          ),
          if (remaining > 0) ...[
            const SizedBox(height: 6),
            TextFormField(
              key: ValueKey('reason-$lineId'),
              initialValue: state.partialLoadReasons[lineId] ?? '',
              decoration: const InputDecoration(
                labelText: 'Reason for partial / zero allocation',
                hintText: 'Enter at least 5 characters',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                context.read<ShipmentWizardBloc>().add(
                  UpdatePartialLoadReason(
                    orderLineId: lineId,
                    reason: value,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
