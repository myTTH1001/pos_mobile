import 'package:equatable/equatable.dart';

class OrderItem extends Equatable {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  final int productId;
  final String productName;
  final int quantity;
  final double price;

  double get subtotal => price * quantity;

  OrderItem copyWith({int? quantity}) => OrderItem(
    productId: productId,
    productName: productName,
    quantity: quantity ?? this.quantity,
    price: price,
  );

  @override
  List<Object?> get props => [productId, quantity, price];
}

class Order extends Equatable {
  const Order({
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
  final List<OrderItem> items;
  final DateTime createdAt;
  final OrderInvoice? invoice;

  @override
  List<Object?> get props => [id, status, total];
}

class OrderInvoice extends Equatable {
  const OrderInvoice({
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

  @override
  List<Object?> get props => [id, status];
}
