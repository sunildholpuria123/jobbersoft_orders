import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../data/dao/outbox_dao.dart';
import '../../data/sync/sync_processor.dart';
import '../orders/bloc/orders_list_bloc.dart';
import '../orders/pages/orders_list_page.dart';
import '../shipments/pages/shipment_list_page.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _hasConnection = false;

  int _selectedIndex = 0;
  Map<String, int> _syncCounts = {};
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();

    _refreshSyncCounts();
    _initializeConnectivity();
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> _initializeConnectivity() async {
    final current = await _connectivity.checkConnectivity();

    if (!mounted) return;

    _hasConnection = _isConnected(current);

    if (_hasConnection) {
      _runSync(showMessage: false);
    }

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final connected = _isConnected(results);

      if (connected && !_hasConnection) {
        _runSync(showMessage: false);
      }

      _hasConnection = connected;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshSyncCounts() async {
    final counts = await getIt<OutboxDao>().getStatusCounts();

    if (!mounted) return;
    setState(() => _syncCounts = counts);
  }

  Future<void> _runSync({bool showMessage = true}) async {
    final connectivity = await _connectivity.checkConnectivity();

    if (!_isConnected(connectivity)) {
      await _refreshSyncCounts();

      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No internet connection. Sync will resume when online.',
            ),
          ),
        );
      }

      return;
    }
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      await getIt<SyncProcessor>().processPendingEvents();
      await _refreshSyncCounts();

      if (showMessage && mounted) {
        final pending = _syncCounts['pending'] ?? 0;
        final conflicts = _syncCounts['conflict'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              conflicts > 0
                  ? 'Sync completed with $conflicts conflict(s).'
                  : pending > 0
                  ? '$pending event(s) still pending.'
                  : 'All events synced successfully.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted && showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _syncCounts['pending'] ?? 0;
    final conflicts = _syncCounts['conflict'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JobberSoft Orders'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                conflicts > 0
                    ? '$conflicts conflict(s)'
                    : pending > 0
                    ? '$pending pending'
                    : 'Synced',
                style: TextStyle(
                  color: conflicts > 0
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sync now',
            onPressed: _isSyncing ? null : () => _runSync(),
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          BlocProvider(
            create: (_) => getIt<OrdersListBloc>(),
            child: const OrdersListPage(),
          ),
          const ShipmentListPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: 'Shipments',
          ),
        ],
      ),
    );
  }
}
