// lib/features/auth/presentation/pages/register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/register_bloc.dart';
import '../bloc/register_state.dart';
import '../widgets/register_form.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RegisterBloc(),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatelessWidget {
  const _RegisterView();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: BlocListener<RegisterBloc, RegisterState>(
        listener: (ctx, state) {
          if (state is RegisterSuccess) {
            // Hiện SnackBar thành công rồi navigate về login
            ScaffoldMessenger.of(ctx)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          'Tạo cửa hàng "${state.storeName}" thành công! Vui lòng đăng nhập.',
                          style: GoogleFonts.dmSans(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(12),
                ),
              );

            // Navigate về login — dùng go() để xóa register khỏi stack
            ctx.go(AppRoutes.login);
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF0F4FF),
          body: isTablet ? const _TabletLayout() : const _PhoneLayout(),
        ),
      ),
    );
  }
}

// ── Phone layout ──────────────────────────────────────────────────────────────
class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout();

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
            const Gap(32),
            // Heading
            Text(
              'Tạo cửa hàng mới',
              style: GoogleFonts.dmSans(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Gap(6),
            Text(
              'Điền thông tin bên dưới để bắt đầu',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const Gap(28),
            const RegisterForm(),
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
  const _TabletLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Brand panel bên trái — giữ consistent với LoginPage
        Expanded(
          flex: 5,
          child: Container(
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
                      'Tạo cửa hàng trong vài giây.\nQuản lý bán hàng chuyên nghiệp.',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.6,
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                    const Spacer(),
                    ..._steps.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _StepChip(number: s.$1, label: s.$2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Form bên phải
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
                    const Gap(16),
                    Text(
                      'Tạo cửa hàng mới',
                      style: GoogleFonts.dmSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      'Điền thông tin bên dưới để bắt đầu',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Gap(32),
                    const RegisterForm(),
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

const _steps = [
  ('1', 'Đặt tên cửa hàng của bạn'),
  ('2', 'Tạo tài khoản quản trị'),
  ('3', 'Bắt đầu bán hàng ngay'),
];

class _StepChip extends StatelessWidget {
  const _StepChip({required this.number, required this.label});
  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
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
