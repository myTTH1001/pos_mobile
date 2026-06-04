import 'package:dio/dio.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_datasource.dart';

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl({OrderRemoteDatasource? remote})
    : _remote = remote ?? OrderRemoteDatasourceImpl();

  final OrderRemoteDatasource _remote;

  @override
  Future<Order> createOrder(List<OrderItem> items) async {
    try {
      print(
        'Creating order with items: ${items.map((e) => e.toString()).toList()}',
      );
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
      );
      return result.toEntity();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Order> confirmOrder(int orderId, String paymentMethod) async {
    try {
      final result = await _remote.confirmOrder(orderId, paymentMethod);
      return result.toEntity();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Order> payOrder(int orderId, String paymentMethod) async {
    try {
      final result = await _remote.payOrder(orderId, paymentMethod);
      return result.toEntity();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    final msg = e.response?.data?['detail'] as String?;
    return Exception(msg ?? 'Lỗi kết nối. Vui lòng thử lại.');
  }
}
