// lib/features/pos/presentation/widgets/discount_sheet.dart
//
// Bottom sheet nhập giảm giá — dùng cho cả item lẻ và toàn đơn.
// Hỗ trợ: % giảm tự do | số tiền giảm tự do

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/pos_bloc.dart' show Discount, DiscountType;

/// Gọi hàm này để mở sheet.
/// [title]      — tiêu đề hiển thị (VD: "Giảm giá: Phở bò", "Giảm giá đơn hàng")
/// [baseAmount] — giá gốc để preview (subtotal của item hoặc tổng đơn)
/// [current]    — discount hiện tại (nếu đang sửa)
/// Trả về [Discount] nếu user xác nhận, null nếu huỷ / xoá.
Future<Discount?> showDiscountSheet(
  BuildContext context, {
  required String title,
  required double baseAmount,
  Discount? current,
}) {
  return showModalBottomSheet<Discount>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _DiscountSheet(title: title, baseAmount: baseAmount, current: current),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _DiscountSheet extends StatefulWidget {
  const _DiscountSheet({
    required this.title,
    required this.baseAmount,
    this.current,
  });
  final String title;
  final double baseAmount;
  final Discount? current;

  @override
  State<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<_DiscountSheet> {
  late DiscountType _type;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _type = widget.current?.type ?? DiscountType.fixedPrice;
    final initVal = widget.current?.value;
    _ctrl = TextEditingController(
      text: initVal != null
          ? (initVal == initVal.truncateToDouble()
                ? initVal.toInt().toString()
                : initVal.toStringAsFixed(0))
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_ctrl.text) ?? 0;

  /// Số tiền thực sự được giảm (dùng để preview)
  double get _amountOff {
    if (_value <= 0) return 0;
    if (_type == DiscountType.percent) {
      return (widget.baseAmount * _value / 100).clamp(0, widget.baseAmount);
    }
    if (_type == DiscountType.fixedPrice) {
      if (_value >= widget.baseAmount) return 0;
      return (widget.baseAmount - _value).clamp(0, widget.baseAmount);
    }
    return _value.clamp(0, widget.baseAmount);
  }

  double get _afterDiscount => widget.baseAmount - _amountOff;

  /// Giá trị hợp lệ để submit
  bool get _isValid {
    if (_value <= 0) return false;
    if (_type == DiscountType.fixedPrice) return _value < widget.baseAmount;
    if (_type == DiscountType.percent) return _value > 0 && _value <= 100;
    return _value > 0 && _value < widget.baseAmount;
  }

  String _fmt(double v) {
    final n = v.toInt();
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf.toString()}đ';
  }

  void _confirm() {
    if (!_isValid) {
      Navigator.pop(context, null);
      return;
    }
    Navigator.pop(context, Discount(type: _type, value: _value));
  }

  void _remove() => Navigator.pop(context, null);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (widget.current != null)
                TextButton.icon(
                  onPressed: _remove,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppColors.error,
                  ),
                  label: Text(
                    'Xoá',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Toggle loại giảm giá — 3 tab
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _TypeTab(
                  label: 'Sửa giá',
                  selected: _type == DiscountType.fixedPrice,
                  onTap: () => setState(() {
                    _type = DiscountType.fixedPrice;
                    _ctrl.clear();
                  }),
                ),
                _TypeTab(
                  label: '% Giảm',
                  selected: _type == DiscountType.percent,
                  onTap: () => setState(() {
                    _type = DiscountType.percent;
                    _ctrl.clear();
                  }),
                ),
                _TypeTab(
                  label: 'Tiền giảm',
                  selected: _type == DiscountType.amount,
                  onTap: () => setState(() {
                    _type = DiscountType.amount;
                    _ctrl.clear();
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Giá gốc (chỉ hiện ở tab Sửa giá để tham khảo)
          if (_type == DiscountType.fixedPrice)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Giá gốc: ',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _fmt(
                      widget.baseAmount / (widget.baseAmount > 0 ? 1 : 1),
                    ), // hiện đơn giá
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
            ),

          // Input
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.dmSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: _type == DiscountType.fixedPrice
                  ? _fmt(widget.baseAmount).replaceAll('đ', '')
                  : '0',
              hintStyle: GoogleFonts.dmSans(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint,
              ),
              suffixText: _type == DiscountType.percent ? '%' : 'đ',
              suffixStyle: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Preview
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isValid
                ? Container(
                    key: ValueKey('${_type}_${_amountOff.toString()}'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _type == DiscountType.fixedPrice
                              ? Text(
                                  'Bán giá ${_fmt(_value)}  (giảm ${_fmt(_amountOff)})',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Giảm ${_fmt(_amountOff)}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    Text(
                                      'Còn lại: ${_fmt(_afterDiscount)}',
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
                  )
                : Container(
                    key: const ValueKey('hint'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.textHint,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          switch (_type) {
                            DiscountType.fixedPrice =>
                              'Nhập giá mới muốn bán (< giá gốc)',
                            DiscountType.percent => 'Nhập % giảm, tối đa 100%',
                            DiscountType.amount => 'Nhập số tiền muốn giảm',
                          },
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'Huỷ',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _isValid ? 'Áp dụng' : 'Xác nhận (không giảm)',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle tab
// ─────────────────────────────────────────────────────────────────────────────

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
