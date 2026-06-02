import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/pos_bloc.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key, required this.onCheckout});
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (ctx, state) {
        return Column(
          children: [
            // ── Header ───────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Giỏ hàng',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (!state.cartEmpty)
                    TextButton.icon(
                      onPressed: () =>
                          ctx.read<PosBloc>().add(const PosCartCleared()),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AppColors.error,
                      ),
                      label: Text(
                        'Xoá tất cả',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // ── Items ─────────────────────────────────────────
            Expanded(
              child: state.cartEmpty
                  ? _EmptyCart()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: state.cartItems.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 16,
                        color: AppColors.border,
                      ),
                      itemBuilder: (ctx, i) =>
                          _CartItemTile(item: state.cartItems[i]),
                    ),
            ),

            // ── Footer ────────────────────────────────────────
            if (!state.cartEmpty) ...[
              const Divider(height: 1, color: AppColors.border),
              _CartFooter(state: state, onCheckout: onCheckout),
            ],
          ],
        );
      },
    );
  }
}

// ── Empty cart ────────────────────────────────────────────────────────────────
class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 48,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có sản phẩm nào',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chọn sản phẩm từ danh sách bên cạnh',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Cart item tile ─────────────────────────────────────────────────────────────
class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Name + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPrice(item.product.price),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Quantity controls
          _QtyControl(item: item),

          // Subtotal
          SizedBox(
            width: 70,
            child: Text(
              _formatPrice(item.subtotal),
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  const _QtyControl({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QtyBtn(
          icon: item.quantity == 1 ? Icons.delete_outline : Icons.remove,
          color: item.quantity == 1 ? AppColors.error : AppColors.textSecondary,
          onTap: () => context.read<PosBloc>().add(
            PosQuantityChanged(
              productId: item.product.id,
              quantity: item.quantity - 1,
            ),
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${item.quantity}',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _QtyBtn(
          icon: Icons.add,
          color: AppColors.primary,
          onTap: () => context.read<PosBloc>().add(
            PosQuantityChanged(
              productId: item.product.id,
              quantity: item.quantity + 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ── Cart footer ────────────────────────────────────────────────────────────────
class _CartFooter extends StatelessWidget {
  const _CartFooter({required this.state, required this.onCheckout});
  final PosState state;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Summary row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${state.itemCount} sản phẩm',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                _formatPrice(state.grandTotal),
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Action buttons row ───────────────────────────
          Row(
            children: [
              // Nút Lưu nháp
              Expanded(flex: 4, child: _SaveDraftButton()),
              const SizedBox(width: 10),
              // Nút Thanh toán
              Expanded(flex: 6, child: _CheckoutButton(onCheckout: onCheckout)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Save Draft Button ─────────────────────────────────────────────────────────

class _SaveDraftButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PosBloc, PosState>(
      // Chỉ rebuild khi status liên quan đến saveDraft thay đổi
      buildWhen: (p, c) =>
          p.status == PosStatus.savingDraft ||
          c.status == PosStatus.savingDraft,
      listenWhen: (p, c) =>
          p.status != c.status &&
          (c.status == PosStatus.saveDraftSuccess ||
              c.status == PosStatus.error),
      listener: (ctx, state) {
        // Hiện snackbar khi lưu nháp thành công
        if (state.status == PosStatus.saveDraftSuccess) {
          final orderId = state.savedDraftOrder?.id;
          ScaffoldMessenger.of(ctx)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.bookmark_added_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        orderId != null
                            ? 'Đã lưu đơn nháp #$orderId'
                            : 'Đã lưu đơn nháp',
                        style: GoogleFonts.dmSans(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF8B5CF6),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(12),
                duration: const Duration(seconds: 3),
              ),
            );

          // Reset status về idle sau khi hiện snackbar
          // để tránh kẹt ở saveDraftSuccess
          Future.microtask(
            () => ctx.read<PosBloc>().add(const PosDraftConsumed()),
          );
        }
        if (state.status == PosStatus.error) {
          ScaffoldMessenger.of(ctx)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Lưu nháp thất bại'),
                backgroundColor: Colors.red,
              ),
            );
        }
      },
      builder: (ctx, state) {
        final isSaving = state.status == PosStatus.savingDraft;
        final isDisabled =
            state.isProcessing || state.status == PosStatus.saveDraftSuccess;

        return SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: isDisabled
                ? null
                : () => ctx.read<PosBloc>().add(const PosSaveDraftRequested()),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: isDisabled ? AppColors.border : const Color(0xFF8B5CF6),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: const Color(0xFF8B5CF6),
              disabledForegroundColor: AppColors.textHint,
              padding: EdgeInsets.zero,
            ),
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B5CF6),
                      strokeWidth: 2,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark_outline_rounded, size: 16),
                      const SizedBox(height: 2),
                      Text(
                        'Lưu nháp',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ── Checkout Button ───────────────────────────────────────────────────────────

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({required this.onCheckout});
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      buildWhen: (p, c) => p.isProcessing != c.isProcessing,
      builder: (ctx, state) => SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: state.isProcessing ? null : onCheckout,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: state.status == PosStatus.loading
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
                    const Icon(Icons.payments_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Thanh toán',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

String _formatPrice(double price) {
  final n = price.toInt();
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '$bufđ';
}
