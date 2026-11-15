import 'package:dio/dio.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_datasource.dart';

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl({OrderRemoteDatasource? remote})
    : _remote = remote ?? OrderRemoteDatasourceImpl();

  final OrderRemoteDatasource _remote;

  @override
  Future<Order> createOrder(
    List<OrderItem> items, {
    Map<String, dynamic> options = const {},
  }) async {
    try {
      final result = await _remote.createOrder(
        items
            .map(
              (e) => {
                'product_id': e.productId,
                'quantity': e.quantity,
                'price': e.price,
              },
            )
            .toList(),
        options: options,
      );
      return result.toEntity();
    } on DioException catch (_) {
      rethrow;
    }
  }

  @override
  Future<Order> confirmOrder(int orderId, String paymentMethod) async {
    try {
      final result = await _remote.confirmOrder(orderId, paymentMethod);
      return result.toEntity();
    } on DioException catch (_) {
      rethrow;
    }
  }

  @override
  Future<Order> payOrder(int orderId, String paymentMethod) async {
    try {
      final result = await _remote.payOrder(orderId, paymentMethod);
      return result.toEntity();
    } on DioException catch (_) {
      rethrow;
    }
  }
}
