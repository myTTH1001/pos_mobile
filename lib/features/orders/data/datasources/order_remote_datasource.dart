// lib/features/orders/data/datasources/order_remote_datasource.dart
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/order_model.dart';

abstract class OrderRemoteDatasource {
  Future<OrderModel> createOrder(List<Map<String, dynamic>> items);
  Future<OrderModel> confirmOrder(int orderId, String paymentMethod);
  Future<OrderModel> payOrder(int orderId, String paymentMethod);
}

class OrderRemoteDatasourceImpl implements OrderRemoteDatasource {
  final Dio _dio = DioClient.instance.dio;

  @override
  Future<OrderModel> createOrder(List<Map<String, dynamic>> items) async {
    final res = await _dio.post(ApiConstants.orders, data: {'items': items});
    return OrderModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<OrderModel> confirmOrder(int orderId, String paymentMethod) async {
    final res = await _dio.post(
      ApiConstants.orderConfirm(orderId),
      data: {'payment_method': paymentMethod},
    );
    return OrderModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<OrderModel> payOrder(int orderId, String paymentMethod) async {
    // Bước 1: Tạo invoice (backend trả về Invoice, không phải Order)
    await _dio.post(
      '${ApiConstants.invoices}/$orderId',
      data: {'payment_method': paymentMethod},
    );

    // Bước 2: Load lại order đầy đủ (có invoice embedded) để UI hiển thị đúng
    final orderRes = await _dio.get('${ApiConstants.orders}/$orderId');
    return OrderModel.fromJson(orderRes.data as Map<String, dynamic>);
  }
}
