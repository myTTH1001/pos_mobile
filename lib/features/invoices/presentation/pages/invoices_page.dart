// lib/features/invoices/presentation/pages/invoices_page.dart
//
// Invoices Page — đầy đủ:
//   • List invoices + pagination
//   • Filter: status (paid/cancelled) + payment method + date range
//   • Phone: list → bottom sheet detail
//   • Tablet: split view
//   • Cancel invoice với confirm dialog
//   • In hóa đơn qua printing package (flutter_to_pdf)
//
// Dependency cần thêm vào pubspec.yaml:
//   printing: ^5.13.1
//   pdf: ^3.10.8

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/printing/thermal_printer_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/invoices_bloc.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

class InvoicesPage extends StatelessWidget {
  const InvoicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InvoicesBloc()..add(const InvoicesLoadRequested()),
      child: const _InvoicesView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _InvoicesView extends StatelessWidget {
  const _InvoicesView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<InvoicesBloc, InvoicesState>(
      listenWhen: (p, c) => p.actionStatus != c.actionStatus,
      listener: (ctx, state) {
        if (state.actionStatus == InvoicesActionStatus.success) {
          _showSnack(ctx, '✓ Đã hủy hóa đơn', AppColors.success);
        } else if (state.actionStatus == InvoicesActionStatus.failure) {
          _showSnack(
            ctx,
            state.actionError ?? 'Có lỗi xảy ra',
            AppColors.error,
          );
        }
      },
      child: LayoutBuilder(
        builder: (_, constraints) => constraints.maxWidth >= 700
            ? const _TabletLayout()
            : const _PhoneLayout(),
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
          duration: const Duration(seconds: 2),
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
          const _InvoicesHeader(),
          const _SummaryStrip(),
          const _FilterBar(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _InvoicesList(
              onTap: (inv) => _showDetailSheet(context, inv),
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
          const _InvoicesHeader(),
          const _SummaryStrip(),
          const _FilterBar(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 380,
                  child: _InvoicesList(
                    onTap: (inv) => context.read<InvoicesBloc>().add(
                      InvoiceDetailSelected(inv),
                    ),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
                Expanded(
                  child: BlocBuilder<InvoicesBloc, InvoicesState>(
                    buildWhen: (p, c) => p.selectedInvoice != c.selectedInvoice,
                    builder: (_, state) => state.selectedInvoice == null
                        ? const _DetailEmptyState()
                        : _InvoiceDetailPanel(invoice: state.selectedInvoice!),
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

class _InvoicesHeader extends StatelessWidget {
  const _InvoicesHeader();

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
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hóa đơn',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                BlocBuilder<InvoicesBloc, InvoicesState>(
                  buildWhen: (p, c) =>
                      p.total != c.total || p.status != c.status,
                  builder: (_, state) => Text(
                    state.status == InvoicesStatus.initial
                        ? 'Tất cả hóa đơn'
                        : 'Tổng ${state.total} hóa đơn',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          BlocBuilder<InvoicesBloc, InvoicesState>(
            buildWhen: (p, c) => p.status != c.status,
            builder: (ctx, state) => IconButton(
              onPressed: state.status == InvoicesStatus.loading
                  ? null
                  : () => ctx.read<InvoicesBloc>().add(
                      const InvoicesLoadRequested(refresh: true),
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
// SUMMARY STRIP — tổng doanh thu từ list hiện tại
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InvoicesBloc, InvoicesState>(
      buildWhen: (p, c) => p.invoices != c.invoices || p.status != c.status,
      builder: (_, state) {
        if (state.status == InvoicesStatus.initial || state.invoices.isEmpty) {
          return const SizedBox.shrink();
        }

        final paid = state.invoices.where((i) => i.status == 'paid');
        final totalRevenue = paid.fold(0.0, (s, i) => s + i.total);
        final countPaid = paid.length;
        final countCancelled = state.invoices
            .where((i) => i.status == 'cancelled')
            .length;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _StatChip(
                label: 'Đã TT',
                value: '$countPaid',
                color: AppColors.paid,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Đã hủy',
                value: '$countCancelled',
                color: AppColors.cancelled,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatPrice(totalRevenue),
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    'Doanh thu trong kỳ',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER BAR
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  static const _statusFilters = [
    (null, 'Tất cả'),
    ('paid', 'Đã TT'),
    ('cancelled', 'Đã hủy'),
  ];

  static const _methodFilters = [
    (null, 'Tất cả'),
    ('cash', 'Tiền mặt'),
    ('card', 'Thẻ'),
    ('transfer', 'CK'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: BlocBuilder<InvoicesBloc, InvoicesState>(
        buildWhen: (p, c) =>
            p.statusFilter != c.statusFilter ||
            p.paymentMethodFilter != c.paymentMethodFilter ||
            p.startDate != c.startDate ||
            p.endDate != c.endDate,
        builder: (ctx, state) => Column(
          children: [
            // Row 1: Status + Date
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statusFilters.map((f) {
                        final (value, label) = f;
                        final color = value == 'paid'
                            ? AppColors.paid
                            : value == 'cancelled'
                            ? AppColors.cancelled
                            : AppColors.textSecondary;
                        final selected = value == state.statusFilter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: label,
                            color: color,
                            selected: selected,
                            onTap: () => ctx.read<InvoicesBloc>().add(
                              InvoicesFilterChanged(
                                status: value,
                                paymentMethod: state.paymentMethodFilter,
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
                _DateRangeButton(state: state),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Payment method
            Row(
              children: [
                Text(
                  'Thanh toán:',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                ..._methodFilters.map((f) {
                  final (value, label) = f;
                  final selected = value == state.paymentMethodFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: label,
                      color: AppColors.primary,
                      selected: selected,
                      onTap: () => ctx.read<InvoicesBloc>().add(
                        InvoicesFilterChanged(
                          status: state.statusFilter,
                          paymentMethod: value,
                          startDate: state.startDate,
                          endDate: state.endDate,
                        ),
                      ),
                    ),
                  );
                }),
                if (state.hasActiveFilter) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () => ctx.read<InvoicesBloc>().add(
                      const InvoicesFilterCleared(),
                    ),
                    child: Text(
                      'Xóa lọc',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
  final InvoicesState state;

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
                primary: AppColors.accent,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null && context.mounted) {
          final fmt = DateFormat('yyyy-MM-dd');
          context.read<InvoicesBloc>().add(
            InvoicesFilterChanged(
              status: state.statusFilter,
              paymentMethod: state.paymentMethodFilter,
              startDate: fmt.format(picked.start),
              endDate: fmt.format(picked.end),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasDate
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: hasDate ? AppColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 14,
              color: hasDate ? AppColors.accent : AppColors.textSecondary,
            ),
            if (hasDate) ...[
              const SizedBox(width: 4),
              Text(
                '${_shortDate(state.startDate!)}–${_shortDate(state.endDate!)}',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _shortDate(String d) {
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return DateFormat('dd/MM').format(dt);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INVOICES LIST
// ─────────────────────────────────────────────────────────────────────────────

class _InvoicesList extends StatefulWidget {
  const _InvoicesList({required this.onTap});
  final void Function(InvoiceModel) onTap;

  @override
  State<_InvoicesList> createState() => _InvoicesListState();
}

class _InvoicesListState extends State<_InvoicesList> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        context.read<InvoicesBloc>().add(const InvoicesLoadMore());
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InvoicesBloc, InvoicesState>(
      buildWhen: (p, c) =>
          p.status != c.status ||
          p.invoices != c.invoices ||
          p.selectedInvoice?.id != c.selectedInvoice?.id,
      builder: (ctx, state) {
        if (state.status == InvoicesStatus.initial ||
            state.status == InvoicesStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2.5,
            ),
          );
        }
        if (state.status == InvoicesStatus.failure) {
          return _ErrorBody(
            message: state.errorMessage,
            onRetry: () =>
                ctx.read<InvoicesBloc>().add(const InvoicesLoadRequested()),
          );
        }
        if (state.invoices.isEmpty) {
          return _EmptyBody(hasFilter: state.hasActiveFilter);
        }

        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async => ctx.read<InvoicesBloc>().add(
            const InvoicesLoadRequested(refresh: true),
          ),
          child: ListView.separated(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: state.invoices.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              if (i == state.invoices.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }
              final inv = state.invoices[i];
              return _InvoiceCard(
                invoice: inv,
                isSelected: state.selectedInvoice?.id == inv.id,
                onTap: () => widget.onTap(inv),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INVOICE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.onTap,
    this.isSelected = false,
  });
  final InvoiceModel invoice;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice.status == 'paid';
    final statusColor = isPaid ? AppColors.paid : AppColors.cancelled;
    final methodIcon = _methodIcon(invoice.paymentMethod);

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
          child: Row(
            children: [
              // Left: method icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(methodIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),

              // Middle: info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'HD #${invoice.id}',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: invoice.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Đơn #${invoice.orderId}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _methodLabel(invoice.paymentMethod),
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.cashierName != null
                          ? 'Thu ngân: ${invoice.cashierName}'
                          : _formatTime(invoice.createdAt),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),

              // Right: total
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatPrice(invoice.total),
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    _formatTime(invoice.createdAt),
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppColors.textHint,
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
// DETAIL CONTENT (dùng cho cả sheet lẫn panel)
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceDetailContent extends StatelessWidget {
  const _InvoiceDetailContent({required this.invoice, this.onClose});
  final InvoiceModel invoice;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice.status == 'paid';
    final statusColor = isPaid ? AppColors.paid : AppColors.cancelled;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────
        Container(
          color: Colors.white,
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
                          'Hóa đơn #${invoice.id}',
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: invoice.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Đơn hàng #${invoice.orderId}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Print button
              if (isPaid) PrintInvoiceButton(invoice: invoice, compact: true),
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
                // ── Info card ────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.tag_rounded,
                        label: 'Mã hóa đơn',
                        value: '#${invoice.id}',
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _InfoRow(
                        icon: Icons.receipt_outlined,
                        label: 'Đơn hàng',
                        value: '#${invoice.orderId}',
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _InfoRow(
                        icon: _methodIcon(invoice.paymentMethod),
                        label: 'Phương thức',
                        value: _methodLabel(invoice.paymentMethod),
                      ),
                      if (invoice.cashierName != null) ...[
                        const Divider(height: 1, color: AppColors.border),
                        _InfoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Thu ngân',
                          value: invoice.cashierName!,
                        ),
                      ],
                      if (invoice.paidAt != null) ...[
                        const Divider(height: 1, color: AppColors.border),
                        _InfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Thanh toán lúc',
                          value: _formatDateTime(invoice.paidAt!),
                        ),
                      ],
                      const Divider(height: 1, color: AppColors.border),
                      _InfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Tạo lúc',
                        value: _formatDateTime(invoice.createdAt),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Total ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng tiền',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _StatusBadge(status: invoice.status),
                        ],
                      ),
                      Text(
                        _formatPrice(invoice.total),
                        style: GoogleFonts.dmSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Actions ──────────────────────────────────
                BlocBuilder<InvoicesBloc, InvoicesState>(
                  buildWhen: (p, c) =>
                      p.actionStatus != c.actionStatus ||
                      p.actionInvoiceId != c.actionInvoiceId,
                  builder: (ctx, state) {
                    final isLoading =
                        state.actionStatus == InvoicesActionStatus.loading &&
                        state.actionInvoiceId == invoice.id;

                    return Column(
                      children: [
                        // Print
                        if (isPaid) PrintInvoiceButton(invoice: invoice),
                        if (isPaid) const SizedBox(height: 10),

                        // Cancel (chỉ cho phép nếu status == paid)
                        if (isPaid)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : () => _confirmCancel(ctx, invoice),
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: Text(
                                'Hủy hóa đơn',
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
                              color: AppColors.accent,
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
// TABLET DETAIL PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceDetailPanel extends StatelessWidget {
  const _InvoiceDetailPanel({required this.invoice});
  final InvoiceModel invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: _InvoiceDetailContent(
        invoice: invoice,
        onClose: () =>
            context.read<InvoicesBloc>().add(const InvoiceDetailCleared()),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET (phone)
// ─────────────────────────────────────────────────────────────────────────────

void _showDetailSheet(BuildContext context, InvoiceModel invoice) {
  context.read<InvoicesBloc>().add(InvoiceDetailSelected(invoice));

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<InvoicesBloc>(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, _) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
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
                child: BlocBuilder<InvoicesBloc, InvoicesState>(
                  buildWhen: (p, c) => p.selectedInvoice != c.selectedInvoice,
                  builder: (ctx, state) => _InvoiceDetailContent(
                    invoice: state.selectedInvoice ?? invoice,
                    onClose: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    if (context.mounted) {
      context.read<InvoicesBloc>().add(const InvoiceDetailCleared());
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CANCEL CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────────────────────

void _confirmCancel(BuildContext context, InvoiceModel invoice) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<InvoicesBloc>(),
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
            Expanded(
              child: Text(
                'Hủy hóa đơn #${invoice.id}?',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hủy hóa đơn sẽ hoàn kho tự động và chuyển đơn hàng về trạng thái "Đã hủy". Hành động này không thể hoàn tác.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
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
                ctx.read<InvoicesBloc>().add(
                  InvoiceCancelRequested(invoice.id),
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
                'Xác nhận hủy',
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
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isPaid = status == 'paid';
    final color = isPaid ? AppColors.paid : AppColors.cancelled;
    final label = isPaid ? 'Đã TT' : 'Đã hủy';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
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
            'Chọn hóa đơn để xem chi tiết',
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
            hasFilter ? 'Không có hóa đơn phù hợp' : 'Chưa có hóa đơn nào',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.read<InvoicesBloc>().add(
                const InvoicesFilterCleared(),
              ),
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Xóa bộ lọc'),
            ),
          ],
        ],
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
            message ?? 'Không thể tải hóa đơn',
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
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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

String _methodLabel(String m) => switch (m) {
  'cash' => 'Tiền mặt',
  'card' => 'Thẻ',
  'transfer' => 'Chuyển khoản',
  _ => m,
};

IconData _methodIcon(String m) => switch (m) {
  'cash' => Icons.payments_outlined,
  'card' => Icons.credit_card_outlined,
  'transfer' => Icons.account_balance_outlined,
  _ => Icons.receipt_outlined,
};
