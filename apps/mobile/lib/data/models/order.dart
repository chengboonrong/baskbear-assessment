import 'cart.dart';

enum OrderStatus {
  pending, confirmed, preparing, ready, completed, cancelled;
  static OrderStatus fromJson(String raw) => OrderStatus.values.firstWhere(
        (s) => s.name.toUpperCase() == raw.toUpperCase(),
        orElse: () => OrderStatus.pending,
      );
}

enum FulfilmentType { dineIn, takeaway, delivery;
  String get apiName => switch (this) {
        FulfilmentType.dineIn => 'DINE_IN',
        FulfilmentType.takeaway => 'TAKEAWAY',
        FulfilmentType.delivery => 'DELIVERY',
      };
  static FulfilmentType fromApi(String raw) => switch (raw) {
        'DINE_IN' => FulfilmentType.dineIn,
        'DELIVERY' => FulfilmentType.delivery,
        _ => FulfilmentType.takeaway,
      };
}

class OrderDto {
  OrderDto({
    required this.id, required this.orderNumber, required this.status,
    required this.fulfilmentType, required this.subtotalMinor,
    required this.discountMinor, required this.taxMinor, required this.totalMinor,
    required this.currencyCode, required this.placedAt,
    required this.items, required this.statusEvents,
  });

  final int id;
  final String orderNumber;
  final OrderStatus status;
  final FulfilmentType fulfilmentType;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
  final String currencyCode;
  final DateTime placedAt;
  final List<OrderItemDto> items;
  final List<OrderStatusEventDto> statusEvents;

  factory OrderDto.fromJson(Map<String, dynamic> j) => OrderDto(
        id: (j['id'] as num).toInt(),
        orderNumber: j['orderNumber'] as String,
        status: OrderStatus.fromJson(j['status'] as String),
        fulfilmentType: FulfilmentType.fromApi(j['fulfilmentType'] as String),
        subtotalMinor: (j['subtotalMinor'] as num).toInt(),
        discountMinor: (j['discountMinor'] as num).toInt(),
        taxMinor: (j['taxMinor'] as num).toInt(),
        totalMinor: (j['totalMinor'] as num).toInt(),
        currencyCode: j['currencyCode'] as String,
        placedAt: DateTime.parse(j['placedAt'] as String),
        items: ((j['items'] as List<dynamic>?) ?? const [])
            .map((e) => OrderItemDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        statusEvents: ((j['statusEvents'] as List<dynamic>?) ?? const [])
            .map((e) => OrderStatusEventDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class OrderItemDto {
  OrderItemDto({
    required this.id, required this.sku, required this.nameSnapshot,
    required this.quantity, required this.unitPriceMinor,
    required this.lineTotalMinor, required this.customisations,
  });
  final int id;
  final String sku;
  final String nameSnapshot;
  final int quantity;
  final int unitPriceMinor;
  final int lineTotalMinor;
  final List<CustomisationChoiceDto> customisations;

  factory OrderItemDto.fromJson(Map<String, dynamic> j) {
    final raw = (j['customisationsSnapshotJson'] as List<dynamic>?) ?? const [];
    return OrderItemDto(
      id: (j['id'] as num).toInt(),
      sku: j['sku'] as String,
      nameSnapshot: j['nameSnapshot'] as String,
      quantity: (j['quantity'] as num).toInt(),
      unitPriceMinor: (j['unitPriceMinor'] as num).toInt(),
      lineTotalMinor: (j['lineTotalMinor'] as num).toInt(),
      customisations: raw
          .map((e) => CustomisationChoiceDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OrderStatusEventDto {
  OrderStatusEventDto({required this.status, required this.occurredAt, required this.source});
  final OrderStatus status;
  final DateTime occurredAt;
  final String source;
  factory OrderStatusEventDto.fromJson(Map<String, dynamic> j) => OrderStatusEventDto(
        status: OrderStatus.fromJson(j['status'] as String),
        occurredAt: DateTime.parse(j['occurredAt'] as String),
        source: j['source'] as String,
      );
}
