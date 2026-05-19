// lib/features/orders/presentation/bloc/orders_bloc.dart
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/models/order_model.dart';
import '../../domain/entities/order_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REMOTE DATASOURCE (inline — nhất quán với pattern của stock/reports)
// ─────────────────────────────────────────────────────────────────────────────

class OrdersRemote {
  final Dio _dio = DioClient.instance.dio;

  Future<Map<String, dynamic>> fetchOrders({
    String? status,
    String? startDate,
    String? endDate,
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _dio.get(
      ApiConstants.orders,
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (status != null) 'status': status,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Order> cancelOrder(int orderId, {String? reason}) async {
    final res = await _dio.post(
      ApiConstants.orderCancel(orderId),
      data: {'reason': reason},
    );
    return OrderModel.fromJson(res.data as Map<String, dynamic>).toEntity();
  }

  Future<Order> getOrder(int orderId) async {
    final res = await _dio.get('${ApiConstants.orders}/$orderId');
    return OrderModel.fromJson(res.data as Map<String, dynamic>).toEntity();
  }

  /// Reorder: tạo draft order mới từ items của order cũ
  Future<Order> reorder(Order original) async {
    final items = original.items
        .map((e) => {'product_id': e.productId, 'quantity': e.quantity})
        .toList();
    final res = await _dio.post(ApiConstants.orders, data: {'items': items});
    return OrderModel.fromJson(res.data as Map<String, dynamic>).toEntity();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS
// ─────────────────────────────────────────────────────────────────────────────

abstract class OrdersEvent extends Equatable {
  const OrdersEvent();
  @override
  List<Object?> get props => [];
}

class OrdersLoadRequested extends OrdersEvent {
  const OrdersLoadRequested({this.refresh = false});
  final bool refresh;
  @override
  List<Object?> get props => [refresh];
}

class OrdersLoadMore extends OrdersEvent {
  const OrdersLoadMore();
}

class OrdersFilterChanged extends OrdersEvent {
  const OrdersFilterChanged({this.status, this.startDate, this.endDate});
  final String? status; // null = tất cả
  final String? startDate; // YYYY-MM-DD
  final String? endDate;

  @override
  List<Object?> get props => [status, startDate, endDate];
}

class OrdersFilterCleared extends OrdersEvent {
  const OrdersFilterCleared();
}

class OrderCancelRequested extends OrdersEvent {
  const OrderCancelRequested({required this.orderId, this.reason});
  final int orderId;
  final String? reason;
  @override
  List<Object?> get props => [orderId, reason];
}

class OrderReorderRequested extends OrdersEvent {
  const OrderReorderRequested(this.order);
  final Order order;
  @override
  List<Object?> get props => [order.id];
}

class OrderDetailSelected extends OrdersEvent {
  const OrderDetailSelected(this.order);
  final Order order;
  @override
  List<Object?> get props => [order.id];
}

class OrderDetailCleared extends OrdersEvent {
  const OrderDetailCleared();
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────

enum OrdersStatus { initial, loading, success, loadingMore, failure }

enum OrdersActionStatus { idle, loading, success, failure }

class OrdersState extends Equatable {
  const OrdersState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.total = 0,
    this.hasMore = false,
    this.statusFilter,
    this.startDate,
    this.endDate,
    this.errorMessage,
    this.actionStatus = OrdersActionStatus.idle,
    this.actionError,
    this.actionOrderId,
    this.selectedOrder,
    this.reorderedOrder,
  });

  final OrdersStatus status;
  final List<Order> orders;
  final int total;
  final bool hasMore;

  // Filters
  final String? statusFilter;
  final String? startDate;
  final String? endDate;

  // Error
  final String? errorMessage;

  // Cancel / Reorder action
  final OrdersActionStatus actionStatus;
  final String? actionError;
  final int? actionOrderId; // order đang được xử lý

  // Detail panel (tablet split view)
  final Order? selectedOrder;

  // Reorder result — để POS bloc có thể nhận
  final Order? reorderedOrder;

  bool get hasActiveFilter =>
      statusFilter != null || startDate != null || endDate != null;

  OrdersState copyWith({
    OrdersStatus? status,
    List<Order>? orders,
    int? total,
    bool? hasMore,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? startDate,
    bool clearStartDate = false,
    String? endDate,
    bool clearEndDate = false,
    String? errorMessage,
    OrdersActionStatus? actionStatus,
    String? actionError,
    bool clearActionError = false,
    int? actionOrderId,
    bool clearActionOrderId = false,
    Order? selectedOrder,
    bool clearSelectedOrder = false,
    Order? reorderedOrder,
    bool clearReorderedOrder = false,
  }) => OrdersState(
    status: status ?? this.status,
    orders: orders ?? this.orders,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    statusFilter: clearStatusFilter
        ? null
        : (statusFilter ?? this.statusFilter),
    startDate: clearStartDate ? null : (startDate ?? this.startDate),
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    errorMessage: errorMessage ?? this.errorMessage,
    actionStatus: actionStatus ?? this.actionStatus,
    actionError: clearActionError ? null : (actionError ?? this.actionError),
    actionOrderId: clearActionOrderId
        ? null
        : (actionOrderId ?? this.actionOrderId),
    selectedOrder: clearSelectedOrder
        ? null
        : (selectedOrder ?? this.selectedOrder),
    reorderedOrder: clearReorderedOrder
        ? null
        : (reorderedOrder ?? this.reorderedOrder),
  );

  @override
  List<Object?> get props => [
    status,
    orders,
    total,
    hasMore,
    statusFilter,
    startDate,
    endDate,
    errorMessage,
    actionStatus,
    actionError,
    actionOrderId,
    selectedOrder,
    reorderedOrder,
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOC
// ─────────────────────────────────────────────────────────────────────────────

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc() : super(const OrdersState()) {
    on<OrdersLoadRequested>(_onLoad);
    on<OrdersLoadMore>(_onLoadMore);
    on<OrdersFilterChanged>(_onFilterChanged);
    on<OrdersFilterCleared>(_onFilterCleared);
    on<OrderCancelRequested>(_onCancel);
    on<OrderReorderRequested>(_onReorder);
    on<OrderDetailSelected>(_onDetailSelected);
    on<OrderDetailCleared>(_onDetailCleared);
  }

  final _remote = OrdersRemote();
  static const _pageSize = 20;

  // ── Load / Refresh ──────────────────────────────────────────────────────

  Future<void> _onLoad(
    OrdersLoadRequested event,
    Emitter<OrdersState> emit,
  ) async {
    emit(state.copyWith(status: OrdersStatus.loading));
    try {
      final data = await _remote.fetchOrders(
        status: state.statusFilter,
        startDate: state.startDate,
        endDate: state.endDate,
        limit: _pageSize,
        offset: 0,
      );
      final orders = _parseOrders(data);
      emit(
        state.copyWith(
          status: OrdersStatus.success,
          orders: orders,
          total: data['total'] as int? ?? orders.length,
          hasMore: data['has_more'] as bool? ?? false,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: OrdersStatus.failure, errorMessage: _clean(e)),
      );
    }
  }

  // ── Load More ───────────────────────────────────────────────────────────

  Future<void> _onLoadMore(
    OrdersLoadMore event,
    Emitter<OrdersState> emit,
  ) async {
    if (!state.hasMore || state.status == OrdersStatus.loadingMore) return;
    emit(state.copyWith(status: OrdersStatus.loadingMore));
    try {
      final data = await _remote.fetchOrders(
        status: state.statusFilter,
        startDate: state.startDate,
        endDate: state.endDate,
        limit: _pageSize,
        offset: state.orders.length,
      );
      final more = _parseOrders(data);
      emit(
        state.copyWith(
          status: OrdersStatus.success,
          orders: [...state.orders, ...more],
          total: data['total'] as int? ?? state.total,
          hasMore: data['has_more'] as bool? ?? false,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: OrdersStatus.success));
    }
  }

  // ── Filter ──────────────────────────────────────────────────────────────

  Future<void> _onFilterChanged(
    OrdersFilterChanged event,
    Emitter<OrdersState> emit,
  ) async {
    emit(
      state.copyWith(
        statusFilter: event.status,
        clearStatusFilter: event.status == null,
        startDate: event.startDate,
        clearStartDate: event.startDate == null,
        endDate: event.endDate,
        clearEndDate: event.endDate == null,
        status: OrdersStatus.loading,
      ),
    );
    try {
      final data = await _remote.fetchOrders(
        status: event.status,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: _pageSize,
        offset: 0,
      );
      final orders = _parseOrders(data);
      emit(
        state.copyWith(
          status: OrdersStatus.success,
          orders: orders,
          total: data['total'] as int? ?? orders.length,
          hasMore: data['has_more'] as bool? ?? false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: OrdersStatus.failure, errorMessage: _clean(e)),
      );
    }
  }

  Future<void> _onFilterCleared(
    OrdersFilterCleared event,
    Emitter<OrdersState> emit,
  ) async {
    add(const OrdersFilterChanged());
  }

  // ── Cancel ──────────────────────────────────────────────────────────────

  Future<void> _onCancel(
    OrderCancelRequested event,
    Emitter<OrdersState> emit,
  ) async {
    emit(
      state.copyWith(
        actionStatus: OrdersActionStatus.loading,
        actionOrderId: event.orderId,
      ),
    );
    try {
      final cancelled = await _remote.cancelOrder(
        event.orderId,
        reason: event.reason,
      );

      // Cập nhật order trong list
      final updated = state.orders
          .map((o) => o.id == event.orderId ? cancelled : o)
          .toList();

      // Nếu đang xem order này trong detail panel, cập nhật luôn
      final updatedSelected = state.selectedOrder?.id == event.orderId
          ? cancelled
          : state.selectedOrder;

      emit(
        state.copyWith(
          actionStatus: OrdersActionStatus.success,
          orders: updated,
          selectedOrder: updatedSelected,
          clearActionError: true,
          clearActionOrderId: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: OrdersActionStatus.failure,
          actionError: _clean(e),
          clearActionOrderId: true,
        ),
      );
    }
  }

  // ── Reorder ─────────────────────────────────────────────────────────────

  Future<void> _onReorder(
    OrderReorderRequested event,
    Emitter<OrdersState> emit,
  ) async {
    emit(
      state.copyWith(
        actionStatus: OrdersActionStatus.loading,
        actionOrderId: event.order.id,
      ),
    );
    try {
      final newOrder = await _remote.reorder(event.order);
      emit(
        state.copyWith(
          actionStatus: OrdersActionStatus.success,
          reorderedOrder: newOrder,
          clearActionError: true,
          clearActionOrderId: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: OrdersActionStatus.failure,
          actionError: _clean(e),
          clearActionOrderId: true,
        ),
      );
    }
  }

  // ── Detail ──────────────────────────────────────────────────────────────

  void _onDetailSelected(OrderDetailSelected event, Emitter<OrdersState> emit) {
    emit(state.copyWith(selectedOrder: event.order));
  }

  void _onDetailCleared(OrderDetailCleared event, Emitter<OrdersState> emit) {
    emit(state.copyWith(clearSelectedOrder: true));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  List<Order> _parseOrders(Map<String, dynamic> data) {
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }

  String _clean(Object e) {
    if (e is DioException) {
      final detail = e.response?.data?['detail'];
      if (detail is String) return detail;
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}
