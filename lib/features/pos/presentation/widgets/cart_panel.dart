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
          // Checkout button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: state.status == PosStatus.loading ? null : onCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
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
                  : Text(
                      'Thanh toán',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
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
