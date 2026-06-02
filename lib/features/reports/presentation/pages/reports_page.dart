// lib/features/reports/presentation/pages/reports_page.dart
//
// Màn hình Báo cáo — kết nối thực với 3 API:
//   • GET /reports/daily   → Doanh thu theo ngày (line chart)
//   • GET /reports/cashier → Doanh thu theo thu ngân (bar / list)
//   • GET /reports/product → Top sản phẩm bán chạy (ranked list)
//
// Cấu trúc: BLoC + remote datasource + UI thuần Flutter (không cần thư viện chart)
// Responsive: phone (TabBar) & tablet (side tabs + split view)

import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════

class RevenueByDay {
  final DateTime date;
  final double revenue;
  final int totalOrders;

  const RevenueByDay({
    required this.date,
    required this.revenue,
    required this.totalOrders,
  });

  factory RevenueByDay.fromJson(Map<String, dynamic> j) => RevenueByDay(
    date: (DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now())
        .toLocal(),
    revenue: _toDouble(j['revenue']),
    totalOrders: (j['total_orders'] as num?)?.toInt() ?? 0,
  );
}

class RevenueByCashier {
  final int cashierId;
  final String username;
  final double revenue;
  final int totalOrders;

  const RevenueByCashier({
    required this.cashierId,
    required this.username,
    required this.revenue,
    required this.totalOrders,
  });

  factory RevenueByCashier.fromJson(Map<String, dynamic> j) => RevenueByCashier(
    cashierId: j['cashier_id'] as int? ?? 0,
    username: j['username'] as String? ?? '',
    revenue: _toDouble(j['revenue']),
    totalOrders: (j['total_orders'] as num?)?.toInt() ?? 0,
  );
}

class RevenueByProduct {
  final int productId;
  final String productName;
  final int totalSold;
  final double revenue;

  const RevenueByProduct({
    required this.productId,
    required this.productName,
    required this.totalSold,
    required this.revenue,
  });

  factory RevenueByProduct.fromJson(Map<String, dynamic> j) => RevenueByProduct(
    productId: j['product_id'] as int? ?? 0,
    productName: j['product_name'] as String? ?? '',
    totalSold: (j['total_sold'] as num?)?.toInt() ?? 0,
    revenue: _toDouble(j['revenue']),
  );
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

// ═══════════════════════════════════════════════════════════════
// REMOTE DATASOURCE
// ═══════════════════════════════════════════════════════════════

class ReportRemote {
  final Dio _dio = DioClient.instance.dio;

  String _fmt(DateTime dt) => dt.toUtc().toIso8601String();

  Future<List<RevenueByDay>> fetchDaily(DateTime from, DateTime to) async {
    final res = await _dio.get(
      ApiConstants.reportDaily,
      queryParameters: {'start_date': _fmt(from), 'end_date': _fmt(to)},
    );
    final list = res.data as List<dynamic>? ?? [];
    return list
        .map((e) => RevenueByDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RevenueByCashier>> fetchCashier(
    DateTime from,
    DateTime to,
  ) async {
    final res = await _dio.get(
      ApiConstants.reportCashier,
      queryParameters: {'start_date': _fmt(from), 'end_date': _fmt(to)},
    );
    final list = res.data as List<dynamic>? ?? [];
    return list
        .map((e) => RevenueByCashier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RevenueByProduct>> fetchProduct(
    DateTime from,
    DateTime to, {
    int limit = 10,
  }) async {
    final res = await _dio.get(
      ApiConstants.reportProduct,
      queryParameters: {
        'start_date': _fmt(from),
        'end_date': _fmt(to),
        'limit': limit,
        'offset': 0,
      },
    );
    final data = res.data as Map<String, dynamic>? ?? {};
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => RevenueByProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ═══════════════════════════════════════════════════════════════
// DATE RANGE PRESET
// ═══════════════════════════════════════════════════════════════

enum DatePreset { today, week, month, quarter }

extension DatePresetExt on DatePreset {
  String get label => switch (this) {
    DatePreset.today => 'Hôm nay',
    DatePreset.week => '7 ngày',
    DatePreset.month => '30 ngày',
    DatePreset.quarter => '90 ngày',
  };

  (DateTime, DateTime) get range {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return switch (this) {
      DatePreset.today => (DateTime(now.year, now.month, now.day), end),
      DatePreset.week => (
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6)),
        end,
      ),
      DatePreset.month => (
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29)),
        end,
      ),
      DatePreset.quarter => (
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 89)),
        end,
      ),
    };
  }
}

// ═══════════════════════════════════════════════════════════════
// BLOC — EVENTS
// ═══════════════════════════════════════════════════════════════

abstract class ReportEvent {}

class ReportPresetChanged extends ReportEvent {
  ReportPresetChanged(this.preset);
  final DatePreset preset;
}

class ReportCustomDateChanged extends ReportEvent {
  ReportCustomDateChanged(this.from, this.to);
  final DateTime from;
  final DateTime to;
}

class ReportRefreshRequested extends ReportEvent {}

// ═══════════════════════════════════════════════════════════════
// BLOC — STATE
// ═══════════════════════════════════════════════════════════════

enum ReportStatus { initial, loading, success, failure }

class ReportState {
  const ReportState({
    this.status = ReportStatus.initial,
    this.preset = DatePreset.week,
    this.from,
    this.to,
    this.daily = const [],
    this.cashiers = const [],
    this.products = const [],
    this.errorMessage,
  });

  final ReportStatus status;
  final DatePreset preset;
  final DateTime? from;
  final DateTime? to;
  final List<RevenueByDay> daily;
  final List<RevenueByCashier> cashiers;
  final List<RevenueByProduct> products;
  final String? errorMessage;

  double get totalRevenue => daily.fold(0, (sum, d) => sum + d.revenue);
  int get totalOrders => daily.fold(0, (sum, d) => sum + d.totalOrders);

  ReportState copyWith({
    ReportStatus? status,
    DatePreset? preset,
    DateTime? from,
    DateTime? to,
    List<RevenueByDay>? daily,
    List<RevenueByCashier>? cashiers,
    List<RevenueByProduct>? products,
    String? errorMessage,
  }) => ReportState(
    status: status ?? this.status,
    preset: preset ?? this.preset,
    from: from ?? this.from,
    to: to ?? this.to,
    daily: daily ?? this.daily,
    cashiers: cashiers ?? this.cashiers,
    products: products ?? this.products,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

// ═══════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  ReportBloc() : super(const ReportState()) {
    on<ReportPresetChanged>(_onPreset);
    on<ReportCustomDateChanged>(_onCustomDate);
    on<ReportRefreshRequested>(_onRefresh);
  }

  final _remote = ReportRemote();

  Future<void> _onPreset(
    ReportPresetChanged event,
    Emitter<ReportState> emit,
  ) async {
    final (from, to) = event.preset.range;
    emit(
      state.copyWith(
        preset: event.preset,
        from: from,
        to: to,
        status: ReportStatus.loading,
      ),
    );
    await _fetch(from, to, emit);
  }

  Future<void> _onCustomDate(
    ReportCustomDateChanged event,
    Emitter<ReportState> emit,
  ) async {
    emit(
      state.copyWith(
        from: event.from,
        to: event.to,
        status: ReportStatus.loading,
      ),
    );
    await _fetch(event.from, event.to, emit);
  }

  Future<void> _onRefresh(
    ReportRefreshRequested event,
    Emitter<ReportState> emit,
  ) async {
    final from = state.from;
    final to = state.to;
    if (from == null || to == null) return;
    emit(state.copyWith(status: ReportStatus.loading));
    await _fetch(from, to, emit);
  }

  Future<void> _fetch(
    DateTime from,
    DateTime to,
    Emitter<ReportState> emit,
  ) async {
    try {
      final results = await Future.wait([
        _remote.fetchDaily(from, to),
        _remote.fetchCashier(from, to),
        _remote.fetchProduct(from, to, limit: 10),
      ]);
      emit(
        state.copyWith(
          status: ReportStatus.success,
          daily: results[0] as List<RevenueByDay>,
          cashiers: results[1] as List<RevenueByCashier>,
          products: results[2] as List<RevenueByProduct>,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ReportStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// PAGE ENTRY
// ═══════════════════════════════════════════════════════════════

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReportBloc()..add(ReportPresetChanged(DatePreset.week)),
      child: const _ReportsView(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MAIN VIEW
// ═══════════════════════════════════════════════════════════════

class _ReportsView extends StatefulWidget {
  const _ReportsView();

  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['Doanh thu', 'Thu ngân', 'Sản phẩm'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 700;
    return isTablet
        ? _TabletLayout(tabController: _tabController, tabs: _tabs)
        : _PhoneLayout(tabController: _tabController, tabs: _tabs);
  }
}

// ─────────────────────────────────────────────────────────────
// PHONE LAYOUT
// ─────────────────────────────────────────────────────────────

class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({required this.tabController, required this.tabs});
  final TabController tabController;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _ReportHeader(tabController: tabController, tabs: tabs),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: const [_DailyTab(), _CashierTab(), _ProductTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TABLET LAYOUT
// ─────────────────────────────────────────────────────────────

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({required this.tabController, required this.tabs});
  final TabController tabController;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _ReportHeader(tabController: tabController, tabs: tabs),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: const [_DailyTab(), _CashierTab(), _ProductTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HEADER (Date picker + Tab bar + Summary cards)
// ═══════════════════════════════════════════════════════════════

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.tabController, required this.tabs});
  final TabController tabController;
  final List<String> tabs;

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
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: AppColors.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Báo cáo',
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      BlocBuilder<ReportBloc, ReportState>(
                        buildWhen: (p, c) => p.from != c.from || p.to != c.to,
                        builder: (_, s) {
                          if (s.from == null) return const SizedBox.shrink();
                          return Text(
                            '${_fmtDate(s.from!)} – ${_fmtDate(s.to!)}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Refresh
                BlocBuilder<ReportBloc, ReportState>(
                  buildWhen: (p, c) => p.status != c.status,
                  builder: (ctx, s) => IconButton(
                    onPressed: s.status == ReportStatus.loading
                        ? null
                        : () => ctx.read<ReportBloc>().add(
                            ReportRefreshRequested(),
                          ),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Làm mới',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Preset chips
          SizedBox(
            height: 36,
            child: BlocBuilder<ReportBloc, ReportState>(
              buildWhen: (p, c) => p.preset != c.preset,
              builder: (ctx, s) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ...DatePreset.values.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _PresetChip(
                        preset: p,
                        selected: s.preset == p,
                        onTap: () =>
                            ctx.read<ReportBloc>().add(ReportPresetChanged(p)),
                      ),
                    ),
                  ),
                  // Custom date picker
                  _CustomDateChip(currentFrom: s.from, currentTo: s.to),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Summary cards
          BlocBuilder<ReportBloc, ReportState>(
            buildWhen: (p, c) =>
                p.totalRevenue != c.totalRevenue ||
                p.totalOrders != c.totalOrders ||
                p.status != c.status,
            builder: (_, s) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Tổng doanh thu',
                      value: s.status == ReportStatus.loading
                          ? '...'
                          : _fmtMoney(s.totalRevenue),
                      icon: Icons.trending_up_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Số đơn hàng',
                      value: s.status == ReportStatus.loading
                          ? '...'
                          : '${s.totalOrders}',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'TB / đơn',
                      value: s.status == ReportStatus.loading
                          ? '...'
                          : s.totalOrders == 0
                          ? '–'
                          : _fmtMoneyShort(s.totalRevenue / s.totalOrders),
                      icon: Icons.calculate_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab bar
          TabBar(
            controller: tabController,
            labelColor: AppColors.error,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.error,
            indicatorWeight: 2.5,
            labelStyle: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: tabs.map((t) => Tab(text: t)).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Preset chip ──────────────────────────────────────────────

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });
  final DatePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.error : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? AppColors.error : Colors.transparent,
          ),
        ),
        child: Text(
          preset.label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Custom date chip ─────────────────────────────────────────

class _CustomDateChip extends StatelessWidget {
  const _CustomDateChip({this.currentFrom, this.currentTo});
  final DateTime? currentFrom;
  final DateTime? currentTo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: now,
          initialDateRange: currentFrom != null
              ? DateTimeRange(start: currentFrom!, end: currentTo ?? now)
              : null,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.error,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null && context.mounted) {
          context.read<ReportBloc>().add(
            ReportCustomDateChanged(
              picked.start,
              DateTime(
                picked.end.year,
                picked.end.month,
                picked.end.day,
                23,
                59,
                59,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 13,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              'Tùy chọn',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary card ────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 1 — DOANH THU THEO NGÀY
// ═══════════════════════════════════════════════════════════════

class _DailyTab extends StatelessWidget {
  const _DailyTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportBloc, ReportState>(
      buildWhen: (p, c) => p.status != c.status || p.daily != c.daily,
      builder: (_, state) {
        if (state.status == ReportStatus.initial ||
            state.status == ReportStatus.loading) {
          return const _LoadingBody();
        }
        if (state.status == ReportStatus.failure) {
          return _ErrorBody(message: state.errorMessage);
        }
        if (state.daily.isEmpty) {
          return const _EmptyBody(message: 'Không có dữ liệu doanh thu');
        }
        return _DailyContent(data: state.daily);
      },
    );
  }
}

class _DailyContent extends StatelessWidget {
  const _DailyContent({required this.data});
  final List<RevenueByDay> data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Line chart
        _RevenueLineChart(data: data),
        const SizedBox(height: 16),
        // Daily breakdown list
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _SectionTitle(
                icon: Icons.list_alt_rounded,
                title: 'Chi tiết theo ngày',
                count: data.length,
              ),
              const Divider(height: 1, color: AppColors.border),
              ...data.reversed.map((d) => _DayRow(day: d)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});
  final RevenueByDay day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Date
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd').format(day.date),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _monthVi(day.date.month),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weekdayVi(day.date.weekday),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${day.totalOrders} đơn hàng',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _fmtMoney(day.revenue),
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Revenue Line Chart (custom paint) ──────────────────────

class _RevenueLineChart extends StatelessWidget {
  const _RevenueLineChart({required this.data});
  final List<RevenueByDay> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.show_chart_rounded,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Text(
                  'Xu hướng doanh thu',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: CustomPaint(
                painter: _LineChartPainter(data: data),
                child: Container(),
              ),
            ),
            const SizedBox(height: 4),
            // X-axis labels — show first, mid, last
            if (data.length >= 2)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmtDateShort(data.first.date), style: _axisStyle()),
                  if (data.length > 2)
                    Text(
                      _fmtDateShort(data[data.length ~/ 2].date),
                      style: _axisStyle(),
                    ),
                  Text(_fmtDateShort(data.last.date), style: _axisStyle()),
                ],
              ),
          ],
        ),
      ),
    );
  }

  TextStyle _axisStyle() =>
      GoogleFonts.dmSans(fontSize: 10, color: AppColors.textSecondary);
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.data});
  final List<RevenueByDay> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.map((d) => d.revenue).reduce(math.max);
    if (maxVal == 0) return;

    // Grid lines
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Build points
    final pts = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = size.width * i / math.max(data.length - 1, 1);
      final y = size.height * (1 - data[i].revenue / maxVal);
      pts.add(Offset(x, y));
    }

    // Gradient fill
    final fillPath = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(pts.last.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.success.withValues(alpha: 0.25),
          AppColors.success.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = AppColors.success
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      // Smooth curve
      final prev = pts[i - 1];
      final curr = pts[i];
      final cpX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots on data points
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final p in pts) {
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(p, 4, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.data != data;
}

// ═══════════════════════════════════════════════════════════════
// TAB 2 — DOANH THU THEO THU NGÂN
// ═══════════════════════════════════════════════════════════════

class _CashierTab extends StatelessWidget {
  const _CashierTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportBloc, ReportState>(
      buildWhen: (p, c) => p.status != c.status || p.cashiers != c.cashiers,
      builder: (_, state) {
        if (state.status == ReportStatus.initial ||
            state.status == ReportStatus.loading) {
          return const _LoadingBody();
        }
        if (state.status == ReportStatus.failure) {
          return _ErrorBody(message: state.errorMessage);
        }
        if (state.cashiers.isEmpty) {
          return const _EmptyBody(
            message: 'Không có dữ liệu thu ngân trong kỳ này',
          );
        }
        return _CashierContent(data: state.cashiers);
      },
    );
  }
}

class _CashierContent extends StatelessWidget {
  const _CashierContent({required this.data});
  final List<RevenueByCashier> data;

  @override
  Widget build(BuildContext context) {
    final maxRevenue = data.map((c) => c.revenue).reduce(math.max);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Bar chart
        _CashierBarChart(data: data, maxRevenue: maxRevenue),
        const SizedBox(height: 16),
        // Ranked list
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _SectionTitle(
                icon: Icons.people_rounded,
                title: 'Xếp hạng thu ngân',
                count: data.length,
              ),
              const Divider(height: 1, color: AppColors.border),
              ...data.asMap().entries.map(
                (e) => _CashierRow(
                  rank: e.key + 1,
                  cashier: e.value,
                  maxRevenue: maxRevenue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CashierBarChart extends StatelessWidget {
  const _CashierBarChart({required this.data, required this.maxRevenue});
  final List<RevenueByCashier> data;
  final double maxRevenue;

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      AppColors.accent,
      const Color(0xFF8B5CF6),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'So sánh doanh thu',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.asMap().entries.map((e) {
                final ratio = maxRevenue > 0
                    ? e.value.revenue / maxRevenue
                    : 0.0;
                final color = colors[e.key % colors.length];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _fmtMoneyShort(e.value.revenue),
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 400 + e.key * 80),
                          height: 100 * ratio,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.value.username,
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashierRow extends StatelessWidget {
  const _CashierRow({
    required this.rank,
    required this.cashier,
    required this.maxRevenue,
  });
  final int rank;
  final RevenueByCashier cashier;
  final double maxRevenue;

  @override
  Widget build(BuildContext context) {
    final ratio = maxRevenue > 0 ? cashier.revenue / maxRevenue : 0.0;
    final medalColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final isMedal = rank <= 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Rank badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isMedal
                      ? medalColors[rank - 1].withValues(alpha: 0.15)
                      : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isMedal
                      ? Icon(
                          Icons.emoji_events_rounded,
                          size: 16,
                          color: medalColors[rank - 1],
                        )
                      : Text(
                          '$rank',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  cashier.username.isNotEmpty
                      ? cashier.username[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cashier.username,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${cashier.totalOrders} đơn',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _fmtMoney(cashier.revenue),
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 3 — TOP SẢN PHẨM
// ═══════════════════════════════════════════════════════════════

class _ProductTab extends StatelessWidget {
  const _ProductTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportBloc, ReportState>(
      buildWhen: (p, c) => p.status != c.status || p.products != c.products,
      builder: (_, state) {
        if (state.status == ReportStatus.initial ||
            state.status == ReportStatus.loading) {
          return const _LoadingBody();
        }
        if (state.status == ReportStatus.failure) {
          return _ErrorBody(message: state.errorMessage);
        }
        if (state.products.isEmpty) {
          return const _EmptyBody(
            message: 'Không có dữ liệu sản phẩm trong kỳ này',
          );
        }
        return _ProductContent(data: state.products);
      },
    );
  }
}

class _ProductContent extends StatelessWidget {
  const _ProductContent({required this.data});
  final List<RevenueByProduct> data;

  @override
  Widget build(BuildContext context) {
    final maxSold = data.map((p) => p.totalSold).reduce(math.max).toDouble();
    final maxRevenue = data.map((p) => p.revenue).reduce(math.max);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Horizontal bar chart (quantity)
        _ProductBarChart(data: data, maxSold: maxSold),
        const SizedBox(height: 16),
        // Revenue ranked list
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _SectionTitle(
                icon: Icons.inventory_2_rounded,
                title: 'Top sản phẩm bán chạy',
                count: data.length,
              ),
              const Divider(height: 1, color: AppColors.border),
              ...data.asMap().entries.map(
                (e) => _ProductRow(
                  rank: e.key + 1,
                  product: e.value,
                  maxRevenue: maxRevenue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductBarChart extends StatelessWidget {
  const _ProductBarChart({required this.data, required this.maxSold});
  final List<RevenueByProduct> data;
  final double maxSold;

  @override
  Widget build(BuildContext context) {
    // Show top 5 only in chart
    final top = data.take(5).toList();
    const barColor = Color(0xFF8B5CF6);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 6),
              Text(
                'Số lượng bán (Top 5)',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...top.map((p) {
            final ratio = maxSold > 0 ? p.totalSold / maxSold : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      p.productName,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 10,
                        backgroundColor: AppColors.surfaceAlt,
                        valueColor: const AlwaysStoppedAnimation(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${p.totalSold}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.rank,
    required this.product,
    required this.maxRevenue,
  });
  final int rank;
  final RevenueByProduct product;
  final double maxRevenue;

  @override
  Widget build(BuildContext context) {
    final ratio = maxRevenue > 0 ? product.revenue / maxRevenue : 0.0;
    const color = Color(0xFF8B5CF6);

    final medalColors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final isMedal = rank <= 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Rank
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isMedal
                      ? medalColors[rank - 1].withValues(alpha: 0.15)
                      : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isMedal
                      ? Icon(
                          Icons.emoji_events_rounded,
                          size: 14,
                          color: medalColors[rank - 1],
                        )
                      : Text(
                          '$rank',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              // Product icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Đã bán: ${product.totalSold} đơn vị',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _fmtMoney(product.revenue),
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.count,
  });
  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count mục',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
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
        color: AppColors.error,
        strokeWidth: 2.5,
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({this.message});
  final String? message;

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
              message ?? 'Không thể tải báo cáo',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  context.read<ReportBloc>().add(ReportRefreshRequested()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
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
  const _EmptyBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bar_chart_rounded,
            size: 52,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════

String _fmtMoney(double v) {
  final n = v.toInt();
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '$bufđ';
}

String _fmtMoneyShort(double v) {
  if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(1)}T';
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return '${v.toInt()}đ';
}

String _fmtDate(DateTime dt) => DateFormat('dd/MM/yyyy').format(dt);

String _fmtDateShort(DateTime dt) => DateFormat('dd/MM').format(dt);

String _weekdayVi(int weekday) =>
    const {
      1: 'Thứ Hai',
      2: 'Thứ Ba',
      3: 'Thứ Tư',
      4: 'Thứ Năm',
      5: 'Thứ Sáu',
      6: 'Thứ Bảy',
      7: 'Chủ Nhật',
    }[weekday] ??
    '';

String _monthVi(int month) =>
    const {
      1: 'Th1',
      2: 'Th2',
      3: 'Th3',
      4: 'Th4',
      5: 'Th5',
      6: 'Th6',
      7: 'Th7',
      8: 'Th8',
      9: 'Th9',
      10: 'Th10',
      11: 'Th11',
      12: 'Th12',
    }[month] ??
    '';
