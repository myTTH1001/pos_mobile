// lib/core/printing/thermal_printer_service.dart
//
// ESC/POS Bluetooth printer service cho GOOJPRT PT-210 (58mm)
//
// pubspec.yaml — thêm:
//   print_bluetooth_thermal: ^2.1.2
//   esc_pos_utils_plus: ^2.0.4
//
// Android: android/app/src/main/AndroidManifest.xml
//   <uses-permission android:name="android.permission.BLUETOOTH" />
//   <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
//   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
//   <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
//
// iOS: ios/Runner/Info.plist
//   <key>NSBluetoothAlwaysUsageDescription</key>
//   <string>Kết nối máy in nhiệt Bluetooth</string>
//   <key>NSBluetoothPeripheralUsageDescription</key>
//   <string>Kết nối máy in nhiệt Bluetooth</string>

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../features/invoices/presentation/bloc/invoices_bloc.dart'
    show InvoiceModel;
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class ThermalPrinterService {
  ThermalPrinterService._();
  static final ThermalPrinterService instance = ThermalPrinterService._();

  // Địa chỉ máy in đã kết nối (lưu tạm trong session)
  String? _connectedAddress;
  String? get connectedAddress => _connectedAddress;
  bool get isConnected => _connectedAddress != null;

  // ── Lấy danh sách máy in đã pair ────────────────────────────────────────

  Future<List<BluetoothInfo>> getPairedPrinters() async {
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {
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
      }
      return result;
    } catch (_) {
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

  // ── In hóa đơn ───────────────────────────────────────────────────────────

  Future<bool> printInvoice(InvoiceModel invoice) async {
    final connected = await checkConnection();
    if (!connected) return false;

    try {
      final bytes = await _buildInvoiceTicket(invoice);
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  // ── Build ESC/POS ticket cho hóa đơn ────────────────────────────────────

  Future<List<int>> _buildInvoiceTicket(InvoiceModel invoice) async {
    final profile = await CapabilityProfile.load();
    // PT-210 dùng giấy 58mm → PaperSize.mm58
    final gen = Generator(PaperSize.mm58, profile);

    List<int> bytes = [];

    // Reset
    bytes += gen.reset();

    // ── Store header ──────────────────────────────────────────────────────
    bytes += gen.text(
      'DAC SAN QUE HUONG',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += gen.text(
      'HOA DON BAN HANG',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += gen.text(
      'So: #${invoice.id}',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += gen.hr();

    // ── Invoice info ──────────────────────────────────────────────────────
    bytes += gen.row([
      PosColumn(
        text: 'Don hang:',
        width: 6,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: '#${invoice.orderId}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += gen.row([
      PosColumn(
        text: 'Phuong thuc:',
        width: 6,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: _methodLabel(invoice.paymentMethod),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    if (invoice.cashierName != null) {
      bytes += gen.row([
        PosColumn(
          text: 'Thu ngan:',
          width: 6,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: invoice.cashierName!,
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
    }

    if (invoice.paidAt != null) {
      bytes += gen.row([
        PosColumn(
          text: 'Thoi gian:',
          width: 5,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: _formatDateTimeShort(invoice.paidAt!),
          width: 7,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += gen.hr();

    // ── Total ─────────────────────────────────────────────────────────────
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
        text: _formatPrice(invoice.total),
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
    bytes += gen.text(
      'Cam on quy khach!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += gen.text(
      'Hen gap lai!',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Feed & cut
    bytes += gen.feed(3);
    bytes += gen.cut();

    return bytes;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatPrice(double v) {
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
    'transfer' => 'Chuyen khoan',
    _ => m,
  };

  String _formatDateTimeShort(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$h:$min $d/$mo/${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRINTER PICKER DIALOG
// Dialog để chọn máy in từ danh sách paired + kết nối
// ─────────────────────────────────────────────────────────────────────────────

class PrinterPickerDialog extends StatefulWidget {
  const PrinterPickerDialog({super.key, required this.onConnected});

  /// Callback khi đã kết nối thành công — truyền địa chỉ MAC
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
    if (mounted) {
      setState(() {
        _printers = printers;
        _loading = false;
        if (printers.isEmpty) {
          _error =
              'Không tìm thấy máy in đã ghép đôi.\nVui lòng pair PT-210 trong cài đặt Bluetooth của điện thoại trước.';
        }
      });
    }
  }

  Future<void> _connect(BluetoothInfo printer) async {
    setState(() => _connectingAddress = printer.macAdress);
    final ok = await ThermalPrinterService.instance.connect(printer.macAdress);
    if (!mounted) return;
    setState(() => _connectingAddress = null);

    if (ok) {
      widget.onConnected(printer.macAdress);
      Navigator.pop(context);
    } else {
      setState(() => _error = 'Không thể kết nối ${printer.name}. Thử lại.');
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
            // Header
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
                          'Máy in đã ghép đôi qua Bluetooth',
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

            // Body
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
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (_, i) {
                    final printer = _printers[i];
                    final isConnecting =
                        _connectingAddress == printer.macAdress;
                    final isCurrentlyConnected =
                        ThermalPrinterService.instance.connectedAddress ==
                        printer.macAdress;

                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCurrentlyConnected
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isCurrentlyConnected
                              ? Icons.bluetooth_connected_rounded
                              : Icons.bluetooth_rounded,
                          color: isCurrentlyConnected
                              ? AppColors.success
                              : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        printer.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        isCurrentlyConnected
                            ? 'Đang kết nối'
                            : printer.macAdress,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: isCurrentlyConnected
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
                          : isCurrentlyConnected
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
                      onTap: isConnecting || isCurrentlyConnected
                          ? null
                          : () => _connect(printer),
                    );
                  },
                ),
              ),

            // Error snack (kết nối thất bại)
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
// PRINT BUTTON WIDGET
// Widget dùng chung — tự xử lý flow: kiểm tra kết nối → pick printer → in
// ─────────────────────────────────────────────────────────────────────────────

class PrintInvoiceButton extends StatefulWidget {
  const PrintInvoiceButton({
    super.key,
    required this.invoice,
    this.compact = false,
  });

  final InvoiceModel invoice;

  /// compact = true → chỉ hiện icon (dùng trong list card)
  final bool compact;

  @override
  State<PrintInvoiceButton> createState() => _PrintInvoiceButtonState();
}

class _PrintInvoiceButtonState extends State<PrintInvoiceButton> {
  bool _printing = false;

  Future<void> _handlePrint() async {
    final service = ThermalPrinterService.instance;

    // Kiểm tra xem đã kết nối chưa
    final connected = await service.checkConnection();

    if (!mounted) return;

    if (!connected) {
      // Chưa kết nối → mở dialog chọn máy in
      await showDialog(
        context: context,
        builder: (_) => PrinterPickerDialog(
          onConnected: (_) {
            // Sau khi kết nối, tự động in luôn
            if (mounted) _doPrint();
          },
        ),
      );
      return;
    }

    _doPrint();
  }

  Future<void> _doPrint() async {
    setState(() => _printing = true);
    final ok = await ThermalPrinterService.instance.printInvoice(
      widget.invoice,
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
