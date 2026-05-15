import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoginView();
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.width >= 600;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      // Không đặt BlocListener ở đây — AuthError đã được xử lý
      // hoàn toàn bên trong LoginForm (BlocConsumer).
      // Giữ BlocListener ở nhiều nơi cho cùng 1 state sẽ gây double SnackBar.
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: isTablet ? _TabletLayout() : _PhoneLayout(),
      ),
    );
  }
}

// ── Phone layout ──────────────────────────────────────────────────────────────
class _PhoneLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Gap(48),
            const _LogoBlock(),
            const Gap(40),
            const LoginForm(),
            const Gap(32),
            const _FooterText(),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}

// ── Tablet layout ─────────────────────────────────────────────────────────────
class _TabletLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 5, child: _BrandPanel()),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(32),
                    _TabletFormHeader(),
                    const Gap(32),
                    const LoginForm(),
                    const Gap(32),
                    const _FooterText(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Brand panel ───────────────────────────────────────────────────────────────
class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A56DB), Color(0xFF0EA5E9)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const Gap(24),
              Text(
                'ĐẶC SẢN\nQUÊ HƯƠNG',
                style: GoogleFonts.dmSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
              const Gap(16),
              Text(
                'Hệ thống quản lý bán hàng\nchuyên nghiệp cho cửa hàng của bạn',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.6,
                ),
              ).animate().fadeIn(delay: 400.ms),
              const Spacer(),
              ..._features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FeatureChip(icon: f.$1, label: f.$2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _features = [
  (Icons.point_of_sale_rounded, 'Bán hàng nhanh chóng'),
  (Icons.inventory_2_rounded, 'Quản lý kho thông minh'),
  (Icons.bar_chart_rounded, 'Báo cáo chi tiết'),
  (Icons.people_rounded, 'Phân quyền linh hoạt'),
];

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const Gap(12),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Logo block (phone) ────────────────────────────────────────────────────────
class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: 36,
          ),
        ).animate().scale(
          delay: 100.ms,
          duration: 400.ms,
          curve: Curves.elasticOut,
        ),
        const Gap(16),
        Text(
          'ĐẶC SẢN QUÊ HƯƠNG',
          style: GoogleFonts.dmSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
        const Gap(6),
        Text(
          'Hệ thống quản lý bán hàng',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }
}

class _TabletFormHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đăng nhập',
          style: GoogleFonts.dmSans(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Gap(6),
        Text(
          'Nhập thông tin tài khoản để tiếp tục',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _FooterText extends StatelessWidget {
  const _FooterText();

  @override
  Widget build(BuildContext context) {
    return Text(
      '© 2025 Đặc Sản Quê Hương. All rights reserved.',
      textAlign: TextAlign.center,
      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textHint),
    );
  }
}
