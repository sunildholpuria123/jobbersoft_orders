import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../bloc/order_bloc.dart';
import '../bloc/orders_list_bloc.dart';
import '../bloc/orders_list_event.dart';
import '../bloc/orders_list_state.dart';
import 'order_step_one_page.dart';

class OrdersListPage extends StatefulWidget {
  const OrdersListPage({super.key});

  @override
  State<OrdersListPage> createState() => _OrdersListPageState();
}

class _OrdersListPageState extends State<OrdersListPage> {
  String _status = 'ALL';
  String _storeQuery = '';
  DateTime? _selectedDate;

  String? get _dateFilter => _selectedDate?.toIso8601String().split('T').first;

  void _loadOrders() {
    context.read<OrdersListBloc>().add(
      LoadOrders(
        status: _status,
        shipmentDate: _dateFilter,
        storeQuery: _storeQuery,
      ),
    );
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '—';

    final date = DateTime.tryParse(value);
    if (date == null) return value;

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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

    return '${weekdays[date.weekday - 1]} '
        '${months[date.month - 1]} ${date.day}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'SUBMITTED':
        return Colors.blue;
      case 'SCHEDULED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      case 'DRAFT':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _newOrder() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OrderWizardHost()));

    if (mounted) _loadOrders();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(onPressed: _loadOrders, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        icon: const Icon(Icons.add),
        label: const Text('New Order'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search store',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _storeQuery = value;
                _loadOrders();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All')),
                      DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                      DropdownMenuItem(
                        value: 'SUBMITTED',
                        child: Text('Submitted'),
                      ),
                      DropdownMenuItem(
                        value: 'SCHEDULED',
                        child: Text('Scheduled'),
                      ),
                      DropdownMenuItem(
                        value: 'CANCELLED',
                        child: Text('Cancelled'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _status = value;
                      _loadOrders();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Filter by date',
                  icon: const Icon(Icons.calendar_month),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (date != null) {
                      _selectedDate = date;
                      _loadOrders();
                    }
                  },
                ),
                if (_selectedDate != null)
                  IconButton(
                    tooltip: 'Clear date',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _selectedDate = null;
                      _loadOrders();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BlocBuilder<OrdersListBloc, OrdersListState>(
              builder: (context, state) {
                if (state.status == OrdersListStatus.loading ||
                    state.status == OrdersListStatus.initial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == OrdersListStatus.failure) {
                  return Center(
                    child: Text(state.errorMessage ?? 'Failed to load orders'),
                  );
                }

                if (state.orders.isEmpty) {
                  return const Center(child: Text('No orders found'));
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadOrders(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: state.orders.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final order = state.orders[index];
                      final status = order['status']?.toString() ?? '';
                      final isDraft = status == 'DRAFT';

                      final orderCode = isDraft
                          ? '—'
                          : order['code']?.toString() ?? '—';

                      final storeName =
                          order['store_name']?.toString() ?? 'Unknown store';

                      final date = _formatDate(
                        order['shipment_date']?.toString(),
                      );

                      final time = order['delivery_time']?.toString() ?? '—';

                      final gallons = order['total_gallons'] ?? 0;

                      final step = order['wizard_step'] ?? 1;

                      return InkWell(
                        onTap: isDraft
                            ? () {
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) => OrderWizardHost(
                                          draftId: order['id'] as int,
                                        ),
                                      ),
                                    )
                                    .then((_) => _loadOrders());
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$orderCode  $storeName',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isDraft ? 'DRAFT · Step $step' : status,
                                    style: TextStyle(
                                      color: _statusColor(status),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$date · $time',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    '$gallons gal',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class OrderWizardHost extends StatelessWidget {
  final int? draftId;

  const OrderWizardHost({super.key, this.draftId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OrderBloc>(),
      child: OrderStepOnePage(draftId: draftId),
    );
  }
}
