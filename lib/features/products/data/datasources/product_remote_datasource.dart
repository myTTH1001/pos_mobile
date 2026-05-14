// lib/features/products/data/datasources/product_remote_datasource.dart
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/product_model.dart';

abstract class ProductRemoteDatasource {
  Future<List<ProductModel>> getProducts({String? search});
}

class ProductRemoteDatasourceImpl implements ProductRemoteDatasource {
  final Dio _dio = DioClient.instance.dio;

  @override
  Future<List<ProductModel>> getProducts({String? search}) async {
    final res = await _dio.get(
      ApiConstants.products,
      queryParameters: {
        'limit': 100,
        'offset': 0,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    final data = res.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
