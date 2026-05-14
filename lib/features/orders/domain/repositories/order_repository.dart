import '../entities/order_entity.dart';

abstract class OrderRepository {
  /// Tạo draft order — backend trả về order với id
  Future<Order> createOrder(List<OrderItem> items);

  /// Confirm order + trừ kho — cần payment_method
  Future<Order> confirmOrder(int orderId, String paymentMethod);

  /// Tạo invoice (thanh toán)
  Future<Order> payOrder(int orderId, String paymentMethod);
}
