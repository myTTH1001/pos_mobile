// lib/features/invoices/presentation/bloc/invoices_bloc.dart
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class InvoiceModel {
  const InvoiceModel({
    required this.id,
    required this.orderId,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.createdAt,
    this.cashierId,
    this.cashierName,
    this.paidAt,
  });

  final int id;
  final int orderId;
  final double total;
  final String status; // paid | cancelled
  final String paymentMethod; // cash | card | transfer
  final DateTime createdAt;
  final int? cashierId;
  final String? cashierName;
  final DateTime? paidAt;

  factory InvoiceModel.fromJson(Map<String, dynamic> j) => InvoiceModel(
    id: j['id'] as int,
    orderId: j['order_id'] as int,
    total: _toDouble(j['total']),
    status: j['status'] as String? ?? 'paid',
    paymentMethod: j['payment_method'] as String? ?? 'cash',
    createdAt:
        (DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now())
            .toLocal(),
    cashierId: j['cashier_id'] as int?,
    cashierName: j['cashier_name'] as String?,
    paidAt: j['paid_at'] != null
        ? DateTime.tryParse(j['paid_at'] as String)?.toLocal()
        : null,
  );

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REMOTE
// ─────────────────────────────────────────────────────────────────────────────

class InvoicesRemote {
  final Dio _dio = DioClient.instance.dio;

  Future<Map<String, dynamic>> fetchInvoices({
    String? status,
    String? paymentMethod,
    int? cashierId,
    String? startDate,
    String? endDate,
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _dio.get(
      ApiConstants.invoices,
      queryParameters: {
        'limit': limit,
        'offset': offset,
        // ignore: use_null_aware_elements
        if (status != null) 'status': status,
        // ignore: use_null_aware_elements
        if (paymentMethod != null) 'payment_method': paymentMethod,
        // ignore: use_null_aware_elements
        if (cashierId != null) 'cashier_id': cashierId,
        // ignore: use_null_aware_elements
        if (startDate != null) 'start_date': startDate,
        // ignore: use_null_aware_elements
        if (endDate != null) 'end_date': endDate,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<InvoiceModel> cancelInvoice(int invoiceId) async {
    final res = await _dio.post(ApiConstants.invoiceCancel(invoiceId));
    return InvoiceModel.fromJson(res.data as Map<String, dynamic>);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS
// ─────────────────────────────────────────────────────────────────────────────

abstract class InvoicesEvent extends Equatable {
  const InvoicesEvent();
  @override
  List<Object?> get props => [];
}

class InvoicesLoadRequested extends InvoicesEvent {
  const InvoicesLoadRequested({this.refresh = false});
  final bool refresh;
  @override
  List<Object?> get props => [refresh];
}

class InvoicesLoadMore extends InvoicesEvent {
  const InvoicesLoadMore();
}

class InvoicesFilterChanged extends InvoicesEvent {
  const InvoicesFilterChanged({
    this.status,
    this.paymentMethod,
    this.startDate,
    this.endDate,
  });
  final String? status;
  final String? paymentMethod;
  final String? startDate;
  final String? endDate;
  @override
  List<Object?> get props => [status, paymentMethod, startDate, endDate];
}

class InvoicesFilterCleared extends InvoicesEvent {
  const InvoicesFilterCleared();
}

class InvoiceCancelRequested extends InvoicesEvent {
  const InvoiceCancelRequested(this.invoiceId);
  final int invoiceId;
  @override
  List<Object?> get props => [invoiceId];
}

class InvoicePrintRequested extends InvoicesEvent {
  const InvoicePrintRequested(this.invoice);
  final InvoiceModel invoice;
  @override
  List<Object?> get props => [invoice.id];
}

class InvoiceDetailSelected extends InvoicesEvent {
  const InvoiceDetailSelected(this.invoice);
  final InvoiceModel invoice;
  @override
  List<Object?> get props => [invoice.id];
}

class InvoiceDetailCleared extends InvoicesEvent {
  const InvoiceDetailCleared();
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────

enum InvoicesStatus { initial, loading, success, loadingMore, failure }

enum InvoicesActionStatus { idle, loading, success, failure }

class InvoicesState extends Equatable {
  const InvoicesState({
    this.status = InvoicesStatus.initial,
    this.invoices = const [],
    this.total = 0,
    this.hasMore = false,
    this.statusFilter,
    this.paymentMethodFilter,
    this.startDate,
    this.endDate,
    this.errorMessage,
    this.actionStatus = InvoicesActionStatus.idle,
    this.actionError,
    this.actionInvoiceId,
    this.selectedInvoice,
  });

  final InvoicesStatus status;
  final List<InvoiceModel> invoices;
  final int total;
  final bool hasMore;

  // Filters
  final String? statusFilter;
  final String? paymentMethodFilter;
  final String? startDate;
  final String? endDate;

  final String? errorMessage;

  // Action
  final InvoicesActionStatus actionStatus;
  final String? actionError;
  final int? actionInvoiceId;

  // Detail
  final InvoiceModel? selectedInvoice;

  bool get hasActiveFilter =>
      statusFilter != null ||
      paymentMethodFilter != null ||
      startDate != null ||
      endDate != null;

  // Summary stats từ list hiện tại
  double get totalRevenue => invoices
      .where((i) => i.status == 'paid')
      .fold(0, (sum, i) => sum + i.total);

  InvoicesState copyWith({
    InvoicesStatus? status,
    List<InvoiceModel>? invoices,
    int? total,
    bool? hasMore,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? paymentMethodFilter,
    bool clearPaymentFilter = false,
    String? startDate,
    bool clearStartDate = false,
    String? endDate,
    bool clearEndDate = false,
    String? errorMessage,
    InvoicesActionStatus? actionStatus,
    String? actionError,
    bool clearActionError = false,
    int? actionInvoiceId,
    bool clearActionInvoiceId = false,
    InvoiceModel? selectedInvoice,
    bool clearSelectedInvoice = false,
  }) => InvoicesState(
    status: status ?? this.status,
    invoices: invoices ?? this.invoices,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    statusFilter: clearStatusFilter
        ? null
        : (statusFilter ?? this.statusFilter),
    paymentMethodFilter: clearPaymentFilter
        ? null
        : (paymentMethodFilter ?? this.paymentMethodFilter),
    startDate: clearStartDate ? null : (startDate ?? this.startDate),
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    errorMessage: errorMessage ?? this.errorMessage,
    actionStatus: actionStatus ?? this.actionStatus,
    actionError: clearActionError ? null : (actionError ?? this.actionError),
    actionInvoiceId: clearActionInvoiceId
        ? null
        : (actionInvoiceId ?? this.actionInvoiceId),
    selectedInvoice: clearSelectedInvoice
        ? null
        : (selectedInvoice ?? this.selectedInvoice),
  );

  @override
  List<Object?> get props => [
    status,
    invoices,
    total,
    hasMore,
    statusFilter,
    paymentMethodFilter,
    startDate,
    endDate,
    errorMessage,
    actionStatus,
    actionError,
    actionInvoiceId,
    selectedInvoice,
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOC
// ─────────────────────────────────────────────────────────────────────────────

class InvoicesBloc extends Bloc<InvoicesEvent, InvoicesState> {
  InvoicesBloc() : super(const InvoicesState()) {
    on<InvoicesLoadRequested>(_onLoad);
    on<InvoicesLoadMore>(_onLoadMore);
    on<InvoicesFilterChanged>(_onFilterChanged);
    on<InvoicesFilterCleared>(_onFilterCleared);
    on<InvoiceCancelRequested>(_onCancel);
    on<InvoiceDetailSelected>(_onDetailSelected);
    on<InvoiceDetailCleared>(_onDetailCleared);
    // Print handled in UI layer (needs BuildContext for printing package)
  }

  final _remote = InvoicesRemote();
  static const _pageSize = 20;

  Future<void> _onLoad(
    InvoicesLoadRequested event,
    Emitter<InvoicesState> emit,
  ) async {
    emit(state.copyWith(status: InvoicesStatus.loading));
    try {
      final data = await _remote.fetchInvoices(
        status: state.statusFilter,
        paymentMethod: state.paymentMethodFilter,
        startDate: state.startDate,
        endDate: state.endDate,
        limit: _pageSize,
        offset: 0,
      );
      final invoices = _parse(data);
      emit(
        state.copyWith(
          status: InvoicesStatus.success,
          invoices: invoices,
          total: data['total'] as int? ?? invoices.length,
          hasMore: data['has_more'] as bool? ?? false,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: InvoicesStatus.failure, errorMessage: _clean(e)),
      );
    }
  }

  Future<void> _onLoadMore(
    InvoicesLoadMore event,
    Emitter<InvoicesState> emit,
  ) async {
    if (!state.hasMore || state.status == InvoicesStatus.loadingMore) return;
    emit(state.copyWith(status: InvoicesStatus.loadingMore));
    try {
      final data = await _remote.fetchInvoices(
        status: state.statusFilter,
        paymentMethod: state.paymentMethodFilter,
        startDate: state.startDate,
        endDate: state.endDate,
        limit: _pageSize,
        offset: state.invoices.length,
      );
      final more = _parse(data);
      emit(
        state.copyWith(
          status: InvoicesStatus.success,
          invoices: [...state.invoices, ...more],
          total: data['total'] as int? ?? state.total,
          hasMore: data['has_more'] as bool? ?? false,
        ),
      );
    } catch (_) {
      emit(state.copyWith(status: InvoicesStatus.success));
    }
  }

  Future<void> _onFilterChanged(
    InvoicesFilterChanged event,
    Emitter<InvoicesState> emit,
  ) async {
    emit(
      state.copyWith(
        statusFilter: event.status,
        clearStatusFilter: event.status == null,
        paymentMethodFilter: event.paymentMethod,
        clearPaymentFilter: event.paymentMethod == null,
        startDate: event.startDate,
        clearStartDate: event.startDate == null,
        endDate: event.endDate,
        clearEndDate: event.endDate == null,
        status: InvoicesStatus.loading,
      ),
    );
    try {
      final data = await _remote.fetchInvoices(
        status: event.status,
        paymentMethod: event.paymentMethod,
        startDate: event.startDate,
        endDate: event.endDate,
        limit: _pageSize,
        offset: 0,
      );
      final invoices = _parse(data);
      emit(
        state.copyWith(
          status: InvoicesStatus.success,
          invoices: invoices,
          total: data['total'] as int? ?? invoices.length,
          hasMore: data['has_more'] as bool? ?? false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: InvoicesStatus.failure, errorMessage: _clean(e)),
      );
    }
  }

  Future<void> _onFilterCleared(
    InvoicesFilterCleared event,
    Emitter<InvoicesState> emit,
  ) async {
    add(const InvoicesFilterChanged());
  }

  Future<void> _onCancel(
    InvoiceCancelRequested event,
    Emitter<InvoicesState> emit,
  ) async {
    emit(
      state.copyWith(
        actionStatus: InvoicesActionStatus.loading,
        actionInvoiceId: event.invoiceId,
      ),
    );
    try {
      final cancelled = await _remote.cancelInvoice(event.invoiceId);
      final updated = state.invoices
          .map((i) => i.id == event.invoiceId ? cancelled : i)
          .toList();

      final updatedSelected = state.selectedInvoice?.id == event.invoiceId
          ? cancelled
          : state.selectedInvoice;

      emit(
        state.copyWith(
          actionStatus: InvoicesActionStatus.success,
          invoices: updated,
          selectedInvoice: updatedSelected,
          clearActionError: true,
          clearActionInvoiceId: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionStatus: InvoicesActionStatus.failure,
          actionError: _clean(e),
          clearActionInvoiceId: true,
        ),
      );
    }
  }

  void _onDetailSelected(
    InvoiceDetailSelected event,
    Emitter<InvoicesState> emit,
  ) {
    emit(state.copyWith(selectedInvoice: event.invoice));
  }

  void _onDetailCleared(
    InvoiceDetailCleared event,
    Emitter<InvoicesState> emit,
  ) {
    emit(state.copyWith(clearSelectedInvoice: true));
  }

  List<InvoiceModel> _parse(Map<String, dynamic> data) {
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => InvoiceModel.fromJson(e as Map<String, dynamic>))
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
