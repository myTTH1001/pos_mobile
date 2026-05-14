// lib/features/products/domain/repositories/product_repository.dart
import '../entities/product_entity.dart';

abstract class ProductRepository {
  Future<List<ProductEntity>> getProducts({String? search});
}
