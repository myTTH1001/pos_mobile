// lib/features/users/presentation/pages/users_page.dart
//
// Phân quyền đầy đủ:
//   • Danh sách user kèm role hiện tại
//   • Tap vào user → bottom sheet chi tiết: xem role, gán thêm role, xóa role
//   • Tạo user mới với role
//   • Bật/tắt tài khoản, xóa user
//   • Owner không thể bị sửa bởi manager

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/user_model.dart';
import '../bloc/users_bloc.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY
// ─────────────────────────────────────────────────────────────────────────────

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UsersBloc()..add(const UsersLoadRequested()),
      child: const _UsersView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _UsersView extends StatelessWidget {
  const _UsersView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<UsersBloc, UsersState>(
      listenWhen: (p, c) => p.actionStatus != c.actionStatus,
      listener: (ctx, state) {
        if (state.actionStatus == UsersActionStatus.success) {
          _showSnack(ctx, 'Thành công!', AppColors.success);
        } else if (state.actionStatus == UsersActionStatus.failure) {
          _showSnack(
            ctx,
            state.actionError ?? 'Có lỗi xảy ra',
            AppColors.error,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: BlocBuilder<UsersBloc, UsersState>(
                buildWhen: (p, c) => p.status != c.status || p.users != c.users,
                builder: (ctx, state) {
                  if (state.status == UsersStatus.initial ||
                      state.status == UsersStatus.loading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    );
                  }
                  if (state.status == UsersStatus.failure) {
                    return _ErrorBody(
                      message: state.errorMessage,
                      onRetry: () =>
                          ctx.read<UsersBloc>().add(const UsersLoadRequested()),
                    );
                  }
                  if (state.users.isEmpty) return const _EmptyBody();
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async =>
                        ctx.read<UsersBloc>().add(const UsersLoadRequested()),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.users.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _UserCard(user: state.users[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: const _AddFab(),
      ),
    );
  }

  void _showSnack(BuildContext ctx, String msg, Color color) {
    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people_rounded,
              color: Color(0xFFEC4899),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhân viên',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                BlocBuilder<UsersBloc, UsersState>(
                  buildWhen: (p, c) => p.users.length != c.users.length,
                  builder: (_, state) => Text(
                    '${state.users.length} tài khoản',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          BlocBuilder<UsersBloc, UsersState>(
            buildWhen: (p, c) => p.status != c.status,
            builder: (ctx, state) => IconButton(
              onPressed: state.status == UsersStatus.loading
                  ? null
                  : () => ctx.read<UsersBloc>().add(const UsersLoadRequested()),
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Tải lại',
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final cfg = _roleConfig(user.primaryRole);
    final isOwner = user.roles.contains('owner');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showUserDetail(context, user),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: cfg.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    user.username[0].toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cfg.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.username,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (!user.isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Đã khóa',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Role badges
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: user.roles.map((role) {
                        final rc = _roleConfig(role);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: rc.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rc.label,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: rc.color,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Chevron / shield for owner
              if (isOwner)
                const Icon(
                  Icons.shield_rounded,
                  size: 20,
                  color: Color(0xFF1A56DB),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textHint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER DETAIL BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

void _showUserDetail(BuildContext context, UserModel user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<UsersBloc>(),
      child: _UserDetailSheet(user: user),
    ),
  );
}

class _UserDetailSheet extends StatelessWidget {
  const _UserDetailSheet({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final isOwner = user.roles.contains('owner');
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _roleConfig(
                    user.primaryRole,
                  ).color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    user.username[0].toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _roleConfig(user.primaryRole).color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: GoogleFonts.dmSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: user.isActive
                                ? AppColors.success
                                : AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          user.isActive ? 'Đang hoạt động' : 'Đã bị khóa',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: user.isActive
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),

          // ── Phân quyền ─────────────────────────────────────────
          Text(
            'Phân quyền',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Current roles
          BlocBuilder<UsersBloc, UsersState>(
            buildWhen: (p, c) => p.users != c.users,
            builder: (ctx, state) {
              // Lấy user mới nhất từ state (có thể đã cập nhật)
              final currentUser = state.users.firstWhere(
                (u) => u.id == user.id,
                orElse: () => user,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role hiện tại
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentUser.roles.map((role) {
                      final rc = _roleConfig(role);
                      final canRemove =
                          !isOwner &&
                          role != 'owner' &&
                          currentUser.roles.length > 1;
                      return _RoleBadge(
                        role: role,
                        config: rc,
                        canRemove: canRemove,
                        onRemove: canRemove
                            ? () => _confirmRemoveRole(
                                context,
                                currentUser,
                                role,
                                state.roles,
                              )
                            : null,
                      );
                    }).toList(),
                  ),

                  // Gán thêm role (chỉ hiện nếu không phải owner và còn role chưa gán)
                  if (!isOwner) ...[
                    const SizedBox(height: 12),
                    _AssignRoleSection(
                      user: currentUser,
                      allRoles: state.roles,
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),

          // ── Hành động tài khoản ────────────────────────────────
          if (!isOwner) ...[
            Text(
              'Tài khoản',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            BlocBuilder<UsersBloc, UsersState>(
              buildWhen: (p, c) =>
                  p.users != c.users || p.actionStatus != c.actionStatus,
              builder: (ctx, state) {
                final currentUser = state.users.firstWhere(
                  (u) => u.id == user.id,
                  orElse: () => user,
                );
                final isLoading =
                    state.actionStatus == UsersActionStatus.loading;
                return Row(
                  children: [
                    // Toggle active
                    Expanded(
                      child: _ActionButton(
                        icon: currentUser.isActive
                            ? Icons.lock_outline_rounded
                            : Icons.lock_open_rounded,
                        label: currentUser.isActive
                            ? 'Khóa tài khoản'
                            : 'Mở khóa',
                        color: currentUser.isActive
                            ? AppColors.warning
                            : AppColors.success,
                        loading: isLoading,
                        onTap: () => _confirmToggle(context, currentUser),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Delete
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.delete_outline_rounded,
                        label: 'Xóa tài khoản',
                        color: AppColors.error,
                        loading: isLoading,
                        onTap: () {
                          Navigator.pop(context);
                          _confirmDelete(context, currentUser);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tài khoản chủ cửa hàng — không thể chỉnh sửa',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Role Badge (có nút xóa) ───────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.role,
    required this.config,
    required this.canRemove,
    this.onRemove,
  });
  final String role;
  final _RoleConfig config;
  final bool canRemove;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 10,
        top: 6,
        bottom: 6,
        right: canRemove ? 4 : 10,
      ),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.color),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: config.color,
            ),
          ),
          if (canRemove) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, size: 12, color: config.color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Assign Role Section ───────────────────────────────────────────────────────

class _AssignRoleSection extends StatelessWidget {
  const _AssignRoleSection({required this.user, required this.allRoles});
  final UserModel user;
  final List<RoleModel> allRoles;

  @override
  Widget build(BuildContext context) {
    // Roles chưa được gán cho user (loại trừ 'owner')
    final assignable = allRoles
        .where((r) => r.name != 'owner' && !user.roles.contains(r.name))
        .toList();

    if (assignable.isEmpty) {
      return Text(
        'Đã gán tất cả các quyền có thể',
        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textHint),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gán thêm quyền:',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: assignable.map((role) {
            final rc = _roleConfig(role.name);
            return GestureDetector(
              onTap: () => _assignRole(context, user, role),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: rc.color),
                    const SizedBox(width: 4),
                    Text(
                      rc.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

void _assignRole(BuildContext context, UserModel user, RoleModel role) {
  context.read<UsersBloc>().add(
    UserAssignRoleRequested(userId: user.id, roleId: role.id),
  );
}

void _confirmRemoveRole(
  BuildContext context,
  UserModel user,
  String roleName,
  List<RoleModel> allRoles,
) {
  final roleModel = allRoles.firstWhere(
    (r) => r.name == roleName,
    orElse: () => RoleModel(id: 0, name: roleName, permissions: []),
  );
  if (roleModel.id == 0) return;
  final rc = _roleConfig(roleName);

  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<UsersBloc>(),
      child: _ConfirmDialog(
        icon: Icons.remove_circle_outline_rounded,
        iconColor: AppColors.error,
        title: 'Xóa quyền ${rc.label}?',
        message: 'Bỏ quyền "${rc.label}" khỏi tài khoản "${user.username}".',
        confirmLabel: 'Xóa quyền',
        confirmColor: AppColors.error,
        onConfirm: (ctx) {
          ctx.read<UsersBloc>().add(
            UserRemoveRoleRequested(userId: user.id, roleId: roleModel.id),
          );
          Navigator.pop(ctx);
        },
      ),
    ),
  );
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB — Thêm nhân viên
// ─────────────────────────────────────────────────────────────────────────────

class _AddFab extends StatelessWidget {
  const _AddFab();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showCreateSheet(context),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.person_add_rounded),
      label: Text(
        'Thêm nhân viên',
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
      ),
      elevation: 2,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE USER SHEET
// ─────────────────────────────────────────────────────────────────────────────

void _showCreateSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: context.read<UsersBloc>(),
      child: const _CreateUserSheet(),
    ),
  );
}

const _assignableRoles = ['manager', 'staff', 'cashier'];

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet();

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _selectedRole = 'cashier';
  bool _obscurePass = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext ctx) {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ctx.read<UsersBloc>().add(
      UserCreateRequested(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        roleName: _selectedRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return BlocListener<UsersBloc, UsersState>(
      listenWhen: (p, c) => p.actionStatus != c.actionStatus,
      listener: (ctx, state) {
        if (state.actionStatus == UsersActionStatus.success) Navigator.pop(ctx);
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, viewInsets.bottom + 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Thêm nhân viên',
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _SheetLabel('Tên đăng nhập'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _usernameCtrl,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Tối thiểu 3 ký tự, không dấu',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Vui lòng nhập tên đăng nhập';
                  if (v.trim().length < 3) return 'Tối thiểu 3 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              _SheetLabel('Mật khẩu'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePass,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Tối thiểu 6 ký tự',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                  if (v.length < 6) return 'Tối thiểu 6 ký tự';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              _SheetLabel('Vai trò mặc định'),
              const SizedBox(height: 8),
              Row(
                children: _assignableRoles.map((role) {
                  final cfg = _roleConfig(role);
                  final selected = _selectedRole == role;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRole = role),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? cfg.color.withValues(alpha: 0.1)
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? cfg.color : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                cfg.icon,
                                size: 20,
                                color: selected
                                    ? cfg.color
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cfg.label,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: selected
                                      ? cfg.color
                                      : AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              BlocBuilder<UsersBloc, UsersState>(
                buildWhen: (p, c) => p.actionStatus != c.actionStatus,
                builder: (ctx, state) => SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: state.actionStatus == UsersActionStatus.loading
                        ? null
                        : () => _submit(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: state.actionStatus == UsersActionStatus.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Tạo tài khoản',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM DIALOGS
// ─────────────────────────────────────────────────────────────────────────────

void _confirmToggle(BuildContext context, UserModel user) {
  final action = user.isActive ? 'khóa' : 'mở khóa';
  final color = user.isActive ? AppColors.warning : AppColors.success;
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<UsersBloc>(),
      child: _ConfirmDialog(
        icon: user.isActive
            ? Icons.lock_outline_rounded
            : Icons.lock_open_rounded,
        iconColor: color,
        title: '${action[0].toUpperCase()}${action.substring(1)} tài khoản?',
        message: 'Bạn sắp $action tài khoản "${user.username}".',
        confirmLabel: action[0].toUpperCase() + action.substring(1),
        confirmColor: color,
        onConfirm: (ctx) {
          ctx.read<UsersBloc>().add(
            UserToggleStatusRequested(
              userId: user.id,
              isActive: !user.isActive,
            ),
          );
          Navigator.pop(ctx);
        },
      ),
    ),
  );
}

void _confirmDelete(BuildContext context, UserModel user) {
  showDialog(
    context: context,
    builder: (_) => BlocProvider.value(
      value: context.read<UsersBloc>(),
      child: _ConfirmDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: AppColors.error,
        title: 'Xóa tài khoản?',
        message:
            'Bạn sắp xóa tài khoản "${user.username}". Hành động này không thể hoàn tác.',
        confirmLabel: 'Xóa',
        confirmColor: AppColors.error,
        onConfirm: (ctx) {
          ctx.read<UsersBloc>().add(UserDeleteRequested(user.id));
          Navigator.pop(ctx);
        },
      ),
    ),
  );
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final void Function(BuildContext) onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Text(
                        'Hủy',
                        style: GoogleFonts.dmSans(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onConfirm(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY / ERROR BODIES
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_outline_rounded,
            size: 56,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có nhân viên nào',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showCreateSheet(context),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Thêm nhân viên đầu tiên'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              message ?? 'Không thể tải danh sách nhân viên',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.label);
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

class _RoleConfig {
  const _RoleConfig({
    required this.label,
    required this.color,
    required this.icon,
  });
  final String label;
  final Color color;
  final IconData icon;
}

_RoleConfig _roleConfig(String role) => switch (role) {
  'owner' => const _RoleConfig(
    label: 'Chủ cửa hàng',
    color: Color(0xFF1A56DB),
    icon: Icons.storefront_rounded,
  ),
  'manager' => const _RoleConfig(
    label: 'Quản lý',
    color: Color(0xFF8B5CF6),
    icon: Icons.manage_accounts_rounded,
  ),
  'staff' => const _RoleConfig(
    label: 'Nhân viên',
    color: Color(0xFF0EA5E9),
    icon: Icons.person_rounded,
  ),
  'cashier' => const _RoleConfig(
    label: 'Thu ngân',
    color: Color(0xFF10B981),
    icon: Icons.point_of_sale_rounded,
  ),
  _ => const _RoleConfig(
    label: 'Khác',
    color: AppColors.textSecondary,
    icon: Icons.person_outline_rounded,
  ),
};
