// lib/features/products/data/models/product_model.dart
import '../../domain/entities/product_entity.dart';

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.unit,
    this.image,
  });

  final int id;
  final String name;
  final double price;
  final String? unit;
  final String? image;

  factory ProductModel.fromJson(Map<String, dynamic> j) => ProductModel(
    id: j['id'] as int,
    name: j['name'] as String,
    price: _toDouble(j['price']),
    unit: j['unit'] as String?,
    image: j['image'] as String?,
  );

  ProductEntity toEntity() =>
      ProductEntity(id: id, name: name, price: price, unit: unit, image: image);
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
