import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/pos_bloc.dart';
import '../widgets/product_grid.dart';
import '../widgets/cart_panel.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/success_dialog.dart';

class PosPage extends StatelessWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => PosBloc(), child: const _PosView());
  }
}

class _PosView extends StatefulWidget {
  const _PosView();

  @override
  State<_PosView> createState() => _PosViewState();
}

class _PosViewState extends State<_PosView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return BlocListener<PosBloc, PosState>(
      listener: (ctx, state) {
        if (state.status == PosStatus.success && state.completedOrder != null) {
          showDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (_) => SuccessDialog(
              order: state.completedOrder!,
              onNewOrder: () {
                Navigator.pop(ctx);
                ctx.read<PosBloc>().add(const PosReset());
              },
            ),
          );
        }

        if (state.status == PosStatus.error) {
          ScaffoldMessenger.of(ctx)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Có lỗi xảy ra'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(12),
              ),
            );
        }
      },
      child: isTablet
          ? _TabletLayout(tabController: _tabController)
          : _PhoneLayout(tabController: _tabController),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHONE: TabBar (Sản phẩm | Giỏ hàng)
// ─────────────────────────────────────────────────────────────────────────────
class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({required this.tabController});
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Bán hàng',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Badge giỏ hàng
          BlocBuilder<PosBloc, PosState>(
            buildWhen: (p, c) => p.itemCount != c.itemCount,
            builder: (ctx, state) => IconButton(
              onPressed: state.cartEmpty
                  ? null
                  : () => tabController.animateTo(1),
              icon: Badge(
                isLabelVisible: state.itemCount > 0,
                label: Text(
                  '${state.itemCount}',
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Sản phẩm'),
            Tab(text: 'Giỏ hàng'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          const ProductGrid(),
          CartPanel(onCheckout: () => _showPaymentSheet(context)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET: Split view — sản phẩm trái, giỏ hàng phải
// ─────────────────────────────────────────────────────────────────────────────
class _TabletLayout extends StatelessWidget {
  const _TabletLayout({required this.tabController});
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Bán hàng',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Row(
        children: [
          // Danh sách sản phẩm (60%)
          const Expanded(flex: 6, child: ProductGrid()),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.border,
          ),
          // Giỏ hàng (40%)
          Expanded(
            flex: 4,
            child: CartPanel(onCheckout: () => _showPaymentSheet(context)),
          ),
        ],
      ),
    );
  }
}

void _showPaymentSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<PosBloc>(),
      child: const PaymentSheet(),
    ),
  );
}
