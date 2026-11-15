import '../../../../core/network/api_error.dart';
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
  Future<ProductListPage> getProducts({
    String? search,
    double? minPrice,
    double? maxPrice,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final result = await _remote.getProducts(
        search: search,
        minPrice: minPrice,
        maxPrice: maxPrice,
        limit: limit,
        offset: offset,
      );
      return ProductListPage(
        total: result.total,
        items: result.items.map((m) => m.toEntity()).toList(),
        hasMore: result.hasMore,
      );
    } on DioException catch (e) {
      final msg = apiError(e);
      throw Exception(msg);
    }
  }

  // Giữ compat với ProductBloc của POS (chỉ cần list)
  Future<List<ProductEntity>> getProductsList({String? search}) async {
    final page = await getProducts(search: search, limit: 100);
    return page.items;
  }

  @override
  Future<ProductEntity> createProduct({
    required String name,
    required double price,
    String? unit,
    String? image,
  }) async {
    try {
      final model = await _remote.createProduct(
        CreateProductRequest(
          name: name,
          price: price,
          unit: unit,
          image: image,
        ),
      );
      return model.toEntity();
    } on DioException catch (e) {
      final msg = apiError(e);
      throw Exception(msg);
    }
  }

  @override
  Future<ProductEntity> updateProduct(
    int id, {
    String? name,
    double? price,
    String? unit,
    String? image,
  }) async {
    try {
      final model = await _remote.updateProduct(
        id,
        UpdateProductRequest(
          name: name,
          price: price,
          unit: unit,
          image: image,
        ),
      );
      return model.toEntity();
    } on DioException catch (e) {
      final msg = apiError(e);
      throw Exception(msg);
    }
  }

  @override
  Future<void> deleteProduct(int id) async {
    try {
      await _remote.deleteProduct(id);
    } on DioException catch (e) {
      final msg = apiError(e);
      throw Exception(msg);
    }
  }

  @override
  Future<String> uploadImage(String filePath) async {
    try {
      final result = await _remote.uploadImage(filePath);
      return result.url;
    } on DioException catch (e) {
      final msg = apiError(e);
      throw Exception(msg);
    }
  }
}
