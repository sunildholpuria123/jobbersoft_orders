import 'dart:async';
import 'dart:math';

import '../../domain/sync/sync_api.dart';

class FakeSyncApi implements SyncApi {
  FakeSyncApi({Random? random}) : _random = random ?? Random();

  final Random _random;

  // Keeps successful responses to simulate server-side idempotency.
  final Map<String, String> _processedRequests = {};

  // Orders rejected with 409 are treated as unavailable for shipments.
  final Set<String> _cancelledOrderClientIds = {};

  Future<void> _simulateNetwork() async {
    final delay = 300 + _random.nextInt(1201);
    await Future.delayed(Duration(milliseconds: delay));
  }

  SyncApiResponse _serverError() {
    return const SyncApiResponse(
      statusCode: 500,
      message: 'Simulated server error. Please retry.',
    );
  }

  String? _clientId(Map<String, dynamic> payload) {
    return (payload['clientId'] ?? payload['client_id'])?.toString();
  }

  @override
  Future<SyncApiResponse> syncOrder({
    required Map<String, dynamic> payload,
  }) async {
    await _simulateNetwork();

    final clientId = _clientId(payload);
    if (clientId == null || clientId.isEmpty) {
      return const SyncApiResponse(
        statusCode: 400,
        message: 'Missing order clientId.',
      );
    }

    final existing = _processedRequests[clientId];
    if (existing != null) {
      return SyncApiResponse(
        statusCode: 200,
        serverId: existing,
        message: 'Already processed.',
      );
    }

    final storeId = payload['storeId'] ?? payload['store_id'];

    // Deterministic conflict scenario for testing.
    if (storeId?.toString() == '13') {
      _cancelledOrderClientIds.add(clientId);
      return const SyncApiResponse(
        statusCode: 409,
        message: 'Store is unavailable. Order rejected.',
      );
    }

    if (_random.nextDouble() < 0.20) {
      return _serverError();
    }

    final serverId = 'SRV-ORDER-${_random.nextInt(900000) + 100000}';
    _processedRequests[clientId] = serverId;

    return SyncApiResponse(
      statusCode: 201,
      serverId: serverId,
      message: 'Order synced successfully.',
    );
  }

  @override
  Future<SyncApiResponse> syncShipment({
    required Map<String, dynamic> payload,
  }) async {
    await _simulateNetwork();

    final clientId = _clientId(payload);
    if (clientId == null || clientId.isEmpty) {
      return const SyncApiResponse(
        statusCode: 400,
        message: 'Missing shipment clientId.',
      );
    }

    final existing = _processedRequests[clientId];
    if (existing != null) {
      return SyncApiResponse(
        statusCode: 200,
        serverId: existing,
        message: 'Already processed.',
      );
    }

    final orderIds = <String>[];

    final rawOrderIds =
        payload['orderClientIds'] ?? payload['order_client_ids'];

    if (rawOrderIds is List) {
      orderIds.addAll(rawOrderIds.map((id) => id.toString()));
    }

    final rawLoads = payload['loads'];
    if (rawLoads is List) {
      for (final load in rawLoads) {
        if (load is Map) {
          final orderId = load['orderClientId'] ?? load['order_client_id'];
          if (orderId != null) {
            orderIds.add(orderId.toString());
          }
        }
      }
    }

    if (orderIds.any(_cancelledOrderClientIds.contains)) {
      return const SyncApiResponse(
        statusCode: 409,
        message: 'Shipment contains an unavailable order.',
      );
    }

    if (_random.nextDouble() < 0.20) {
      return _serverError();
    }

    final serverId = 'SRV-SHIPMENT-${_random.nextInt(900000) + 100000}';
    _processedRequests[clientId] = serverId;

    return SyncApiResponse(
      statusCode: 201,
      serverId: serverId,
      message: 'Shipment synced successfully.',
    );
  }

  @override
  Future<SyncApiResponse> cancelShipment({
    required String shipmentClientId,
    required String idempotencyKey,
  }) async {
    await _simulateNetwork();

    final existing = _processedRequests[idempotencyKey];
    if (existing != null) {
      return SyncApiResponse(
        statusCode: 200,
        serverId: existing,
        message: 'Cancellation already processed.',
      );
    }

    if (_random.nextDouble() < 0.20) {
      return _serverError();
    }

    _processedRequests[idempotencyKey] = shipmentClientId;

    return SyncApiResponse(
      statusCode: 200,
      serverId: shipmentClientId,
      message: 'Shipment cancelled successfully.',
    );
  }

  @override
  Future<SyncApiResponse> cancelOrder({
    required String orderClientId,
    required String idempotencyKey,
  }) async {
    await _simulateNetwork();

    final existing = _processedRequests[idempotencyKey];
    if (existing != null) {
      return SyncApiResponse(
        statusCode: 200,
        serverId: existing,
        message: 'Cancellation already processed.',
      );
    }

    if (_random.nextDouble() < 0.20) {
      return _serverError();
    }

    _cancelledOrderClientIds.add(orderClientId);
    _processedRequests[idempotencyKey] = orderClientId;

    return SyncApiResponse(
      statusCode: 200,
      serverId: orderClientId,
      message: 'Order cancelled successfully.',
    );
  }
}
