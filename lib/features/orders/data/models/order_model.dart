import '../../domain/entities/order_entity.dart';

class OrderItemModel {
  const OrderItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  final int productId;
  final String productName;
  final int quantity;
  final double price;

  factory OrderItemModel.fromJson(Map<String, dynamic> j) => OrderItemModel(
    productId: j['product_id'] as int,
    productName:
        (j['product'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    quantity: j['quantity'] as int,
    price: _toDouble(j['price']),
  );

  OrderItem toEntity() => OrderItem(
    productId: productId,
    productName: productName,
    quantity: quantity,
    price: price,
  );
}

class OrderInvoiceModel {
  const OrderInvoiceModel({
    required this.id,
    required this.status,
    required this.paymentMethod,
    required this.total,
    this.paidAt,
  });

  final int id;
  final String status;
  final String paymentMethod;
  final double total;
  final DateTime? paidAt;

  factory OrderInvoiceModel.fromJson(Map<String, dynamic> j) =>
      OrderInvoiceModel(
        id: j['id'] as int,
        status: j['status'] as String,
        paymentMethod: j['payment_method'] as String,
        total: _toDouble(j['total']),
        paidAt: j['paid_at'] != null
            ? DateTime.tryParse(j['paid_at'] as String)
            : null,
      );

  OrderInvoice toEntity() => OrderInvoice(
    id: id,
    status: status,
    paymentMethod: paymentMethod,
    total: total,
    paidAt: paidAt,
  );
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.status,
    required this.total,
    required this.items,
    required this.createdAt,
    this.invoice,
  });

  final int id;
  final String status;
  final double total;
  final List<OrderItemModel> items;
  final DateTime createdAt;
  final OrderInvoiceModel? invoice;

  factory OrderModel.fromJson(Map<String, dynamic> j) => OrderModel(
    id: j['id'] as int,
    status: j['status'] as String,
    total: _toDouble(j['total']),
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    items: (j['items'] as List<dynamic>? ?? [])
        .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    invoice: j['invoice'] != null
        ? OrderInvoiceModel.fromJson(j['invoice'] as Map<String, dynamic>)
        : null,
  );

  Order toEntity() => Order(
    id: id,
    status: status,
    total: total,
    createdAt: createdAt,
    items: items.map((e) => e.toEntity()).toList(),
    invoice: invoice?.toEntity(),
  );
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
