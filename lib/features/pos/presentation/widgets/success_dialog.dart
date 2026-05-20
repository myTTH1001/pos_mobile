// lib/features/pos/presentation/widgets/success_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/printing/thermal_printer_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../orders/domain/entities/order_entity.dart';

class SuccessDialog extends StatefulWidget {
  const SuccessDialog({
    super.key,
    required this.order,
    required this.onNewOrder,
  });

  final Order order;
  final VoidCallback onNewOrder;

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog> {
  _PrintStatus _printStatus = _PrintStatus.idle;

  @override
  void initState() {
    super.initState();
    // Dùng addPostFrameCallback để tránh gọi async trong initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoPrint();
    });
  }

  List<PrintReceiptItem> get _receiptItems => widget.order.items
      .map(
        (item) => PrintReceiptItem(
          name: item.productName,
          quantity: item.quantity,
          unitPrice: item.price,
        ),
      )
      .toList();

  /// Kiểm tra kết nối máy in; nếu đã kết nối thì in luôn.
  /// Nếu chưa → giữ trạng thái idle để người dùng chủ động nhấn.
  Future<void> _autoPrint() async {
    final connected = await ThermalPrinterService.instance.checkConnection();
    if (!mounted) return;
    if (connected) {
      await _doPrint();
    }
    // Không tự động mở dialog chọn máy in — tránh UX rác khi không có máy in
  }

  Future<void> _doPrint() async {
    if (!mounted) return;
    setState(() => _printStatus = _PrintStatus.printing);

    final invoice = widget.order.invoice;
    final bool ok;

    if (invoice != null) {
      ok = await ThermalPrinterService.instance.printPosReceipt(
        invoiceId: invoice.id,
        orderId: widget.order.id,
        paymentMethod: invoice.paymentMethod,
        total: widget.order.total,
        items: _receiptItems,
        paidAt: invoice.paidAt ?? DateTime.now(),
      );
    } else {
      // Fallback: không có invoice (hiếm, nhưng phòng thủ)
      ok = await ThermalPrinterService.instance.printPosReceipt(
        invoiceId: 0,
        orderId: widget.order.id,
        paymentMethod: 'cash',
        total: widget.order.total,
        items: _receiptItems,
        paidAt: DateTime.now(),
      );
    }

    if (!mounted) return;
    setState(
      () => _printStatus = ok ? _PrintStatus.success : _PrintStatus.failed,
    );
  }

  Future<void> _connectAndPrint() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => PrinterPickerDialog(
        onConnected: (_) {
          if (mounted) _doPrint();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Check icon ───────────────────────────────────
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 44,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Thanh toán thành công!',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Đơn hàng #${widget.order.id}',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),

            // ── Items ─────────────────────────────────────────
            ...widget.order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${item.quantity}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.productName,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _fmtPrice(item.subtotal),
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // ── Total ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng cộng',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                ),
                Text(
                  _fmtPrice(widget.order.total),
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),

            // ── Payment method ────────────────────────────────
            if (widget.order.invoice != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Phương thức',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _methodLabel(widget.order.invoice!.paymentMethod),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // ── Print status strip ───────────────────────────
            _PrintStatusStrip(
              status: _printStatus,
              onPrint: _doPrint,
              onConnect: _connectAndPrint,
            ),

            const SizedBox(height: 16),

            // ── New order button ──────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onNewOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Đơn hàng mới',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
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
// PRINT STATUS STRIP
// ─────────────────────────────────────────────────────────────────────────────

enum _PrintStatus { idle, printing, success, failed }

class _PrintStatusStrip extends StatelessWidget {
  const _PrintStatusStrip({
    required this.status,
    required this.onPrint,
    required this.onConnect,
  });

  final _PrintStatus status;
  final VoidCallback onPrint;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      _PrintStatus.idle => _buildIdle(),
      _PrintStatus.printing => _buildPrinting(),
      _PrintStatus.success => _buildSuccess(),
      _PrintStatus.failed => _buildFailed(),
    };
  }

  // Chưa có máy in kết nối → cho phép bấm kết nối
  Widget _buildIdle() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onConnect,
            icon: const Icon(Icons.bluetooth_rounded, size: 16),
            label: const Text('Kết nối & In hóa đơn'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: const BorderSide(color: AppColors.accent),
              foregroundColor: AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrinting() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Đang gửi lệnh in...',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          Text(
            'Đã in hóa đơn thành công',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.print_disabled_rounded,
            size: 16,
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'In thất bại',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.error),
            ),
          ),
          GestureDetector(
            onTap: onPrint,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Thử lại',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _fmtPrice(double price) {
  final n = price.toInt();
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '$bufđ';
}

String _methodLabel(String m) => switch (m) {
  'cash' => 'Tiền mặt',
  'card' => 'Thẻ',
  'transfer' => 'Chuyển khoản',
  _ => m,
};
