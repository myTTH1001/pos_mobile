// lib/features/orders/presentation/pages/orders_page.dart
//
// Orders History — đầy đủ:
//   • List orders với pagination (load more on scroll)
//   • Filter: status chips + date range picker
//   • Phone: list → tap → bottom sheet detail
//   • Tablet: split view (list bên trái, detail bên phải)
//   • Actions: Cancel order, Reorder (tạo đơn mới từ đơn cũ)

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/order_entity.dart';
import '../bloc/orders_bloc.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OrdersBloc()..add(const OrdersLoadRequested()),
      child: const _OrdersView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersView extends StatelessWidget {
  const _OrdersView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrdersBloc, OrdersState>(
      listenWhen: (p, c) =>
          p.actionStatus != c.actionStatus ||
          p.reorderedOrder != c.reorderedOrder,
      listener: (ctx, state) {
        if (state.actionStatus == OrdersActionStatus.success &&
            state.reorderedOrder != null) {
          // Reorder thành công → thông báo + navigate về POS
          _showSnack(
            ctx,
            '✓ Đã tạo đơn mới #${state.reorderedOrder!.id} — chuyển sang POS',
            AppColors.success,
          );
          // Xóa reorderedOrder khỏi state sau khi xử lý
          ctx.read<OrdersBloc>().add(const OrderDetailCleared());
          Future.delayed(const Duration(milliseconds: 800), () {
            if (ctx.mounted) ctx.go('/pos');
          });
        } else if (state.actionStatus == OrdersActionStatus.success &&
            state.reorderedOrder == null &&
            state.actionError == null) {
          _showSnack(ctx, '✓ Đã hủy đơn hàng', AppColors.success);
        } else if (state.actionStatus == OrdersActionStatus.failure) {
          _showSnack(
            ctx,
            state.actionError ?? 'Có lỗi xảy ra',
            AppColors.error,
          );
        }
      },
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isTablet = constraints.maxWidth >= 700;
          return isTablet ? const _TabletLayout() : const _PhoneLayout();
        },
      ),
    );
  }

  void _showSnack(BuildContext ctx, String msg, Color color) {
    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHONE LAYOUT
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const _OrdersHeader(),
          const _FilterBar(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _OrdersList(
              onTap: (order) => _showDetailSheet(context, order),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET LAYOUT — split view
// ─────────────────────────────────────────────────────────────────────────────

class _TabletLayout extends StatelessWidget {
  const _TabletLayout();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const _OrdersHeader(),
          const _FilterBar(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: Row(
              children: [
                // List (40%)
                SizedBox(
                  width: 380,
                  child: _OrdersList(
                    onTap: (order) => context.read<OrdersBloc>().add(
                      OrderDetailSelected(order),
                    ),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
                // Detail panel (60%)
                Expanded(
                  child: BlocBuilder<OrdersBloc, OrdersState>(
                    buildWhen: (p, c) => p.selectedOrder != c.selectedOrder,
                    builder: (_, state) {
                      if (state.selectedOrder == null) {
                        return const _DetailEmptyState();
                      }
                      return _OrderDetailPanel(order: state.selectedOrder!);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.confirmed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_outlined,
              color: AppColors.confirmed,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lịch sử đơn hàng',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                BlocBuilder<OrdersBloc, OrdersState>(
                  buildWhen: (p, c) =>
                      p.total != c.total || p.status != c.status,
                  builder: (_, state) => Text(
                    state.status == OrdersStatus.initial
                        ? 'Tất cả đơn hàng'
                        : 'Tổng ${state.total} đơn hàng',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Refresh
          BlocBuilder<OrdersBloc, OrdersState>(
            buildWhen: (p, c) => p.status != c.status,
            builder: (ctx, state) => IconButton(
              onPressed: state.status == OrdersStatus.loading
                  ? null
                  : () => ctx.read<OrdersBloc>().add(
                      const OrdersLoadRequested(refresh: true),
                    ),
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Tải lại',
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER BAR
// ─────────────────────────────────────────────────────────────────────────────

const _statusFilters = [
  (null, 'Tất cả', AppColors.textSecondary),
  ('draft', 'Nháp', AppColors.draft),
  ('confirmed', 'Confirmed', AppColors.confirmed),
  ('paid', 'Đã TT', AppColors.paid),
  ('cancelled', 'Đã hủy', AppColors.cancelled),
];

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: BlocBuilder<OrdersBloc, OrdersState>(
        buildWhen: (p, c) =>
            p.statusFilter != c.statusFilter ||
            p.startDate != c.startDate ||
            p.endDate != c.endDate,
        builder: (ctx, state) => Row(
          children: [
            // Status chips
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusFilters.map((f) {
                    final (value, label, color) = f;
                    final selected = value == state.statusFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: label,
                        color: color,
                        selected: selected,
                        onTap: () => ctx.read<OrdersBloc>().add(
                          OrdersFilterChanged(
                            status: value,
                            startDate: state.startDate,
                            endDate: state.endDate,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Date range picker
            _DateRangeButton(state: state),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  const _DateRangeButton({required this.state});
  final OrdersState state;

  @override
  Widget build(BuildContext context) {
    final hasDate = state.startDate != null || state.endDate != null;
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: now,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null && context.mounted) {
          final fmt = DateFormat('yyyy-MM-dd');
          context.read<OrdersBloc>().add(
            OrdersFilterChanged(
              status: state.statusFilter,
              startDate: fmt.format(picked.start),
              endDate: fmt.format(picked.end),
            ),
          );
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasDate
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: hasDate ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: hasDate ? AppColors.primary : AppColors.textSecondary,
                ),
                if (hasDate) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => context.read<OrdersBloc>().add(
                      const OrdersFilterCleared(),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDERS LIST
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersList extends StatefulWidget {
  const _OrdersList({required this.onTap});
  final void Function(Order) onTap;

  @override
  State<_OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<_OrdersList> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<OrdersBloc>().add(const OrdersLoadMore());
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersBloc, OrdersState>(
      buildWhen: (p, c) =>
          p.status != c.status ||
          p.orders != c.orders ||
          p.selectedOrder?.id != c.selectedOrder?.id,
      builder: (ctx, state) {
        if (state.status == OrdersStatus.initial ||
            state.status == OrdersStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          );
        }

        if (state.status == OrdersStatus.failure) {
          return _ErrorBody(
            message: state.errorMessage,
            onRetry: () =>
                ctx.read<OrdersBloc>().add(const OrdersLoadRequested()),
          );
        }

        if (state.orders.isEmpty) {
          return _EmptyBody(hasFilter: state.hasActiveFilter);
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ctx.read<OrdersBloc>().add(
            const OrdersLoadRequested(refresh: true),
          ),
          child: ListView.separated(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: state.orders.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              if (i == state.orders.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }
              final order = state.orders[i];
              final isSelected = state.selectedOrder?.id == order.id;
              return _OrderCard(
                order: order,
                isSelected: isSelected,
                onTap: () => widget.onTap(order),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onTap,
    this.isSelected = false,
  });
  final Order order;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(order.status);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: ID + Status + Time
              Row(
                children: [
                  // Order ID
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${order.id}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  _StatusBadge(status: order.status),
                  const Spacer(),
                  // Time
                  Text(
                    _formatTime(order.createdAt),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Items summary
              Text(
                _itemsSummary(order.items),
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Row 3: Total + Payment method (if paid)
              Row(
                children: [
                  // Item count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${order.items.length} SP',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (order.invoice != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.paid.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _paymentLabel(order.invoice!.paymentMethod),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.paid,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _formatPrice(order.total),
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cfg.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDER DETAIL (dùng cho cả bottom sheet và tablet panel)
// ─────────────────────────────────────────────────────────────────────────────

class _OrderDetailContent extends StatelessWidget {
  const _OrderDetailContent({required this.order, this.onClose});
  final Order order;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(order.status);
    final canCancel = order.status == 'draft' || order.status == 'confirmed';
    final canReorder = order.items.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Đơn hàng #${order.id}',
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(order.createdAt),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),

        const Divider(height: 1, color: AppColors.border),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Items ──────────────────────────────────────
                _SectionTitle('Sản phẩm', Icons.inventory_2_outlined),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: order.items
                        .map((item) => _ItemRow(item: item))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Total ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cfg.color.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      _TotalRow(
                        label: 'Tạm tính',
                        value: _formatPrice(order.total),
                      ),
                      if (order.invoice != null) ...[
                        const SizedBox(height: 6),
                        _TotalRow(
                          label: 'Phương thức',
                          value: _paymentLabel(order.invoice!.paymentMethod),
                          isHighlight: false,
                        ),
                        if (order.invoice!.paidAt != null) ...[
                          const SizedBox(height: 6),
                          _TotalRow(
                            label: 'Thanh toán lúc',
                            value: _formatDateTime(order.invoice!.paidAt!),
                            isHighlight: false,
                          ),
                        ],
                      ],
                      const Divider(height: 16, color: AppColors.border),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tổng cộng',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _formatPrice(order.total),
                            style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: cfg.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Actions ───────────────────────────────────
                BlocBuilder<OrdersBloc, OrdersState>(
                  buildWhen: (p, c) =>
                      p.actionStatus != c.actionStatus ||
                      p.actionOrderId != c.actionOrderId,
                  builder: (ctx, state) {
                    final isLoading =
                        state.actionStatus == OrdersActionStatus.loading &&
                        state.actionOrderId == order.id;

                    return Column(
                      children: [
                        // Reorder
                        if (canReorder)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : () => ctx.read<OrdersBloc>().add(
                                      OrderReorderRequested(order),
                                    ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(
                                'Đặt lại đơn này',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                        if (canReorder && canCancel) const SizedBox(height: 10),

                        // Cancel
                        if (canCancel)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : () => _confirmCancel(ctx, order),
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: Text(
                                'Hủy đơn hàng',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(
                              color: AppColors.primary,
                              backgroundColor: AppColors.surfaceAlt,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL PANEL (tablet)
// ─────────────────────────────────────────────────────────────────────────────

class _OrderDetailPanel extends StatelessWidget {
  const _OrderDetailPanel({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: _OrderDetailContent(
        order: order,
        onClose: () =>
            context.read<OrdersBloc>().add(const OrderDetailCleared()),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL BOTTOM SHEET (phone)
// ─────────────────────────────────────────────────────────────────────────────

void _showDetailSheet(BuildContext context, Order order) {
  // Cập nhật selectedOrder để actions trong detail hoạt động
  context.read<OrdersBloc>().add(OrderDetailSelected(order));

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<OrdersBloc>(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Expanded(
                child: BlocBuilder<OrdersBloc, OrdersState>(
                  buildWhen: (p, c) => p.selectedOrder != c.selectedOrder,
                  builder: (ctx, state) {
                    final currentOrder = state.selectedOrder ?? order;
                    return _OrderDetailContent(
                      order: currentOrder,
                      onClose: () => Navigator.pop(ctx),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    // Clear selection khi đóng sheet
    if (context.mounted) {
      context.read<OrdersBloc>().add(const OrderDetailCleared());
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CANCEL CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────────────────────

void _confirmCancel(BuildContext context, Order order) {
  final reasonCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<OrdersBloc>(),
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_outlined,
                size: 20,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Hủy đơn #${order.id}?',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hành động này không thể hoàn tác.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Lý do hủy (tùy chọn)',
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              style: GoogleFonts.dmSans(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Thôi',
              style: GoogleFonts.dmSans(color: AppColors.textSecondary),
            ),
          ),
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ctx.read<OrdersBloc>().add(
                  OrderCancelRequested(
                    orderId: order.id,
                    reason: reasonCtrl.text.trim().isEmpty
                        ? null
                        : reasonCtrl.text.trim(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Hủy đơn',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cfg.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        cfg.label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cfg.color,
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${item.quantity}',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatPrice(item.price) + '/SP',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatPrice(item.subtotal),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });
  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DetailEmptyState extends StatelessWidget {
  const _DetailEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn đơn hàng để xem chi tiết',
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

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter ? 'Không có đơn hàng phù hợp' : 'Chưa có đơn hàng nào',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () =>
                    context.read<OrdersBloc>().add(const OrdersFilterCleared()),
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Xóa bộ lọc'),
              ),
            ],
          ],
        ),
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
              message ?? 'Không thể tải đơn hàng',
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

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _StatusConfig {
  const _StatusConfig({required this.label, required this.color});
  final String label;
  final Color color;
}

_StatusConfig _statusConfig(String status) => switch (status) {
  'draft' => const _StatusConfig(label: 'Nháp', color: AppColors.draft),
  'confirmed' => const _StatusConfig(
    label: 'Confirmed',
    color: AppColors.confirmed,
  ),
  'paid' => const _StatusConfig(label: 'Đã TT', color: AppColors.paid),
  'cancelled' => const _StatusConfig(
    label: 'Đã hủy',
    color: AppColors.cancelled,
  ),
  _ => const _StatusConfig(label: 'Khác', color: AppColors.textSecondary),
};

String _formatPrice(double v) {
  final n = v.toInt();
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '$bufđ';
}

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
  if (diff.inDays < 1) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return DateFormat('dd/MM/yyyy').format(dt);
}

String _formatDateTime(DateTime dt) =>
    DateFormat('HH:mm — dd/MM/yyyy').format(dt);

String _itemsSummary(List<OrderItem> items) {
  if (items.isEmpty) return 'Không có sản phẩm';
  final parts = items.take(3).map((e) => '${e.productName} x${e.quantity}');
  final extra = items.length > 3 ? ' +${items.length - 3} SP khác' : '';
  return parts.join(', ') + extra;
}

String _paymentLabel(String method) => switch (method) {
  'cash' => 'Tiền mặt',
  'card' => 'Thẻ',
  'transfer' => 'Chuyển khoản',
  _ => method,
};
