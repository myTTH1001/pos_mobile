// lib/features/auth/presentation/widgets/login_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    context.read<AuthBloc>().add(
      AuthLoginRequested(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (ctx, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(ctx)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        state.message,
                        style: GoogleFonts.dmSans(color: Colors.white),
                      ),
                    ),
                  ],
                ),
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
      builder: (ctx, state) {
        final isLoading = state is AuthLoading;

        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Heading (phone only) ──────────────────
              Builder(
                builder: (context) {
                  final isTablet = MediaQuery.sizeOf(context).width >= 600;
                  if (isTablet) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đăng nhập',
                        style: GoogleFonts.dmSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Gap(6),
                      Text(
                        'Nhập thông tin tài khoản để tiếp tục',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Gap(28),
                    ],
                  );
                },
              ),

              // ── Username field ────────────────────────
              _FieldLabel(label: 'Tên đăng nhập'),
              const Gap(6),
              TextFormField(
                controller: _usernameCtrl,
                focusNode: _usernameFocus,
                enabled: !isLoading,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_passwordFocus),
                decoration: InputDecoration(
                  hintText: 'Nhập tên đăng nhập',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: _usernameFocus.hasFocus
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Vui lòng nhập tên đăng nhập';
                  }
                  if (v.trim().length < 3) {
                    return 'Tên đăng nhập tối thiểu 3 ký tự';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05),

              const Gap(16),

              // ── Password field ────────────────────────
              _FieldLabel(label: 'Mật khẩu'),
              const Gap(6),
              TextFormField(
                controller: _passwordCtrl,
                focusNode: _passwordFocus,
                enabled: !isLoading,
                obscureText: _obscurePass,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(ctx),
                decoration: InputDecoration(
                  hintText: 'Nhập mật khẩu',
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: _passwordFocus.hasFocus
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Vui lòng nhập mật khẩu';
                  }
                  if (v.length < 6) {
                    return 'Mật khẩu tối thiểu 6 ký tự';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.05),

              const Gap(12),

              // ── Remember me ───────────────────────────
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: isLoading
                          ? null
                          : (v) => setState(() => _rememberMe = v ?? false),
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: const BorderSide(
                        color: AppColors.border,
                        width: 1.5,
                      ),
                    ),
                  ),
                  const Gap(8),
                  GestureDetector(
                    onTap: isLoading
                        ? null
                        : () => setState(() => _rememberMe = !_rememberMe),
                    child: Text(
                      'Ghi nhớ đăng nhập',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms),

              const Gap(28),

              // ── Submit button ─────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _submit(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Đăng nhập',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

              const Gap(16),

              // ── Divider ───────────────────────────────
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'hoặc',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ).animate().fadeIn(delay: 600.ms),

              const Gap(16),

              // ── Register link ─────────────────────────
              OutlinedButton(
                onPressed: isLoading
                    ? null
                    : () {
                        // TODO: navigate to register
                      },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  foregroundColor: AppColors.textPrimary,
                ),
                child: Text(
                  'Tạo cửa hàng mới',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ).animate().fadeIn(delay: 650.ms),
            ],
          ),
        );
      },
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
