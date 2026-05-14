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
    final res = await _dio.post(
      '${ApiConstants.invoices}/$orderId',
      data: {'payment_method': paymentMethod},
    );
    // backend trả về invoice — load lại order từ confirm result đã có
    // Trả về order đã confirm (đã có invoice)
    return OrderModel.fromJson(res.data as Map<String, dynamic>);
  }
}
