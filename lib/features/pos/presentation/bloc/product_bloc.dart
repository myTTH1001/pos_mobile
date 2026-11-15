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
    this.hasMore = false,
  });

  final ProductStatus status;
  final List<ProductEntity> products;
  final List<ProductEntity> filteredProducts;
  final String query;
  final String? errorMessage;
  final bool hasMore;

  ProductState copyWith({
    bool? hasMore,
    ProductStatus? status,
    List<ProductEntity>? products,
    List<ProductEntity>? filteredProducts,
    String? query,
    String? errorMessage,
  }) => ProductState(
    hasMore: hasMore ?? this.hasMore,
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
    hasMore,
  ];
}

// ── Bloc ──────────────────────────────────────────────────────────────────────
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  ProductBloc({ProductRepository? repo})
    : _repo = repo ?? ProductRepositoryImpl(),
      super(const ProductState()) {
    on<ProductLoadRequested>(_onLoad);
    on<ProductSearchChanged>(_onSearch);
    on<ProductNextPage>((event, emit) => _loadPage(emit, append: true));
  }

  final ProductRepository _repo;

  int _generation = 0;
  bool _loadingMore = false;
  Future<void> _onLoad(
    ProductLoadRequested event,
    Emitter<ProductState> emit,
  ) => _loadPage(emit);

  Future<void> _onSearch(
    ProductSearchChanged event,
    Emitter<ProductState> emit,
  ) async {
    emit(state.copyWith(query: event.query));
    await _loadPage(emit);
  }

  Future<void> _loadPage(
    Emitter<ProductState> emit, {
    bool append = false,
  }) async {
    if (append &&
        (_loadingMore ||
            !state.hasMore ||
            state.status == ProductStatus.loading)) {
      return;
    }
    final generation = append ? _generation : ++_generation;
    final query = state.query;
    final existing = append ? state.products : <ProductEntity>[];
    if (append) {
      _loadingMore = true;
    } else {
      emit(state.copyWith(status: ProductStatus.loading));
    }
    try {
      final page = await _repo.getProducts(
        search: query.isEmpty ? null : query,
        limit: 40,
        offset: existing.length,
      );
      if (generation != _generation) return;
      final products = [...existing, ...page.items];
      emit(
        state.copyWith(
          status: ProductStatus.success,
          products: products,
          filteredProducts: products,
          hasMore: page.hasMore,
        ),
      );
    } catch (error) {
      if (generation == _generation) {
        emit(
          state.copyWith(
            status: ProductStatus.failure,
            errorMessage: error.toString().replaceFirst('Exception: ', ''),
          ),
        );
      }
    } finally {
      if (append) _loadingMore = false;
    }
  }
}

class ProductNextPage extends ProductEvent {
  const ProductNextPage();
}
