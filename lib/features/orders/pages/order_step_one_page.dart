import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../data/models/store_model.dart';
import '../../shipments/widgets/shipment_progress_header.dart';
import '../bloc/order_bloc.dart';
import '../bloc/order_event.dart';
import '../bloc/order_state.dart';
import '../bloc/order_validators.dart';
import '../bloc/tank_bloc.dart';
import '../bloc/tank_event.dart';
import 'order_step_two_page.dart';

class OrderStepOnePage extends StatefulWidget {
  final int? draftId;

  const OrderStepOnePage({super.key, this.draftId});

  @override
  State<OrderStepOnePage> createState() => _OrderStepOnePageState();
}

class _OrderStepOnePageState extends State<OrderStepOnePage> {
  final _storeController = TextEditingController();
  final _poController = TextEditingController();

  StoreModel? _selectedStore;
  DateTime? _shipmentDate;
  TimeOfDay? _deliveryTime;
  bool _initialized = false;
  bool _navigating = false;
  bool _creatingDraft = false;

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  String? get _timeError {
    if (_selectedStore == null || _deliveryTime == null) return null;

    return OrderValidators.validateDeliveryTime(
      store: _selectedStore!,
      time: _formatTime(_deliveryTime!),
    );
  }

  bool get _canContinue {
    return _selectedStore != null &&
        _shipmentDate != null &&
        _shipmentDate!.isBefore(
              DateTime.now().subtract(
                Duration(
                  hours: TimeOfDay.now().hour,
                  minutes: TimeOfDay.now().minute,
                ),
              ),
            ) ==
            false &&
        _deliveryTime != null &&
        _timeError == null &&
        OrderValidators.validatePoNumber(_poController.text) == null;
  }

  bool get _hasFormData {
    return _storeController.text.trim().isNotEmpty ||
        _selectedStore != null ||
        _shipmentDate != null ||
        _deliveryTime != null ||
        _poController.text.trim().isNotEmpty;
  }

  Future<bool> _confirmLeave() async {
    if (!_hasFormData) return true;

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('Your order is saved as a draft.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void initState() {
    super.initState();

    if (widget.draftId != null) {
      context.read<OrderBloc>().add(RestoreOrderDraft(orderId: widget.draftId));
    } /*else {
      context.read<OrderBloc>().add(const CreateOrderDraft());
    }*/
  }

  @override
  void dispose() {
    _storeController.dispose();
    _poController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _shipmentDate ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2),
    );

    if (selected != null) {
      setState(() => _shipmentDate = selected);
    }
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _deliveryTime ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (selected != null) {
      setState(() => _deliveryTime = selected);
    }
  }

  void _continue() {
    if (!_canContinue) return;

    _navigating = false;
    final bloc = context.read<OrderBloc>();

    bloc.add(
      SaveOrderStepOne(
        orderId: bloc.state.orderId!,
        store: _selectedStore!,
        shipmentDate: _shipmentDate!,
        deliveryTime: _formatTime(_deliveryTime!),
        poNumber: _poController.text.trim().isEmpty
            ? null
            : _poController.text.trim(),
      ),
    );
  }

  Future<void> _openStepTwo() async {
    if (_navigating || !mounted) return;

    _navigating = true;

    final orderState = context.read<OrderBloc>().state;
    final orderBloc = context.read<OrderBloc>();

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: orderBloc,
            child: BlocProvider(
              create: (_) => getIt<TankBloc>()
                ..add(
                  LoadTanks(
                    storeId: orderState.selectedStore!.id,
                    orderId: orderState.orderId!,
                  ),
                ),
              child: OrderStepTwoPage(
                storeId: orderState.selectedStore!.id,
                orderId: orderState.orderId!,
                storeName: orderState.selectedStore!.name,
              ),
            ),
          ),
        ),
      );
    } finally {
      _navigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldLeave = await _confirmLeave();

        if (!context.mounted) return;

        if (shouldLeave) {
          Navigator.of(context).pop();
        }
      },
      child: BlocListener<OrderBloc, OrderState>(
        listener: (context, state) {
          if (state.status == OrderStatus.success && state.currentStep == 2) {
            _openStepTwo();
          }

          if (state.status == OrderStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Something went wrong'),
              ),
            );
          }

          if (state.status == OrderStatus.success && !_initialized) {
            _initialized = true;
            _selectedStore = state.selectedStore;
            _shipmentDate = state.shipmentDate;
            _deliveryTime = state.deliveryTime.isEmpty
                ? null
                : TimeOfDay(
                    hour: int.parse(state.deliveryTime.split(':')[0]),
                    minute: int.parse(state.deliveryTime.split(':')[1]),
                  );

            _storeController.text = _selectedStore?.name ?? '';
            _poController.text = state.poNumber ?? '';

            setState(() {});
          }
        },
        child: Scaffold(
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
          body: BlocBuilder<OrderBloc, OrderState>(
            builder: (context, state) {
              if (state.status == OrderStatus.loading &&
                  (widget.draftId != null || _selectedStore != null)) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return SafeArea(
                child: Column(
                  children: [
                    ShipmentProgressHeader(
                      currentStep: 1,
                      labels: const ['Store & Schedule', 'Tanks', 'Review'],
                    ),
                    const Divider(height: 24),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          const Text('Store *'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _storeController,
                            decoration: const InputDecoration(
                              hintText: 'Search store',
                              suffixIcon: Icon(Icons.arrow_drop_down),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() => _selectedStore = null);
                              context.read<OrderBloc>().add(
                                SearchStores(value),
                              );
                            },
                          ),
                          if (_selectedStore != null) ...[
                            const SizedBox(height: 8),
                            Text(_selectedStore!.address),
                            Text(
                              'Delivery window '
                              '${_selectedStore!.deliveryOpen} – '
                              '${_selectedStore!.deliveryClose}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                          if (_selectedStore == null && state.stores.isNotEmpty)
                            ...state.stores.map(
                              (store) => ListTile(
                                title: Text(store.name),
                                subtitle: Text(store.address),

                                onTap: () {
                                  setState(() {
                                    _selectedStore = store;
                                    _storeController.text = store.name;
                                  });

                                  final bloc = context.read<OrderBloc>();

                                  if (bloc.state.orderId == null && !_creatingDraft) {
                                    _creatingDraft = true;
                                    bloc.add(CreateOrderDraft(store));
                                  }
                                },

                              ),
                            ),
                          const SizedBox(height: 24),
                          const Text('Shipment date *'),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _selectDate,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(
                              _shipmentDate == null
                                  ? 'Select delivery date'
                                  : '${_shipmentDate!.day}/'
                                        '${_shipmentDate!.month}/'
                                        '${_shipmentDate!.year}',
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Delivery time *'),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _selectTime,
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              _deliveryTime == null
                                  ? 'Select delivery time'
                                  : _formatTime(_deliveryTime!),
                            ),
                          ),
                          if (_timeError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _timeError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _poController,
                            maxLength: 20,
                            decoration: const InputDecoration(
                              labelText: 'PO number',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
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
                            onPressed: () async {
                              final shouldLeave = await _confirmLeave();

                              if (!context.mounted) return;

                              if (shouldLeave) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed:
                                _canContinue &&
                                    state.status != OrderStatus.saving
                                ? _continue
                                : null,
                            child: state.status == OrderStatus.saving
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
