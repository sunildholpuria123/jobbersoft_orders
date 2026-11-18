abstract class SyncApi {
  Future<SyncApiResponse> syncOrder({required Map<String, dynamic> payload});

  Future<SyncApiResponse> syncShipment({required Map<String, dynamic> payload});

  Future<SyncApiResponse> cancelShipment({
    required String shipmentClientId,
    required String idempotencyKey,
  });

  Future<SyncApiResponse> cancelOrder({
    required String orderClientId,
    required String idempotencyKey,
  });
}

class SyncApiResponse {
  final int statusCode;
  final String? serverId;
  final String? message;

  const SyncApiResponse({
    required this.statusCode,
    this.serverId,
    this.message,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isConflict => statusCode == 409;
  bool get isServerError => statusCode >= 500;
}
