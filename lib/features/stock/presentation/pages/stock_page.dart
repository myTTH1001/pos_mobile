// lib/features/stock/presentation/pages/stock_page.dart
//
// Màn hình Quản lý kho — nghiệp vụ đầy đủ:
//   • Tab Tồn kho: danh sách sản phẩm + số lượng hiện tại
//   • Tab Lịch sử: StockMovement (IMPORT / SALE / RETURN / ADJUST / TRANSFER)
//   • Bottom sheet Nhập kho (POST /stock/import)
//   • Bottom sheet Điều chỉnh tồn (POST /stock/adjust)
//   • Pull-to-refresh, search, filter type

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
  const StockItem({required this.productId, required this.quantity});
  final int productId;
  final int quantity;

  factory StockItem.fromJson(Map<String, dynamic> j) => StockItem(
    productId: j['product_id'] as int,
    quantity: j['quantity'] as int? ?? 0,
  );
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
  final String type; // IMPORT | SALE | RETURN | ADJUST | TRANSFER
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

  Future<List<StockItem>> listStock() async {
    final res = await _dio.get(ApiConstants.stock);
    final list = res.data as List<dynamic>? ?? [];
    return list
        .map((e) => StockItem.fromJson(e as Map<String, dynamic>))
        .toList();
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
        // ignore: use_null_aware_elements
        if (productId != null) 'product_id': productId,
        // ignore: use_null_aware_elements
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
// PRODUCT NAME CACHE (lấy từ /products để hiển thị tên)
// ─────────────────────────────────────────────────────────────────────────────

class _ProductNameCache {
  static final Map<int, String> _cache = {};

  static Future<void> prefetch(Dio dio, List<int> ids) async {
    final missing = ids.where((id) => !_cache.containsKey(id)).toList();
    if (missing.isEmpty) return;
    try {
      final res = await dio.get(
        ApiConstants.products,
        queryParameters: {'limit': 100, 'offset': 0},
      );
      final items = (res.data['items'] as List<dynamic>? ?? []);
      for (final item in items) {
        final m = item as Map<String, dynamic>;
        _cache[m['id'] as int] = m['name'] as String;
      }
    } catch (_) {}
  }

  static String get(int id) => _cache[id] ?? '#$id';
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOC — STOCK
// ─────────────────────────────────────────────────────────────────────────────

// Events
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

// State
enum StockStatus { initial, loading, success, failure }

enum StockActionStatus { idle, loading, success, failure }

class StockState {
  const StockState({
    this.stockStatus = StockStatus.initial,
    this.movementsStatus = StockStatus.initial,
    this.stocks = const [],
    this.movements = const [],
    this.searchQuery = '',
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
  final String? movementTypeFilter;
  final String? errorMessage;
  final StockActionStatus actionStatus;
  final String? actionError;

  List<StockItem> get filteredStocks {
    if (searchQuery.isEmpty) return stocks;
    return stocks
        .where(
          (s) => _ProductNameCache.get(
            s.productId,
          ).toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();
  }

  StockState copyWith({
    StockStatus? stockStatus,
    StockStatus? movementsStatus,
    List<StockItem>? stocks,
    List<StockMovement>? movements,
    String? searchQuery,
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
  }

  final _remote = StockRemote();

  Future<void> _onStockLoad(
    StockLoadRequested event,
    Emitter<StockState> emit,
  ) async {
    emit(state.copyWith(stockStatus: StockStatus.loading));
    try {
      final stocks = await _remote.listStock();
      // prefetch product names
      await _ProductNameCache.prefetch(
        DioClient.instance.dio,
        stocks.map((s) => s.productId).toList(),
      );
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
      await _ProductNameCache.prefetch(
        DioClient.instance.dio,
        movements.map((m) => m.productId).toList(),
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
      // reload
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
// HEADER + TAB BAR
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
                // Summary chip
                BlocBuilder<StockBloc, StockState>(
                  buildWhen: (p, c) => p.stocks != c.stocks,
                  builder: (_, state) {
                    final lowStock = state.stocks
                        .where((s) => s.quantity < 5)
                        .length;
                    if (lowStock == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$lowStock sắp hết',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // TabBar
          TabBar(
            controller: tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
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
                p.searchQuery != c.searchQuery,
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
                return _EmptyBody(
                  icon: Icons.warehouse_outlined,
                  message: state.searchQuery.isNotEmpty
                      ? 'Không tìm thấy "${state.searchQuery}"'
                      : 'Chưa có dữ liệu tồn kho',
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
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
    final name = _ProductNameCache.get(item.productId);
    final isLow = item.quantity < 5;
    final isOut = item.quantity == 0;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

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
        onTap: () => _showStockActions(context, item, name),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar icon
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

              // Name + ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${item.productId}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Quantity + Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.quantity}',
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isOut
                          ? AppColors.error
                          : isLow
                          ? AppColors.warning
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 3),
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

              const SizedBox(width: 8),
              Icon(
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
// TAB 2: LỊCH SỬ NHẬP XUẤT
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
                      selectedColor: AppColors.primary.withValues(alpha: 0.12),
                      checkmarkColor: AppColors.primary,
                      labelStyle: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      backgroundColor: AppColors.surfaceAlt,
                      side: BorderSide(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
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
                color: AppColors.primary,
                onRefresh: () async => ctx.read<StockBloc>().add(
                  MovementsLoadRequested(refresh: true),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.movements.length,
                  itemBuilder: (_, i) =>
                      _MovementCard(movement: state.movements[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.movement});
  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final cfg = _movementConfig(movement.type);
    final name = _ProductNameCache.get(movement.productId);
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
            // Type icon
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

            // Info
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
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
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

            // Quantity
            Text(
              qtyStr,
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: movement.quantity > 0
                    ? AppColors.success.withValues(alpha: 0.1)
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
// FAB — Nhập kho / Điều chỉnh
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
    // Only show on inventory tab
    return AnimatedBuilder(
      animation: widget.tabController,
      builder: (_, _) {
        if (widget.tabController.index != 0) {
          return const SizedBox.shrink();
        }
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
              backgroundColor: AppColors.primary,
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
// STOCK ACTION POPUP (tap vào card tồn kho)
// ─────────────────────────────────────────────────────────────────────────────

void _showStockActions(BuildContext context, StockItem item, String name) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => BlocProvider.value(
      value: context.read<StockBloc>(),
      child: _StockActionSheet(item: item, name: name),
    ),
  );
}

class _StockActionSheet extends StatelessWidget {
  const _StockActionSheet({required this.item, required this.name});
  final StockItem item;
  final String name;

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
          // Handle
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
          // Header
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
                      name,
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
          // Actions
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
            Icon(
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
          // Handle + title
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

          // Product selector
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
                          _ProductNameCache.get(s.productId),
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

          // Quantity
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

          // Note
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

          // Submit
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
    if (widget.currentQty != null) {
      _qtyCtrl.text = '${widget.currentQty}';
    }
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

          // Warning note
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

          // Product selector
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
                          '${_ProductNameCache.get(s.productId)} (hiện: ${s.quantity})',
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
        color: AppColors.primary,
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
                backgroundColor: AppColors.primary,
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
