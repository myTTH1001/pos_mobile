// lib/features/products/data/datasources/product_remote_datasource.dart
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/product_model.dart';

abstract class ProductRemoteDatasource {
  Future<ProductListResult> getProducts({
    String? search,
    double? minPrice,
    double? maxPrice,
    int limit,
    int offset,
  });
  Future<ProductModel> getProduct(int id);
  Future<ProductModel> createProduct(CreateProductRequest req);
  Future<ProductModel> updateProduct(int id, UpdateProductRequest req);
  Future<void> deleteProduct(int id);
  Future<UploadImageResult> uploadImage(String filePath);
}

class ProductListResult {
  final int total;
  final List<ProductModel> items;
  final bool hasMore;

  const ProductListResult({
    required this.total,
    required this.items,
    required this.hasMore,
  });
}

class UploadImageResult {
  final String filename;
  final String url;
  const UploadImageResult({required this.filename, required this.url});
}

class CreateProductRequest {
  final String name;
  final double price;
  final String? unit;
  final String? image;
  const CreateProductRequest({
    required this.name,
    required this.price,
    this.unit,
    this.image,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    if (unit != null) 'unit': unit,
    if (image != null) 'image': image,
  };
}

class UpdateProductRequest {
  final String? name;
  final double? price;
  final String? unit;
  final String? image;
  const UpdateProductRequest({this.name, this.price, this.unit, this.image});

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (price != null) 'price': price,
    if (unit != null) 'unit': unit,
    if (image != null) 'image': image,
  };
}

class ProductRemoteDatasourceImpl implements ProductRemoteDatasource {
  final Dio _dio = DioClient.instance.dio;

  @override
  Future<ProductListResult> getProducts({
    String? search,
    double? minPrice,
    double? maxPrice,
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _dio.get(
      ApiConstants.products,
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (search != null && search.isNotEmpty) 'search': search,
        // ignore: use_null_aware_elements
        if (minPrice != null) 'min_price': minPrice,
        // ignore: use_null_aware_elements
        if (maxPrice != null) 'max_price': maxPrice,
      },
    );
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return ProductListResult(
      total: data['total'] as int? ?? items.length,
      items: items,
      hasMore: data['has_more'] as bool? ?? false,
    );
  }

  @override
  Future<ProductModel> getProduct(int id) async {
    final res = await _dio.get('${ApiConstants.products}/$id');
    return ProductModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<ProductModel> createProduct(CreateProductRequest req) async {
    final res = await _dio.post(ApiConstants.products, data: req.toJson());
    return ProductModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<ProductModel> updateProduct(int id, UpdateProductRequest req) async {
    final res = await _dio.put(
      '${ApiConstants.products}/$id',
      data: req.toJson(),
    );
    return ProductModel.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteProduct(int id) async {
    await _dio.delete('${ApiConstants.products}/$id');
  }

  @override
  Future<UploadImageResult> uploadImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post(
      '${ApiConstants.products}/upload-image',
      data: formData,
    );
    final data = res.data as Map<String, dynamic>;
    return UploadImageResult(
      filename: data['filename'] as String,
      url: data['url'] as String,
    );
  }
}
