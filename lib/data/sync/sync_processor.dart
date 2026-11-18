import 'dart:async';

import '../../domain/sync/sync_api.dart';
import '../dao/outbox_dao.dart';

class SyncProcessor {
  SyncProcessor({required OutboxDao outboxDao, required SyncApi syncApi})
    : _outboxDao = outboxDao,
      _syncApi = syncApi;

  final OutboxDao _outboxDao;
  final SyncApi _syncApi;

  bool _isProcessing = false;
  bool _initialized = false;

  static const int _maxAttempts = 5;

  Future<void> processPendingEvents() async {
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      if (!_initialized) {
        await _outboxDao.resetInterruptedEvents();
        _initialized = true;
      }

      final events = await _outboxDao.getPendingEvents();

      for (final event in events) {
        await _processEvent(event);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processEvent(Map<String, Object?> event) async {
    final id = (event['id'] as num).toInt();
    final entityType = event['entity_type'] as String;
    final operation = event['operation'] as String;
    final clientId = event['client_id'] as String;
    final entityId = (event['entity_id'] as num).toInt();

    final payload = _outboxDao.decodePayload(event['payload_json'] as String);

    if (entityType == 'SHIPMENT' && operation == 'PLAN') {
      final dependencyStatus = await _checkShipmentDependencies(entityId);

      if (dependencyStatus == 'CONFLICT') {
        await _outboxDao.markConflict(
          id,
          error: 'Shipment contains an order with a sync conflict.',
        );
        return;
      }

      if (dependencyStatus != 'READY') return;
    }

    await _outboxDao.markSyncing(id);

    var attempts = (event['attempts'] as num?)?.toInt() ?? 0;

    while (attempts < _maxAttempts) {
      try {
        final response = await _sendEvent(
          entityType: entityType,
          operation: operation,
          clientId: clientId,
          entityId: entityId,
          payload: payload,
        );

        if (response.isSuccess) {
          await _outboxDao.markSynced(id);
          return;
        }

        if (response.isConflict) {
          if (entityType == 'ORDER' && operation == 'SUBMIT') {
            await _outboxDao.markOrderCancelled(clientId);
          }

          await _outboxDao.markConflict(
            id,
            error: response.message ?? 'Server conflict.',
          );
          return;
        }

        if (!response.isServerError) {
          await _outboxDao.markFailed(
            id,
            attempts: attempts + 1,
            error: response.message ?? 'Request failed.',
          );
          return;
        }

        attempts++;

        if (attempts >= _maxAttempts) {
          await _outboxDao.markFailed(
            id,
            attempts: attempts,
            error: response.message ?? 'Maximum retry attempts reached.',
          );
          return;
        }

        await _outboxDao.markRetry(
          id,
          attempts: attempts,
          error: response.message ?? 'Server error. Retrying.',
        );

        await Future.delayed(Duration(seconds: 1 << (attempts - 1)));

        await _outboxDao.markSyncing(id);
      } catch (error) {
        attempts++;

        if (attempts >= _maxAttempts) {
          await _outboxDao.markFailed(
            id,
            attempts: attempts,
            error: error.toString(),
          );
          return;
        }

        await _outboxDao.markRetry(
          id,
          attempts: attempts,
          error: error.toString(),
        );

        await Future.delayed(Duration(seconds: 1 << (attempts - 1)));

        await _outboxDao.markSyncing(id);
      }
    }
  }

  Future<String> _checkShipmentDependencies(int shipmentId) async {
    final payload = await _outboxDao.buildShipmentPayload(shipmentId);
    final loads = payload['loads'] as List<dynamic>;

    final orderClientIds = loads
        .whereType<Map>()
        .map((load) => load['orderClientId']?.toString())
        .whereType<String>()
        .toSet();

    for (final orderClientId in orderClientIds) {
      final status = await _outboxDao.getOrderOutboxStatus(orderClientId);

      if (status == null || status == 'SYNCED') continue;

      if (status == 'CONFLICT' || status == 'FAILED') {
        return 'CONFLICT';
      }

      return 'WAIT';
    }

    return 'READY';
  }

  Future<SyncApiResponse> _sendEvent({
    required String entityType,
    required String operation,
    required String clientId,
    required int entityId,
    required Map<String, dynamic> payload,
  }) async {
    if (entityType == 'ORDER' && operation == 'SUBMIT') {
      return _syncApi.syncOrder(payload: payload);
    }

    if (entityType == 'SHIPMENT' && operation == 'PLAN') {
      final shipmentPayload = await _outboxDao.buildShipmentPayload(entityId);

      return _syncApi.syncShipment(payload: shipmentPayload);
    }

    if (entityType == 'SHIPMENT' && operation == 'CANCEL') {
      final shipmentClientId = payload['client_id']?.toString() ?? clientId;

      return _syncApi.cancelShipment(
        shipmentClientId: shipmentClientId,
        idempotencyKey: clientId,
      );
    }

    if (entityType == 'ORDER' && operation == 'CANCEL') {
      final orderClientId =
          payload['order_client_id']?.toString() ??
          payload['client_id']?.toString() ??
          clientId;

      return _syncApi.cancelOrder(
        orderClientId: orderClientId,
        idempotencyKey: clientId,
      );
    }

    throw StateError('Unsupported outbox event: $entityType / $operation');
  }
}
