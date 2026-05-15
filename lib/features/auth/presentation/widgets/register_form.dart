// lib/features/auth/presentation/widgets/register_form.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/register_bloc.dart';
import '../bloc/register_event.dart';
import '../bloc/register_state.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();

  final _storeNameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  final _storeNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _storeNameFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _storeNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    context.read<RegisterBloc>().add(
      RegisterSubmitted(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        storeName: _storeNameCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterBloc, RegisterState>(
      listener: (ctx, state) {
        if (state is RegisterError) {
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

        // RegisterSuccess được xử lý ở RegisterPage (navigate + SnackBar thành công)
      },
      builder: (ctx, state) {
        final isLoading = state is RegisterLoading;

        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Store name ────────────────────────────────
              _FieldLabel(label: 'Tên cửa hàng'),
              const Gap(6),
              TextFormField(
                controller: _storeNameCtrl,
                focusNode: _storeNameFocus,
                enabled: !isLoading,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_usernameFocus),
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Đặc Sản Quê Hương',
                  prefixIcon: Icon(
                    Icons.storefront_outlined,
                    color: _storeNameFocus.hasFocus
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Vui lòng nhập tên cửa hàng';
                  }
                  if (v.trim().length < 2) {
                    return 'Tên cửa hàng tối thiểu 2 ký tự';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),

              const Gap(16),

              // ── Username ──────────────────────────────────
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
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                    return 'Chỉ được dùng chữ, số và dấu gạch dưới';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05),

              const Gap(16),

              // ── Password ──────────────────────────────────
              _FieldLabel(label: 'Mật khẩu'),
              const Gap(6),
              TextFormField(
                controller: _passwordCtrl,
                focusNode: _passwordFocus,
                enabled: !isLoading,
                obscureText: _obscurePass,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_confirmPasswordFocus),
                decoration: InputDecoration(
                  hintText: 'Tối thiểu 6 ký tự',
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

              const Gap(16),

              // ── Confirm password ──────────────────────────
              _FieldLabel(label: 'Xác nhận mật khẩu'),
              const Gap(6),
              TextFormField(
                controller: _confirmPasswordCtrl,
                focusNode: _confirmPasswordFocus,
                enabled: !isLoading,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(ctx),
                decoration: InputDecoration(
                  hintText: 'Nhập lại mật khẩu',
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: _confirmPasswordFocus.hasFocus
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu';
                  }
                  if (v != _passwordCtrl.text) {
                    return 'Mật khẩu không khớp';
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.05),

              const Gap(28),

              // ── Submit ────────────────────────────────────
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
                            'Tạo cửa hàng',
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

              // ── Back to login ─────────────────────────────
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
              ).animate().fadeIn(delay: 550.ms),

              const Gap(16),

              OutlinedButton(
                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  foregroundColor: AppColors.textPrimary,
                ),
                child: Text(
                  'Quay lại đăng nhập',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms),
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
