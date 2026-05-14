// lib/features/pos/presentation/widgets/product_grid.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../bloc/pos_bloc.dart';
import '../bloc/product_bloc.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductBloc()..add(const ProductLoadRequested()),
      child: const _ProductGridContent(),
    );
  }
}

class _ProductGridContent extends StatefulWidget {
  const _ProductGridContent();

  @override
  State<_ProductGridContent> createState() => _ProductGridContentState();
}

class _ProductGridContentState extends State<_ProductGridContent> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search bar ────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: BlocBuilder<ProductBloc, ProductState>(
            buildWhen: (p, c) => p.query != c.query,
            builder: (ctx, state) => TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  ctx.read<ProductBloc>().add(ProductSearchChanged(v)),
              decoration: InputDecoration(
                hintText: 'Tìm sản phẩm...',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: state.query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          context.read<ProductBloc>().add(
                            const ProductSearchChanged(''),
                          );
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),

        const Divider(height: 1, color: AppColors.border),

        // ── Content ───────────────────────────────────────────
        Expanded(
          child: BlocBuilder<ProductBloc, ProductState>(
            builder: (ctx, state) {
              // Loading
              if (state.status == ProductStatus.loading ||
                  state.status == ProductStatus.initial) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                );
              }

              // Error
              if (state.status == ProductStatus.failure) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        size: 48,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.errorMessage ?? 'Không thể tải sản phẩm',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => ctx.read<ProductBloc>().add(
                          const ProductLoadRequested(),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                );
              }

              // Empty
              if (state.filteredProducts.isEmpty) {
                return Center(
                  child: Text(
                    state.query.isNotEmpty
                        ? 'Không tìm thấy sản phẩm'
                        : 'Chưa có sản phẩm nào',
                    style: GoogleFonts.dmSans(color: AppColors.textSecondary),
                  ),
                );
              }

              // Grid
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async =>
                    ctx.read<ProductBloc>().add(const ProductLoadRequested()),
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: state.filteredProducts.length,
                  itemBuilder: (ctx, i) =>
                      _ProductCard(product: state.filteredProducts[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final ProductEntity product;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      buildWhen: (p, c) =>
          p.cart[product.id]?.quantity != c.cart[product.id]?.quantity,
      builder: (ctx, state) {
        final inCart = state.cart[product.id];
        final qty = inCart?.quantity ?? 0;
        final selected = qty > 0;

        return GestureDetector(
          onTap: () => ctx.read<PosBloc>().add(PosProductAdded(product)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryLight : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon / image
                      Expanded(
                        child: Center(
                          child: _ProductImage(
                            imageUrl: product.image,
                            selected: selected,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatPrice(product.price),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      if (product.unit != null)
                        Text(
                          product.unit!,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),

                // Badge số lượng trong giỏ
                if (qty > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

/// Widget hiển thị ảnh sản phẩm từ URL hoặc icon mặc định
class _ProductImage extends StatelessWidget {
  const _ProductImage({this.imageUrl, required this.selected});
  final String? imageUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // Nếu imageUrl là relative path (vd: /uploads/abc.jpg), cần ghép baseUrl
      final fullUrl = imageUrl!.startsWith('http')
          ? imageUrl!
          : 'http://192.168.100.101:8000$imageUrl';

      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          fullUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _DefaultIcon(selected: selected),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              width: 52,
              height: 52,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.primary,
                ),
              ),
            );
          },
        ),
      );
    }

    return _DefaultIcon(selected: selected);
  }
}

class _DefaultIcon extends StatelessWidget {
  const _DefaultIcon({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: 26,
        color: selected ? AppColors.primary : AppColors.textSecondary,
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
