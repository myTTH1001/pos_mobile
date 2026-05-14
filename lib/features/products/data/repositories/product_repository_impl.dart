// lib/features/products/data/repositories/product_repository_impl.dart
import 'package:dio/dio.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({ProductRemoteDatasource? remote})
    : _remote = remote ?? ProductRemoteDatasourceImpl();

  final ProductRemoteDatasource _remote;

  @override
  Future<List<ProductEntity>> getProducts({String? search}) async {
    try {
      final models = await _remote.getProducts(search: search);
      return models.map((m) => m.toEntity()).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] as String?;
      throw Exception(msg ?? 'Không thể tải danh sách sản phẩm');
    }
  }
}
