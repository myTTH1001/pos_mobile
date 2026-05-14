import 'package:equatable/equatable.dart';

class ProductEntity extends Equatable {
  const ProductEntity({
    required this.id,
    required this.name,
    required this.price,
    this.unit,
    this.image,
    this.stock,
  });

  final int id;
  final String name;
  final double price;
  final String? unit;
  final String? image;
  final int? stock;

  @override
  List<Object?> get props => [id, name, price];
}
