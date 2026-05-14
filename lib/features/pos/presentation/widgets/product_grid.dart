import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../bloc/pos_bloc.dart';

// Mock products — thay bằng BLoC gọi API thật sau
final _mockProducts = List.generate(12, (i) {
  final names = [
    'Mắm tép',
    'Nước mắm',
    'Bánh đa',
    'Nem chua',
    'Chả lụa',
    'Bánh chưng',
    'Dưa cải',
    'Tương bần',
    'Rượu nếp',
    'Bánh cuốn',
    'Phở khô',
    'Bún bò',
  ];
  final prices = [
    25000,
    45000,
    18000,
    35000,
    50000,
    80000,
    22000,
    30000,
    60000,
    40000,
    55000,
    65000,
  ];
  return ProductEntity(
    id: i + 1,
    name: names[i % names.length],
    price: prices[i % prices.length].toDouble(),
    unit: 'gói',
    stock: 20 - i,
  );
});

class ProductGrid extends StatefulWidget {
  const ProductGrid({super.key});

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _mockProducts
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Column(
      children: [
        // ── Search bar ─────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm...',
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: AppColors.textSecondary,
              ),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
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

        const Divider(height: 1, color: AppColors.border),

        // ── Grid ───────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'Không tìm thấy sản phẩm',
                    style: GoogleFonts.dmSans(color: AppColors.textSecondary),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _ProductCard(product: filtered[i]),
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
    final outOfStock = (product.stock ?? 1) <= 0;

    return BlocBuilder<PosBloc, PosState>(
      buildWhen: (p, c) =>
          p.cart[product.id]?.quantity != c.cart[product.id]?.quantity,
      builder: (ctx, state) {
        final inCart = state.cart[product.id];
        final qty = inCart?.quantity ?? 0;
        final selected = qty > 0;

        return GestureDetector(
          onTap: outOfStock
              ? null
              : () => ctx.read<PosBloc>().add(PosProductAdded(product)),
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
                      // Icon placeholder
                      Expanded(
                        child: Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: outOfStock
                                  ? AppColors.surfaceAlt
                                  : selected
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 26,
                              color: outOfStock
                                  ? AppColors.textHint
                                  : selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: outOfStock
                              ? AppColors.textHint
                              : AppColors.textPrimary,
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
                          color: outOfStock
                              ? AppColors.textHint
                              : AppColors.primary,
                        ),
                      ),
                      if (outOfStock)
                        Text(
                          'Hết hàng',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppColors.error,
                          ),
                        ),
                    ],
                  ),
                ),

                // Badge số lượng
                if (qty > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
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
