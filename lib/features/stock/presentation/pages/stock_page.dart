// lib/features/stock/presentation/pages/stock_page.dart
//
// FIX: Sản phẩm mới tạo không hiển thị trong kho vì API /stock/ chỉ trả về
//      sản phẩm đã có bản ghi trong bảng stocks.
// SOLUTION: Gọi song song /products + /stock/, merge theo product_id.
//           Sản phẩm chưa có bản ghi kho → quantity = 0.
//
// THÊM MỚI: Summary bar — tổng SP / còn hàng / sắp hết / hết hàng

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class StockItem {
  const StockItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  final int productId;
  final String productName;
  final int quantity;

  // Merge constructor: product + optional stock record
  factory StockItem.fromMerge({
    required int productId,
    required String productName,
    required int quantity,
  }) => StockItem(
    productId: productId,
    productName: productName,
    quantity: quantity,
  );
}

class StockSummary {
  const StockSummary({
    required this.total,
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
  });

  final int total;
  final int inStock;
  final int lowStock;
  final int outOfStock;

  factory StockSummary.fromList(List<StockItem> items) {
    final total = items.length;
    final outOfStock = items.where((i) => i.quantity == 0).length;
    final lowStock = items
        .where((i) => i.quantity >= 1 && i.quantity <= 5)
        .length;
    final inStock = total - outOfStock - lowStock;
    return StockSummary(
      total: total,
      inStock: inStock,
      lowStock: lowStock,
      outOfStock: outOfStock,
    );
  }
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.type,
    required this.createdAt,
    this.note,
    this.transferRef,
  });

  final int id;
  final int productId;
  final int quantity;
  final String type;
  final DateTime createdAt;
  final String? note;
  final String? transferRef;

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
    id: j['id'] as int,
    productId: j['product_id'] as int,
    quantity: j['quantity'] as int,
    type: j['type'] as String,
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    note: j['note'] as String?,
    transferRef: j['transfer_ref'] as String?,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// REMOTE DATASOURCE
// ─────────────────────────────────────────────────────────────────────────────

class StockRemote {
  final Dio _dio = DioClient.instance.dio;

  /// Lấy tất cả sản phẩm của store (kể cả chưa có bản ghi kho)
  Future<List<Map<String, dynamic>>> _fetchAllProducts() async {
    final res = await _dio.get(
      ApiConstants.products,
      queryParameters: {'limit': 100, 'offset': 0},
    );
    final data = res.data as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  /// Lấy bản ghi tồn kho hiện có (chỉ sp đã có giao dịch)
  Future<List<Map<String, dynamic>>> _fetchStockRecords() async {
    final res = await _dio.get('${ApiConstants.stock}/');
    final list = res.data as List<dynamic>? ?? [];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Merge products + stock → trả về list đầy đủ, sp mới quantity=0
  Future<List<StockItem>> listStock() async {
    final results = await Future.wait([
      _fetchAllProducts(),
      _fetchStockRecords(),
    ]);

    final products = results[0];
    final stockRecords = results[1];

    // Build map: product_id → quantity
    final stockMap = <int, int>{};
    for (final s in stockRecords) {
      stockMap[s['product_id'] as int] = s['quantity'] as int? ?? 0;
    }

    return products.map((p) {
      final id = p['id'] as int;
      return StockItem.fromMerge(
        productId: id,
        productName: p['name'] as String? ?? '#$id',
        quantity: stockMap[id] ?? 0,
      );
    }).toList();
  }

  Future<List<StockMovement>> listMovements({
    int? productId,
    String? movementType,
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _dio.get(
      ApiConstants.stockMovements,
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (productId != null) 'product_id': productId,
        if (movementType != null) 'movement_type': movementType,
      },
    );
    final list = res.data as List<dynamic>? ?? [];
    return list
        .map((e) => StockMovement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> importStock(int productId, int quantity, {String? note}) async {
    await _dio.post(
      ApiConstants.stockImport,
      queryParameters: {
        'product_id': productId,
        'quantity': quantity,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  Future<void> adjustStock(int productId, int newQuantity) async {
    await _dio.post(
      ApiConstants.stockAdjust,
      queryParameters: {'product_id': productId, 'new_quantity': newQuantity},
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOC
// ─────────────────────────────────────────────────────────────────────────────

abstract class StockEvent {}

class StockLoadRequested extends StockEvent {
  StockLoadRequested({this.refresh = false});
  final bool refresh;
}

class MovementsLoadRequested extends StockEvent {
  MovementsLoadRequested({this.typeFilter, this.refresh = false});
  final String? typeFilter;
  final bool refresh;
}

class StockImportRequested extends StockEvent {
  StockImportRequested({
    required this.productId,
    required this.quantity,
    this.note,
  });
  final int productId;
  final int quantity;
  final String? note;
}

class StockAdjustRequested extends StockEvent {
  StockAdjustRequested({required this.productId, required this.newQuantity});
  final int productId;
  final int newQuantity;
}

class StockSearchChanged extends StockEvent {
  StockSearchChanged(this.query);
  final String query;
}

class StockFilterChanged extends StockEvent {
  StockFilterChanged(
    this.filter,
  ); // 'all' | 'in_stock' | 'low_stock' | 'out_of_stock'
  final String filter;
}

enum StockStatus { initial, loading, success, failure }

enum StockActionStatus { idle, loading, success, failure }

class StockState {
  const StockState({
    this.stockStatus = StockStatus.initial,
    this.movementsStatus = StockStatus.initial,
    this.stocks = const [],
    this.movements = const [],
    this.searchQuery = '',
    this.stockFilter = 'all',
    this.movementTypeFilter,
    this.errorMessage,
    this.actionStatus = StockActionStatus.idle,
    this.actionError,
  });

  final StockStatus stockStatus;
  final StockStatus movementsStatus;
  final List<StockItem> stocks;
  final List<StockMovement> movements;
  final String searchQuery;
  final String stockFilter; // 'all' | 'in_stock' | 'low_stock' | 'out_of_stock'
  final String? movementTypeFilter;
  final String? errorMessage;
  final StockActionStatus actionStatus;
  final String? actionError;

  StockSummary get summary => StockSummary.fromList(stocks);

  List<StockItem> get filteredStocks {
    var list = stocks;

    // Filter by status
    if (stockFilter == 'in_stock') {
      list = list.where((s) => s.quantity > 5).toList();
    } else if (stockFilter == 'low_stock') {
      list = list.where((s) => s.quantity >= 1 && s.quantity <= 5).toList();
    } else if (stockFilter == 'out_of_stock') {
      list = list.where((s) => s.quantity == 0).toList();
    }

    // Filter by search
    if (searchQuery.isNotEmpty) {
      list = list
          .where(
            (s) =>
                s.productName.toLowerCase().contains(searchQuery.toLowerCase()),
          )
          .toList();
    }

    return list;
  }

  StockState copyWith({
    StockStatus? stockStatus,
    StockStatus? movementsStatus,
    List<StockItem>? stocks,
    List<StockMovement>? movements,
    String? searchQuery,
    String? stockFilter,
    String? movementTypeFilter,
    bool clearTypeFilter = false,
    String? errorMessage,
    StockActionStatus? actionStatus,
    String? actionError,
    bool clearActionError = false,
  }) => StockState(
    stockStatus: stockStatus ?? this.stockStatus,
    movementsStatus: movementsStatus ?? this.movementsStatus,
    stocks: stocks ?? this.stocks,
    movements: movements ?? this.movements,
    searchQuery: searchQuery ?? this.searchQuery,
    stockFilter: stockFilter ?? this.stockFilter,
    movementTypeFilter: clearTypeFilter
        ? null
        : (movementTypeFilter ?? this.movementTypeFilter),
    errorMessage: errorMessage ?? this.errorMessage,
    actionStatus: actionStatus ?? this.actionStatus,
    actionError: clearActionError ? null : (actionError ?? this.actionError),
  );
}

class StockBloc extends Bloc<StockEvent, StockState> {
  StockBloc() : super(const StockState()) {
    on<StockLoadRequested>(_onStockLoad);
    on<MovementsLoadRequested>(_onMovementsLoad);
    on<StockImportRequested>(_onImport);
    on<StockAdjustRequested>(_onAdjust);
    on<StockSearchChanged>(_onSearch);
    on<StockFilterChanged>(_onFilterChanged);
  }

  final _remote = StockRemote();

  Future<void> _onStockLoad(
    StockLoadRequested event,
    Emitter<StockState> emit,
  ) async {
    emit(state.copyWith(stockStatus: StockStatus.loading));
    try {
      final stocks = await _remote.listStock();
      emit(state.copyWith(stockStatus: StockStatus.success, stocks: stocks));
    } catch (e) {
      emit(
        state.copyWith(
          stockStatus: StockStatus.failure,
          errorMessage: _clean(e),
        ),
      );
    }
  }

  Future<void> _onMovementsLoad(
    MovementsLoadRequested event,
    Emitter<StockState> emit,
  ) async {
    emit(
      state.copyWith(
        movementsStatus: StockStatus.loading,
        movementTypeFilter: event.typeFilter,
        clearTypeFilter: event.typeFilter == null && event.refresh,
      ),
    );
    try {
      final movements = await _remote.listMovements(
        movementType: event.typeFilter ?? state.movementTypeFilter,
        limit: 80,
      );
      emit(
        state.copyWith(
          movementsStatus: StockStatus.success,
          movements: movements,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          movementsStatus: StockStatus.failure,
          errorMessage: _clean(e),
        ),
      );
    }
  }

  Future<void> _onImport(
    StockImportRequested event,
    Emitter<StockState> emit,
  ) async {
    emit(state.copyWith(actionStatus: StockActionStatus.loading));
    try {
      await _remote.importStock(
        event.productId,
        event.quantity,
        note: event.note,
      );
      emit(
        state.copyWith(
          actionStatus: StockActionStatus.success,
          clearActionError: true,
        ),
      );
      add(StockLoadRequested());
      add(MovementsLoadRequested());
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: StockActionStatus.failure,
          actionError: _clean(e),
        ),
      );
    }
  }

  Future<void> _onAdjust(
    StockAdjustRequested event,
    Emitter<StockState> emit,
  ) async {
    emit(state.copyWith(actionStatus: StockActionStatus.loading));
    try {
      await _remote.adjustStock(event.productId, event.newQuantity);
      emit(
        state.copyWith(
          actionStatus: StockActionStatus.success,
          clearActionError: true,
        ),
      );
      add(StockLoadRequested());
      add(MovementsLoadRequested());
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: StockActionStatus.failure,
          actionError: _clean(e),
        ),
      );
    }
  }

  void _onSearch(StockSearchChanged event, Emitter<StockState> emit) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onFilterChanged(StockFilterChanged event, Emitter<StockState> emit) {
    emit(state.copyWith(stockFilter: event.filter));
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE ENTRY
// ─────────────────────────────────────────────────────────────────────────────

class StockPage extends StatelessWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StockBloc()
        ..add(StockLoadRequested())
        ..add(MovementsLoadRequested()),
      child: const _StockView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _StockView extends StatefulWidget {
  const _StockView();

  @override
  State<_StockView> createState() => _StockViewState();
}

class _StockViewState extends State<_StockView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StockBloc, StockState>(
      listenWhen: (p, c) => p.actionStatus != c.actionStatus,
      listener: (ctx, state) {
        if (state.actionStatus == StockActionStatus.success) {
          _showSnack(ctx, '✓ Cập nhật kho thành công', AppColors.success);
        } else if (state.actionStatus == StockActionStatus.failure) {
          _showSnack(
            ctx,
            state.actionError ?? 'Có lỗi xảy ra',
            AppColors.error,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _StockHeader(tabController: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [_StockInventoryTab(), _StockMovementsTab()],
              ),
            ),
          ],
        ),
        floatingActionButton: _StockFab(tabController: _tabController),
      ),
    );
  }

  void _showSnack(BuildContext ctx, String msg, Color color) {
    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _StockHeader extends StatelessWidget {
  const _StockHeader({required this.tabController});
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warehouse_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quản lý kho',
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      BlocBuilder<StockBloc, StockState>(
                        buildWhen: (p, c) =>
                            p.stocks.length != c.stocks.length ||
                            p.stockStatus != c.stockStatus,
                        builder: (_, state) => Text(
                          state.stockStatus == StockStatus.success
                              ? '${state.stocks.length} sản phẩm đang theo dõi'
                              : 'Tồn kho & lịch sử nhập xuất',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Refresh button
                BlocBuilder<StockBloc, StockState>(
                  buildWhen: (p, c) => p.stockStatus != c.stockStatus,
                  builder: (ctx, state) => IconButton(
                    onPressed: state.stockStatus == StockStatus.loading
                        ? null
                        : () => ctx.read<StockBloc>().add(StockLoadRequested()),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Tải lại',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Summary Cards ──────────────────────────────────────────
          BlocBuilder<StockBloc, StockState>(
            buildWhen: (p, c) =>
                p.stocks != c.stocks || p.stockStatus != c.stockStatus,
            builder: (ctx, state) {
              final isLoading =
                  state.stockStatus == StockStatus.loading ||
                  state.stockStatus == StockStatus.initial;
              final s = state.summary;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    _SummaryCard(
                      label: 'Tổng SP',
                      value: isLoading ? '–' : '${s.total}',
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF8B5CF6),
                      filter: 'all',
                      currentFilter: state.stockFilter,
                      onTap: () =>
                          ctx.read<StockBloc>().add(StockFilterChanged('all')),
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      label: 'Còn hàng',
                      value: isLoading ? '–' : '${s.inStock}',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      filter: 'in_stock',
                      currentFilter: state.stockFilter,
                      onTap: () => ctx.read<StockBloc>().add(
                        StockFilterChanged('in_stock'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      label: 'Sắp hết',
                      value: isLoading ? '–' : '${s.lowStock}',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      filter: 'low_stock',
                      currentFilter: state.stockFilter,
                      onTap: () => ctx.read<StockBloc>().add(
                        StockFilterChanged('low_stock'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SummaryCard(
                      label: 'Hết hàng',
                      value: isLoading ? '–' : '${s.outOfStock}',
                      icon: Icons.remove_circle_rounded,
                      color: AppColors.error,
                      filter: 'out_of_stock',
                      currentFilter: state.stockFilter,
                      onTap: () => ctx.read<StockBloc>().add(
                        StockFilterChanged('out_of_stock'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // TabBar
          TabBar(
            controller: tabController,
            labelColor: const Color(0xFF8B5CF6),
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: const Color(0xFF8B5CF6),
            indicatorWeight: 2.5,
            labelStyle: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Tồn kho'),
              Tab(text: 'Lịch sử'),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Summary Card (tap để filter) ─────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.filter,
    required this.currentFilter,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String filter;
  final String currentFilter;
  final VoidCallback onTap;

  bool get isActive => filter == currentFilter;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.12)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? color : AppColors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isActive ? color : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: isActive ? color : AppColors.textSecondary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: TỒN KHO
// ─────────────────────────────────────────────────────────────────────────────

class _StockInventoryTab extends StatefulWidget {
  const _StockInventoryTab();

  @override
  State<_StockInventoryTab> createState() => _StockInventoryTabState();
}

class _StockInventoryTabState extends State<_StockInventoryTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: BlocBuilder<StockBloc, StockState>(
            buildWhen: (p, c) => p.searchQuery != c.searchQuery,
            builder: (ctx, state) => TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  ctx.read<StockBloc>().add(StockSearchChanged(v)),
              decoration: InputDecoration(
                hintText: 'Tìm sản phẩm...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ctx.read<StockBloc>().add(StockSearchChanged(''));
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // List
        Expanded(
          child: BlocBuilder<StockBloc, StockState>(
            buildWhen: (p, c) =>
                p.stockStatus != c.stockStatus ||
                p.stocks != c.stocks ||
                p.searchQuery != c.searchQuery ||
                p.stockFilter != c.stockFilter,
            builder: (ctx, state) {
              if (state.stockStatus == StockStatus.initial ||
                  state.stockStatus == StockStatus.loading) {
                return const _LoadingBody();
              }
              if (state.stockStatus == StockStatus.failure) {
                return _ErrorBody(
                  message: state.errorMessage,
                  onRetry: () =>
                      ctx.read<StockBloc>().add(StockLoadRequested()),
                );
              }
              final items = state.filteredStocks;
              if (items.isEmpty) {
                final filterLabel = switch (state.stockFilter) {
                  'in_stock' => 'còn hàng',
                  'low_stock' => 'sắp hết hàng',
                  'out_of_stock' => 'hết hàng',
                  _ => '',
                };
                return _EmptyBody(
                  icon: Icons.warehouse_outlined,
                  message: state.searchQuery.isNotEmpty
                      ? 'Không tìm thấy "${state.searchQuery}"'
                      : filterLabel.isNotEmpty
                      ? 'Không có sản phẩm $filterLabel'
                      : 'Chưa có dữ liệu tồn kho',
                );
              }
              return RefreshIndicator(
                color: const Color(0xFF8B5CF6),
                onRefresh: () async =>
                    ctx.read<StockBloc>().add(StockLoadRequested()),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _StockItemCard(item: items[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StockItemCard extends StatelessWidget {
  const _StockItemCard({required this.item});
  final StockItem item;

  @override
  Widget build(BuildContext context) {
    final isLow = item.quantity >= 1 && item.quantity <= 5;
    final isOut = item.quantity == 0;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (isOut) {
      statusColor = AppColors.error;
      statusLabel = 'Hết hàng';
      statusIcon = Icons.remove_circle_outline;
    } else if (isLow) {
      statusColor = AppColors.warning;
      statusLabel = 'Sắp hết';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = AppColors.success;
      statusLabel = 'Còn hàng';
      statusIcon = Icons.check_circle_outline;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOut
              ? AppColors.error.withValues(alpha: 0.25)
              : isLow
              ? AppColors.warning.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showStockActions(context, item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quantity
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.quantity}',
                    style: GoogleFonts.dmSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isOut
                          ? AppColors.error
                          : isLow
                          ? AppColors.warning
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'đơn vị',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: LỊCH SỬ
// ─────────────────────────────────────────────────────────────────────────────

const _movementTypes = [
  (null, 'Tất cả'),
  ('IMPORT', 'Nhập kho'),
  ('SALE', 'Bán hàng'),
  ('RETURN', 'Trả hàng'),
  ('ADJUST', 'Điều chỉnh'),
  ('TRANSFER', 'Chuyển kho'),
];

class _StockMovementsTab extends StatelessWidget {
  const _StockMovementsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        BlocBuilder<StockBloc, StockState>(
          buildWhen: (p, c) => p.movementTypeFilter != c.movementTypeFilter,
          builder: (ctx, state) => Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _movementTypes.map((t) {
                  final (value, label) = t;
                  final selected = value == state.movementTypeFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) {
                        ctx.read<StockBloc>().add(
                          MovementsLoadRequested(typeFilter: value),
                        );
                      },
                      selectedColor: const Color(
                        0xFF8B5CF6,
                      ).withValues(alpha: 0.12),
                      checkmarkColor: const Color(0xFF8B5CF6),
                      labelStyle: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? const Color(0xFF8B5CF6)
                            : AppColors.textSecondary,
                      ),
                      backgroundColor: AppColors.surfaceAlt,
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF8B5CF6)
                            : Colors.transparent,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // List
        Expanded(
          child: BlocBuilder<StockBloc, StockState>(
            buildWhen: (p, c) =>
                p.movementsStatus != c.movementsStatus ||
                p.movements != c.movements,
            builder: (ctx, state) {
              if (state.movementsStatus == StockStatus.initial ||
                  state.movementsStatus == StockStatus.loading) {
                return const _LoadingBody();
              }
              if (state.movementsStatus == StockStatus.failure) {
                return _ErrorBody(
                  message: state.errorMessage,
                  onRetry: () =>
                      ctx.read<StockBloc>().add(MovementsLoadRequested()),
                );
              }
              if (state.movements.isEmpty) {
                return const _EmptyBody(
                  icon: Icons.receipt_long_outlined,
                  message: 'Chưa có lịch sử nhập xuất',
                );
              }
              return RefreshIndicator(
                color: const Color(0xFF8B5CF6),
                onRefresh: () async => ctx.read<StockBloc>().add(
                  MovementsLoadRequested(refresh: true),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.movements.length,
                  itemBuilder: (_, i) => _MovementCard(
                    movement: state.movements[i],
                    productName: _productNameFromStocks(
                      context,
                      state.movements[i].productId,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _productNameFromStocks(BuildContext context, int productId) {
    try {
      final stocks = context.read<StockBloc>().state.stocks;
      final found = stocks.where((s) => s.productId == productId);
      if (found.isNotEmpty) return found.first.productName;
    } catch (_) {}
    return '#$productId';
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement, required this.productName});
  final StockMovement movement;
  final String productName;

  @override
  Widget build(BuildContext context) {
    final cfg = _movementConfig(movement.type);
    final qtyStr = movement.quantity > 0
        ? '+${movement.quantity}'
        : '${movement.quantity}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cfg.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cfg.icon, color: cfg.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cfg.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cfg.label,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: cfg.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          productName,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    movement.note ?? _defaultNote(movement.type),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(movement.createdAt),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              qtyStr,
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: movement.quantity > 0
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB
// ─────────────────────────────────────────────────────────────────────────────

class _StockFab extends StatefulWidget {
  const _StockFab({required this.tabController});
  final TabController tabController;

  @override
  State<_StockFab> createState() => _StockFabState();
}

class _StockFabState extends State<_StockFab> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.tabController,
      builder: (_, _) {
        if (widget.tabController.index != 0) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_expanded) ...[
              _MiniAction(
                label: 'Điều chỉnh tồn',
                icon: Icons.tune_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  setState(() => _expanded = false);
                  _showAdjustSheet(context);
                },
              ),
              const SizedBox(height: 10),
              _MiniAction(
                label: 'Nhập kho',
                icon: Icons.add_box_rounded,
                color: AppColors.success,
                onTap: () {
                  setState(() => _expanded = false);
                  _showImportSheet(context);
                },
              ),
              const SizedBox(height: 12),
            ],
            FloatingActionButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              backgroundColor: const Color(0xFF8B5CF6),
              elevation: 3,
              child: AnimatedRotation(
                turns: _expanded ? 0.125 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _expanded ? Icons.close_rounded : Icons.add_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STOCK ACTION POPUP
// ─────────────────────────────────────────────────────────────────────────────

void _showStockActions(BuildContext context, StockItem item) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BlocProvider.value(
      value: context.read<StockBloc>(),
      child: _StockActionSheet(item: item),
    ),
  );
}

class _StockActionSheet extends StatelessWidget {
  const _StockActionSheet({required this.item});
  final StockItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Hiện tại: ${item.quantity} đơn vị',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          _ActionRow(
            icon: Icons.add_box_rounded,
            color: AppColors.success,
            label: 'Nhập kho',
            sublabel: 'Tăng số lượng tồn kho',
            onTap: () {
              Navigator.pop(context);
              _showImportSheet(context, preselected: item);
            },
          ),
          const SizedBox(height: 12),
          _ActionRow(
            icon: Icons.tune_rounded,
            color: const Color(0xFF8B5CF6),
            label: 'Điều chỉnh tồn',
            sublabel: 'Đặt lại số lượng chính xác',
            onTap: () {
              Navigator.pop(context);
              _showAdjustSheet(
                context,
                preselected: item,
                currentQty: item.quantity,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET: NHẬP KHO
// ─────────────────────────────────────────────────────────────────────────────

void _showImportSheet(BuildContext context, {StockItem? preselected}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BlocProvider.value(
      value: context.read<StockBloc>(),
      child: _ImportSheet(preselected: preselected),
    ),
  );
}

class _ImportSheet extends StatefulWidget {
  const _ImportSheet({this.preselected});
  final StockItem? preselected;

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  StockItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.preselected;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    final item = _selectedItem;
    if (item == null) return;
    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;
    ctx.read<StockBloc>().add(
      StockImportRequested(
        productId: item.productId,
        quantity: qty,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ),
    );
    Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final stocks = context.read<StockBloc>().state.stocks;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_box_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Nhập kho',
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SheetLabel('Sản phẩm'),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<StockItem>(
                value: _selectedItem,
                isExpanded: true,
                hint: Text(
                  'Chọn sản phẩm',
                  style: GoogleFonts.dmSans(
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                ),
                icon: const Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textSecondary,
                ),
                items: stocks
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          '${s.productName} (tồn: ${s.quantity})',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedItem = v),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SheetLabel('Số lượng nhập'),
          const SizedBox(height: 6),
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: () {
                  final v = int.tryParse(_qtyCtrl.text) ?? 1;
                  if (v > 1) _qtyCtrl.text = '${v - 1}';
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              _QtyButton(
                icon: Icons.add,
                color: AppColors.primary,
                onTap: () {
                  final v = int.tryParse(_qtyCtrl.text) ?? 0;
                  _qtyCtrl.text = '${v + 1}';
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SheetLabel('Ghi chú (tùy chọn)'),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'VD: Nhập từ nhà cung cấp ABC...',
              filled: true,
              fillColor: AppColors.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            style: GoogleFonts.dmSans(fontSize: 14),
          ),
          const SizedBox(height: 20),
          BlocBuilder<StockBloc, StockState>(
            buildWhen: (p, c) => p.actionStatus != c.actionStatus,
            builder: (ctx, state) => SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    (_selectedItem == null ||
                        state.actionStatus == StockActionStatus.loading)
                    ? null
                    : () => _submit(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: state.actionStatus == StockActionStatus.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Xác nhận nhập kho',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET: ĐIỀU CHỈNH TỒN KHO
// ─────────────────────────────────────────────────────────────────────────────

void _showAdjustSheet(
  BuildContext context, {
  StockItem? preselected,
  int? currentQty,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BlocProvider.value(
      value: context.read<StockBloc>(),
      child: _AdjustSheet(preselected: preselected, currentQty: currentQty),
    ),
  );
}

class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet({this.preselected, this.currentQty});
  final StockItem? preselected;
  final int? currentQty;

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _qtyCtrl = TextEditingController();
  StockItem? _selectedItem;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.preselected;
    if (widget.currentQty != null) _qtyCtrl.text = '${widget.currentQty}';
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    final item = _selectedItem;
    if (item == null) return;
    final qty = int.tryParse(_qtyCtrl.text);
    if (qty == null || qty < 0) return;
    ctx.read<StockBloc>().add(
      StockAdjustRequested(productId: item.productId, newQuantity: qty),
    );
    Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final stocks = context.read<StockBloc>().state.stocks;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Điều chỉnh tồn kho',
                      style: GoogleFonts.dmSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Kiểm kho — đặt lại số lượng thực tế',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thao tác này ghi nhận chênh lệch kiểm kho (ADJUST) vào lịch sử.',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SheetLabel('Sản phẩm'),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<StockItem>(
                value: _selectedItem,
                isExpanded: true,
                hint: Text(
                  'Chọn sản phẩm',
                  style: GoogleFonts.dmSans(
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                ),
                icon: const Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textSecondary,
                ),
                items: stocks
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          '${s.productName} (hiện: ${s.quantity})',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedItem = v;
                    if (v != null) _qtyCtrl.text = '${v.quantity}';
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SheetLabel('Số lượng thực tế (sau kiểm kho)'),
          const SizedBox(height: 6),
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                onTap: () {
                  final v = int.tryParse(_qtyCtrl.text) ?? 0;
                  if (v > 0) _qtyCtrl.text = '${v - 1}';
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              _QtyButton(
                icon: Icons.add,
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  final v = int.tryParse(_qtyCtrl.text) ?? 0;
                  _qtyCtrl.text = '${v + 1}';
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          BlocBuilder<StockBloc, StockState>(
            buildWhen: (p, c) => p.actionStatus != c.actionStatus,
            builder: (ctx, state) => SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    (_selectedItem == null ||
                        state.actionStatus == StockActionStatus.loading)
                    ? null
                    : () => _submit(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: state.actionStatus == StockActionStatus.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Xác nhận điều chỉnh',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.onTap,
    this.color = AppColors.textSecondary,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF8B5CF6),
        strokeWidth: 2.5,
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              message ?? 'Không thể tải dữ liệu',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _MovementConfig {
  const _MovementConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;
}

_MovementConfig _movementConfig(String type) => switch (type) {
  'IMPORT' => const _MovementConfig(
    label: 'NHẬP KHO',
    icon: Icons.archive_rounded,
    color: AppColors.success,
  ),
  'SALE' => const _MovementConfig(
    label: 'BÁN HÀNG',
    icon: Icons.point_of_sale_rounded,
    color: Color(0xFF0EA5E9),
  ),
  'RETURN' => const _MovementConfig(
    label: 'TRẢ HÀNG',
    icon: Icons.assignment_return_rounded,
    color: Color(0xFFF59E0B),
  ),
  'ADJUST' => const _MovementConfig(
    label: 'ĐIỀU CHỈNH',
    icon: Icons.tune_rounded,
    color: Color(0xFF8B5CF6),
  ),
  'TRANSFER' => const _MovementConfig(
    label: 'CHUYỂN KHO',
    icon: Icons.swap_horiz_rounded,
    color: Color(0xFFEC4899),
  ),
  _ => const _MovementConfig(
    label: 'KHÁC',
    icon: Icons.help_outline_rounded,
    color: AppColors.textSecondary,
  ),
};

String _defaultNote(String type) => switch (type) {
  'IMPORT' => 'Nhập kho',
  'SALE' => 'Bán hàng',
  'RETURN' => 'Trả hàng',
  'ADJUST' => 'Kiểm kho',
  'TRANSFER' => 'Chuyển kho',
  _ => '',
};

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
  if (diff.inDays < 1) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
