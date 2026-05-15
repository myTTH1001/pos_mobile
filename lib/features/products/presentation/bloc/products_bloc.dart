// lib/features/products/presentation/bloc/products_bloc.dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/product_repository_impl.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';

// ─── Events ──────────────────────────────────────────────────────────────────

abstract class ProductsEvent extends Equatable {
  const ProductsEvent();
  @override
  List<Object?> get props => [];
}

class ProductsLoadRequested extends ProductsEvent {
  const ProductsLoadRequested({this.refresh = false});
  final bool refresh;
  @override
  List<Object?> get props => [refresh];
}

class ProductsLoadMore extends ProductsEvent {
  const ProductsLoadMore();
}

class ProductsSearchChanged extends ProductsEvent {
  const ProductsSearchChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

class ProductCreateRequested extends ProductsEvent {
  const ProductCreateRequested({
    required this.name,
    required this.price,
    this.unit,
    this.imagePath,
  });
  final String name;
  final double price;
  final String? unit;
  final String? imagePath; // local file path, sẽ upload trước
  @override
  List<Object?> get props => [name, price, unit, imagePath];
}

class ProductUpdateRequested extends ProductsEvent {
  const ProductUpdateRequested({
    required this.id,
    this.name,
    this.price,
    this.unit,
    this.imagePath, // null = không đổi ảnh
    this.clearImage, // true = xóa ảnh
  });
  final int id;
  final String? name;
  final double? price;
  final String? unit;
  final String? imagePath;
  final bool? clearImage;
  @override
  List<Object?> get props => [id, name, price, unit, imagePath, clearImage];
}

class ProductDeleteRequested extends ProductsEvent {
  const ProductDeleteRequested(this.id);
  final int id;
  @override
  List<Object?> get props => [id];
}

// ─── State ───────────────────────────────────────────────────────────────────

enum ProductsStatus { initial, loading, success, loadingMore, failure }

enum ProductsActionStatus { idle, loading, success, failure }

class ProductsState extends Equatable {
  const ProductsState({
    this.status = ProductsStatus.initial,
    this.products = const [],
    this.total = 0,
    this.hasMore = false,
    this.query = '',
    this.errorMessage,
    this.actionStatus = ProductsActionStatus.idle,
    this.actionError,
    this.lastActionProduct,
  });

  final ProductsStatus status;
  final List<ProductEntity> products;
  final int total;
  final bool hasMore;
  final String query;
  final String? errorMessage;

  // Dùng cho create/update/delete feedback
  final ProductsActionStatus actionStatus;
  final String? actionError;
  final ProductEntity? lastActionProduct; // sản phẩm vừa create/update

  ProductsState copyWith({
    ProductsStatus? status,
    List<ProductEntity>? products,
    int? total,
    bool? hasMore,
    String? query,
    String? errorMessage,
    ProductsActionStatus? actionStatus,
    String? actionError,
    ProductEntity? lastActionProduct,
  }) => ProductsState(
    status: status ?? this.status,
    products: products ?? this.products,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    query: query ?? this.query,
    errorMessage: errorMessage ?? this.errorMessage,
    actionStatus: actionStatus ?? this.actionStatus,
    actionError: actionError ?? this.actionError,
    lastActionProduct: lastActionProduct ?? this.lastActionProduct,
  );

  @override
  List<Object?> get props => [
    status,
    products,
    total,
    hasMore,
    query,
    errorMessage,
    actionStatus,
    actionError,
    lastActionProduct,
  ];
}

// ─── Bloc ────────────────────────────────────────────────────────────────────

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  ProductsBloc({ProductRepository? repo})
    : _repo = repo ?? ProductRepositoryImpl(),
      super(const ProductsState()) {
    on<ProductsLoadRequested>(_onLoad);
    on<ProductsLoadMore>(_onLoadMore);
    on<ProductsSearchChanged>(_onSearch);
    on<ProductCreateRequested>(_onCreate);
    on<ProductUpdateRequested>(_onUpdate);
    on<ProductDeleteRequested>(_onDelete);
  }

  final ProductRepository _repo;
  static const _pageSize = 20;

  // ── Load / Refresh ────────────────────────────────────────────────────────

  Future<void> _onLoad(
    ProductsLoadRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(status: ProductsStatus.loading));
    try {
      final page = await _repo.getProducts(
        search: state.query.isEmpty ? null : state.query,
        limit: _pageSize,
        offset: 0,
      );
      emit(
        state.copyWith(
          status: ProductsStatus.success,
          products: page.items,
          total: page.total,
          hasMore: page.hasMore,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: ProductsStatus.failure, errorMessage: _clean(e)),
      );
    }
  }

  // ── Load More (pagination) ────────────────────────────────────────────────

  Future<void> _onLoadMore(
    ProductsLoadMore event,
    Emitter<ProductsState> emit,
  ) async {
    if (!state.hasMore || state.status == ProductsStatus.loadingMore) return;
    emit(state.copyWith(status: ProductsStatus.loadingMore));
    try {
      final page = await _repo.getProducts(
        search: state.query.isEmpty ? null : state.query,
        limit: _pageSize,
        offset: state.products.length,
      );
      emit(
        state.copyWith(
          status: ProductsStatus.success,
          products: [...state.products, ...page.items],
          total: page.total,
          hasMore: page.hasMore,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ProductsStatus.success)); // giữ data cũ
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> _onSearch(
    ProductsSearchChanged event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(query: event.query, status: ProductsStatus.loading));
    try {
      final page = await _repo.getProducts(
        search: event.query.isEmpty ? null : event.query,
        limit: _pageSize,
        offset: 0,
      );
      emit(
        state.copyWith(
          status: ProductsStatus.success,
          products: page.items,
          total: page.total,
          hasMore: page.hasMore,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: ProductsStatus.failure, errorMessage: _clean(e)),
      );
    }
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<void> _onCreate(
    ProductCreateRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ProductsActionStatus.loading));
    try {
      String? imageUrl;
      if (event.imagePath != null) {
        imageUrl = await _repo.uploadImage(event.imagePath!);
      }

      final product = await _repo.createProduct(
        name: event.name,
        price: event.price,
        unit: event.unit,
        image: imageUrl,
      );

      emit(
        state.copyWith(
          actionStatus: ProductsActionStatus.success,
          lastActionProduct: product,
          // prepend vào đầu list
          products: [product, ...state.products],
          total: state.total + 1,
          actionError: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: ProductsActionStatus.failure,
          actionError: _clean(e),
        ),
      );
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<void> _onUpdate(
    ProductUpdateRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ProductsActionStatus.loading));
    try {
      String? imageUrl;
      if (event.imagePath != null) {
        imageUrl = await _repo.uploadImage(event.imagePath!);
      } else if (event.clearImage == true) {
        imageUrl = '';
      }

      final product = await _repo.updateProduct(
        event.id,
        name: event.name,
        price: event.price,
        unit: event.unit,
        image: imageUrl,
      );

      final updated = state.products
          .map((p) => p.id == product.id ? product : p)
          .toList();

      emit(
        state.copyWith(
          actionStatus: ProductsActionStatus.success,
          lastActionProduct: product,
          products: updated,
          actionError: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: ProductsActionStatus.failure,
          actionError: _clean(e),
        ),
      );
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _onDelete(
    ProductDeleteRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(actionStatus: ProductsActionStatus.loading));
    try {
      await _repo.deleteProduct(event.id);
      final updated = state.products.where((p) => p.id != event.id).toList();
      emit(
        state.copyWith(
          actionStatus: ProductsActionStatus.success,
          products: updated,
          total: state.total - 1,
          actionError: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: ProductsActionStatus.failure,
          actionError: _clean(e),
        ),
      );
    }
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
}
