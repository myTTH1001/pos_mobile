// lib/features/pos/presentation/bloc/product_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../../../products/data/repositories/product_repository_impl.dart';

// ── Events ────────────────────────────────────────────────────────────────────
abstract class ProductEvent extends Equatable {
  const ProductEvent();
  @override
  List<Object?> get props => [];
}

class ProductLoadRequested extends ProductEvent {
  const ProductLoadRequested();
}

class ProductSearchChanged extends ProductEvent {
  const ProductSearchChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

// ── State ─────────────────────────────────────────────────────────────────────
enum ProductStatus { initial, loading, success, failure }

class ProductState extends Equatable {
  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const [],
    this.filteredProducts = const [],
    this.query = '',
    this.errorMessage,
  });

  final ProductStatus status;
  final List<ProductEntity> products;
  final List<ProductEntity> filteredProducts;
  final String query;
  final String? errorMessage;

  ProductState copyWith({
    ProductStatus? status,
    List<ProductEntity>? products,
    List<ProductEntity>? filteredProducts,
    String? query,
    String? errorMessage,
  }) => ProductState(
    status: status ?? this.status,
    products: products ?? this.products,
    filteredProducts: filteredProducts ?? this.filteredProducts,
    query: query ?? this.query,
    errorMessage: errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [
    status,
    products,
    filteredProducts,
    query,
    errorMessage,
  ];
}

// ── Bloc ──────────────────────────────────────────────────────────────────────
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  ProductBloc({ProductRepository? repo})
    : _repo = repo ?? ProductRepositoryImpl(),
      super(const ProductState()) {
    on<ProductLoadRequested>(_onLoad);
    on<ProductSearchChanged>(_onSearch);
  }

  final ProductRepository _repo;

  Future<void> _onLoad(
    ProductLoadRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(state.copyWith(status: ProductStatus.loading));
    try {
      // Dùng getProducts với limit lớn để lấy toàn bộ cho POS grid
      final page = await _repo.getProducts(
        search: state.query.isEmpty ? null : state.query,
        limit: 200,
        offset: 0,
      );
      emit(
        state.copyWith(
          status: ProductStatus.success,
          products: page.items,
          filteredProducts: page.items,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ProductStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void _onSearch(ProductSearchChanged event, Emitter<ProductState> emit) {
    // Search client-side để không gọi API mỗi keystroke trên POS
    final q = event.query.toLowerCase();
    final filtered = state.products
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
    emit(state.copyWith(query: event.query, filteredProducts: filtered));
  }
}
