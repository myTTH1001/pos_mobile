// lib/core/printing/thermal_printer_service.dart
//
// ESC/POS Bluetooth printer service cho GOOJPRT PT-210 (58mm)

import 'dart:developer' as dev;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../features/invoices/presentation/bloc/invoices_bloc.dart'
    show InvoiceModel;
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS — chi tiết 1 dòng sản phẩm trên hóa đơn
// ─────────────────────────────────────────────────────────────────────────────

class PrintReceiptItem {
  const PrintReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final int quantity;
  final double unitPrice;

  double get subtotal => unitPrice * quantity;
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class ThermalPrinterService {
  ThermalPrinterService._();
  static final ThermalPrinterService instance = ThermalPrinterService._();

  String? _connectedAddress;
  String? get connectedAddress => _connectedAddress;
  bool get isConnected => _connectedAddress != null;

  // ── Cache CapabilityProfile — load 1 lần duy nhất ────────────────────────
  // Gọi CapabilityProfile.load() nhiều lần gây log "already loaded"
  CapabilityProfile? _profile;

  Future<CapabilityProfile> _getProfile() async {
    _profile ??= await CapabilityProfile.load();
    return _profile!;
  }

  // ── Warmup: pre-load profile lúc app khởi động ───────────────────────────
  // Gọi hàm này trong main() hoặc sau khi login để tránh delay khi in
  Future<void> warmup() async {
    try {
      await _getProfile();
      dev.log('[Printer] CapabilityProfile loaded', name: 'ThermalPrinter');
    } catch (e) {
      dev.log('[Printer] warmup failed: $e', name: 'ThermalPrinter');
    }
  }

  // ── Lấy danh sách máy in đã pair ────────────────────────────────────────

  Future<List<BluetoothInfo>> getPairedPrinters() async {
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      dev.log('[Printer] getPairedPrinters error: $e', name: 'ThermalPrinter');
      return [];
    }
  }

  // ── Kết nối ──────────────────────────────────────────────────────────────

  Future<bool> connect(String macAddress) async {
    try {
      final result = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );
      if (result) {
        _connectedAddress = macAddress;
        dev.log('[Printer] connected: $macAddress', name: 'ThermalPrinter');
      }
      return result;
    } catch (e) {
      dev.log('[Printer] connect error: $e', name: 'ThermalPrinter');
      return false;
    }
  }

  // ── Ngắt kết nối ─────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      _connectedAddress = null;
    } catch (_) {}
  }

  // ── Kiểm tra kết nối ────────────────────────────────────────────────────

  Future<bool> checkConnection() async {
    try {
      final connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) _connectedAddress = null;
      return connected;
    } catch (_) {
      return false;
    }
  }

  // ── In hóa đơn từ InvoiceModel (trang Hóa đơn) ──────────────────────────

  Future<bool> printInvoice(
    InvoiceModel invoice, {
    List<PrintReceiptItem>? items,
  }) async {
    final connected = await checkConnection();
    if (!connected) return false;
    try {
      final bytes = await _buildTicket(
        invoiceId: invoice.id,
        orderId: invoice.orderId,
        paymentMethod: invoice.paymentMethod,
        cashierName: invoice.cashierName,
        paidAt: invoice.paidAt,
        total: invoice.total,
        items: items,
      );
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      dev.log(
        '[Printer] printInvoice #${invoice.id} → $ok',
        name: 'ThermalPrinter',
      );
      return ok;
    } catch (e) {
      dev.log('[Printer] printInvoice error: $e', name: 'ThermalPrinter');
      return false;
    }
  }

  // ── In ngay sau khi thanh toán POS (có đầy đủ items) ────────────────────

  Future<bool> printPosReceipt({
    required int invoiceId,
    required int orderId,
    required String paymentMethod,
    required double total,
    required List<PrintReceiptItem> items,
    String? cashierName,
    DateTime? paidAt,
  }) async {
    final connected = await checkConnection();
    if (!connected) {
      dev.log(
        '[Printer] printPosReceipt: not connected',
        name: 'ThermalPrinter',
      );
      return false;
    }
    try {
      final bytes = await _buildTicket(
        invoiceId: invoiceId,
        orderId: orderId,
        paymentMethod: paymentMethod,
        cashierName: cashierName,
        paidAt: paidAt ?? DateTime.now(),
        total: total,
        items: items,
      );
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      dev.log(
        '[Printer] printPosReceipt order#$orderId → $ok',
        name: 'ThermalPrinter',
      );
      return ok;
    } catch (e) {
      dev.log('[Printer] printPosReceipt error: $e', name: 'ThermalPrinter');
      return false;
    }
  }

  // ── Build ESC/POS ticket ─────────────────────────────────────────────────

  Future<List<int>> _buildTicket({
    required int invoiceId,
    required int orderId,
    required String paymentMethod,
    required double total,
    List<PrintReceiptItem>? items,
    String? cashierName,
    DateTime? paidAt,
  }) async {
    // Dùng cached profile — không gọi load() lại
    final profile = await _getProfile();
    final gen = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += gen.reset();

    // ── Header store ──────────────────────────────────────────────────────
    bytes += gen.text(
      'DAC SAN QUE HUONG',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size1,
      ),
    );
    bytes += gen.text(
      'HOA DON BAN HANG',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += gen.text(
      'So: #$invoiceId',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += gen.hr();

    // ── Thông tin đơn hàng ────────────────────────────────────────────────
    bytes += gen.row([
      PosColumn(
        text: 'Don hang:',
        width: 6,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: '#$orderId',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += gen.row([
      PosColumn(
        text: 'Thanh toan:',
        width: 6,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: _methodLabel(paymentMethod),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    if (cashierName != null && cashierName.isNotEmpty) {
      bytes += gen.row([
        PosColumn(
          text: 'Thu ngan:',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: _stripDiacritics(cashierName),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
    }

    if (paidAt != null) {
      bytes += gen.row([
        PosColumn(
          text: 'Thoi gian:',
          width: 5,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: _fmtDateTime(paidAt),
          width: 7,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += gen.hr();

    // ── Chi tiết sản phẩm ─────────────────────────────────────────────────
    if (items != null && items.isNotEmpty) {
      bytes += gen.text(
        'CHI TIET SAN PHAM',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += gen.emptyLines(1);

      for (final item in items) {
        // ESC/POS 58mm ~ 32 ký tự mỗi dòng ở size thường
        // Tên sản phẩm: strip dấu tiếng Việt, cắt max 28 ký tự
        final name = _truncate(_stripDiacritics(item.name), 28);

        bytes += gen.text(name, styles: const PosStyles(bold: true));

        // Dòng 2: SL x đơn giá | thành tiền
        bytes += gen.row([
          PosColumn(
            text: '  ${item.quantity} x ${_fmtPrice(item.unitPrice)}',
            width: 7,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: _fmtPrice(item.subtotal),
            width: 5,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]);
      }

      bytes += gen.hr();

      // Số lượng mặt hàng
      final totalQty = items.fold<int>(0, (s, e) => s + e.quantity);
      bytes += gen.row([
        PosColumn(
          text: 'Tong SL:',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: '$totalQty san pham',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += gen.hr();
    }

    // ── Tổng cộng ─────────────────────────────────────────────────────────
    bytes += gen.row([
      PosColumn(
        text: 'TONG CONG',
        width: 6,
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      ),
      PosColumn(
        text: _fmtPrice(total),
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      ),
    ]);

    bytes += gen.hr();

    // ── Footer ────────────────────────────────────────────────────────────
    bytes += gen.emptyLines(1);
    bytes += gen.text(
      'Cam on quy khach!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += gen.text(
      'Hen gap lai!',
      styles: const PosStyles(align: PosAlign.center),
    );
    // bytes += gen.emptyLines(1);
    // bytes += gen.feed(1);
    bytes += gen.cut();

    return bytes;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _fmtPrice(double v) {
    final n = v.toInt();
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf}d';
  }

  String _methodLabel(String m) => switch (m) {
    'cash' => 'Tien mat',
    'card' => 'The',
    'transfer' => 'CK',
    _ => m,
  };

  String _fmtDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$h:$min $d/$mo/${dt.year}';
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max - 2)}..' : s;

  /// Xóa dấu tiếng Việt để tránh lỗi encoding ESC/POS
  String _stripDiacritics(String input) {
    const map = <String, String>{
      'à': 'a',
      'á': 'a',
      'ả': 'a',
      'ã': 'a',
      'ạ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'ặ': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ậ': 'a',
      'è': 'e',
      'é': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ẹ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ệ': 'e',
      'ì': 'i',
      'í': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ị': 'i',
      'ò': 'o',
      'ó': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ọ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ộ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ợ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ụ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ự': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'ỵ': 'y',
      'đ': 'd',
      'À': 'A',
      'Á': 'A',
      'Ả': 'A',
      'Ã': 'A',
      'Ạ': 'A',
      'Ă': 'A',
      'Ằ': 'A',
      'Ắ': 'A',
      'Ẳ': 'A',
      'Ẵ': 'A',
      'Ặ': 'A',
      'Â': 'A',
      'Ầ': 'A',
      'Ấ': 'A',
      'Ẩ': 'A',
      'Ẫ': 'A',
      'Ậ': 'A',
      'È': 'E',
      'É': 'E',
      'Ẻ': 'E',
      'Ẽ': 'E',
      'Ẹ': 'E',
      'Ê': 'E',
      'Ề': 'E',
      'Ế': 'E',
      'Ể': 'E',
      'Ễ': 'E',
      'Ệ': 'E',
      'Ì': 'I',
      'Í': 'I',
      'Ỉ': 'I',
      'Ĩ': 'I',
      'Ị': 'I',
      'Ò': 'O',
      'Ó': 'O',
      'Ỏ': 'O',
      'Õ': 'O',
      'Ọ': 'O',
      'Ô': 'O',
      'Ồ': 'O',
      'Ố': 'O',
      'Ổ': 'O',
      'Ỗ': 'O',
      'Ộ': 'O',
      'Ơ': 'O',
      'Ờ': 'O',
      'Ớ': 'O',
      'Ở': 'O',
      'Ỡ': 'O',
      'Ợ': 'O',
      'Ù': 'U',
      'Ú': 'U',
      'Ủ': 'U',
      'Ũ': 'U',
      'Ụ': 'U',
      'Ư': 'U',
      'Ừ': 'U',
      'Ứ': 'U',
      'Ử': 'U',
      'Ữ': 'U',
      'Ự': 'U',
      'Ỳ': 'Y',
      'Ý': 'Y',
      'Ỷ': 'Y',
      'Ỹ': 'Y',
      'Ỵ': 'Y',
      'Đ': 'D',
    };

    final buf = StringBuffer();
    for (final ch in input.characters) {
      buf.write(map[ch] ?? ch);
    }
    return buf.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRINTER PICKER DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class PrinterPickerDialog extends StatefulWidget {
  const PrinterPickerDialog({super.key, required this.onConnected});
  final void Function(String macAddress) onConnected;

  @override
  State<PrinterPickerDialog> createState() => _PrinterPickerDialogState();
}

class _PrinterPickerDialogState extends State<PrinterPickerDialog> {
  List<BluetoothInfo> _printers = [];
  bool _loading = true;
  String? _connectingAddress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final printers = await ThermalPrinterService.instance.getPairedPrinters();
    if (!mounted) return;
    setState(() {
      _printers = printers;
      _loading = false;
      if (printers.isEmpty) {
        _error =
            'Khong tim thay may in da ghep doi.\nVui long pair PT-210 trong Bluetooth.';
      }
    });
  }

  Future<void> _connect(BluetoothInfo printer) async {
    setState(() => _connectingAddress = printer.macAdress);
    final ok = await ThermalPrinterService.instance.connect(printer.macAdress);
    if (!mounted) return;
    setState(() => _connectingAddress = null);
    if (ok) {
      widget.onConnected(printer.macAdress);
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _error = 'Khong the ket noi ${printer.name}. Thu lai.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.print_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chọn máy in',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Máy in đã ghép đôi Bluetooth',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              )
            else if (_error != null && _printers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.bluetooth_disabled_rounded,
                      size: 48,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadPrinters,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Tải lại'),
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
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _printers.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (_, i) {
                    final p = _printers[i];
                    final isConnecting = _connectingAddress == p.macAdress;
                    final isConnected =
                        ThermalPrinterService.instance.connectedAddress ==
                        p.macAdress;
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isConnected
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isConnected
                              ? Icons.bluetooth_connected_rounded
                              : Icons.bluetooth_rounded,
                          color: isConnected
                              ? AppColors.success
                              : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        p.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        isConnected ? 'Đang kết nối' : p.macAdress,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: isConnected
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      trailing: isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : isConnected
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Đã kết nối',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textHint,
                            ),
                      onTap: isConnecting || isConnected
                          ? null
                          : () => _connect(p),
                    );
                  },
                ),
              ),

            if (_error != null && _printers.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRINT INVOICE BUTTON — dùng ở trang Hóa đơn
// ─────────────────────────────────────────────────────────────────────────────

class PrintInvoiceButton extends StatefulWidget {
  const PrintInvoiceButton({
    super.key,
    required this.invoice,
    this.items,
    this.compact = false,
  });

  final InvoiceModel invoice;
  final List<PrintReceiptItem>? items;
  final bool compact;

  @override
  State<PrintInvoiceButton> createState() => _PrintInvoiceButtonState();
}

class _PrintInvoiceButtonState extends State<PrintInvoiceButton> {
  bool _printing = false;

  Future<void> _handlePrint() async {
    final connected = await ThermalPrinterService.instance.checkConnection();
    if (!mounted) return;

    if (!connected) {
      await showDialog(
        context: context,
        builder: (_) => PrinterPickerDialog(
          onConnected: (_) {
            if (mounted) _doPrint();
          },
        ),
      );
      return;
    }
    _doPrint();
  }

  Future<void> _doPrint() async {
    if (!mounted) return;
    setState(() => _printing = true);
    final ok = await ThermalPrinterService.instance.printInvoice(
      widget.invoice,
      items: widget.items,
    );
    if (!mounted) return;
    setState(() => _printing = false);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '✓ Đã gửi lệnh in đến PT-210'
                : '✗ In thất bại. Kiểm tra kết nối.',
            style: GoogleFonts.dmSans(color: Colors.white),
          ),
          backgroundColor: ok ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return IconButton(
        onPressed: _printing ? null : _handlePrint,
        icon: _printing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            : const Icon(Icons.print_rounded),
        color: AppColors.accent,
        tooltip: 'In hóa đơn (PT-210)',
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _printing ? null : _handlePrint,
        icon: _printing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.print_rounded, size: 18),
        label: Text(
          _printing ? 'Đang in...' : 'In hóa đơn (PT-210)',
          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
