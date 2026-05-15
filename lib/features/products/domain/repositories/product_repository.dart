// lib/features/products/domain/repositories/product_repository.dart
import '../entities/product_entity.dart';

class ProductListPage {
  final int total;
  final List<ProductEntity> items;
  final bool hasMore;
  const ProductListPage({
    required this.total,
    required this.items,
    required this.hasMore,
  });
}

abstract class ProductRepository {
  Future<ProductListPage> getProducts({
    String? search,
    double? minPrice,
    double? maxPrice,
    int limit,
    int offset,
  });

  Future<ProductEntity> createProduct({
    required String name,
    required double price,
    String? unit,
    String? image,
  });

  Future<ProductEntity> updateProduct(
    int id, {
    String? name,
    double? price,
    String? unit,
    String? image,
  });

  Future<void> deleteProduct(int id);
  Future<String> uploadImage(String filePath);
}
