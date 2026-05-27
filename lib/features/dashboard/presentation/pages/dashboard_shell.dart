// lib/features/dashboard/presentation/pages/dashboard_shell.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const int _mobileBreakpoint = 600;
  static const int _tabletBreakpoint = 1024;

  // FIX Bug #1: Tách riêng bottom nav (5 tab) vs full nav (7 tab).
  // Bottom nav chỉ hiển thị 5 tab đầu để tránh overflow trên mobile.
  static const int _bottomNavCount = 5;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= _tabletBreakpoint) {
      return _DesktopLayout(navigationShell: navigationShell);
    }
    if (width >= _mobileBreakpoint) {
      return _TabletLayout(navigationShell: navigationShell);
    }
    return _MobileLayout(
      navigationShell: navigationShell,
      bottomNavCount: _bottomNavCount,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MOBILE
// ─────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.navigationShell,
    required this.bottomNavCount,
  });

  final StatefulNavigationShell navigationShell;
  final int bottomNavCount;

  @override
  Widget build(BuildContext context) {
    // FIX Bug #1: clamp currentIndex vào phạm vi bottom nav
    final effectiveIndex = navigationShell.currentIndex < bottomNavCount
        ? navigationShell.currentIndex
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: const _AppTitle(),
        // FIX Bug #5: Thêm logout vào mobile AppBar qua PopupMenu
        actions: [
          const _NotificationButton(),
          const SizedBox(width: 4),
          _ProfilePopupMenu(),
          const SizedBox(width: 8),
        ],
      ),
      body: navigationShell,
      // FIX Bug #1: Chỉ lấy bottomNavCount destinations, dùng effectiveIndex
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: effectiveIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: dashboardDestinations
            .take(bottomNavCount)
            .map(
              (e) => NavigationDestination(icon: Icon(e.icon), label: e.label),
            )
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TABLET
// ─────────────────────────────────────────────────────────────

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            labelType: NavigationRailLabelType.all,
            minWidth: 88,
            leading: const Padding(
              padding: EdgeInsets.only(top: 20),
              child: _SidebarLogo(),
            ),
            // Tablet rail hiển thị tất cả 7 destinations
            destinations: dashboardDestinations
                .map(
                  (e) => NavigationRailDestination(
                    icon: Icon(e.icon),
                    label: Text(e.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                const _TopBar(),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DESKTOP
// ─────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Row(
        children: [
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFEAECEF))),
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const _SidebarLogo(),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView.builder(
                    itemCount: dashboardDestinations.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, index) {
                      final item = dashboardDestinations[index];
                      final selected = navigationShell.currentIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _SidebarItem(
                          destination: item,
                          selected: selected,
                          onTap: () {
                            navigationShell.goBranch(
                              index,
                              initialLocation:
                                  index == navigationShell.currentIndex,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // FIX Bug #13: Avatar dùng username thực từ token
                      const _ProfileAvatar(),
                      const SizedBox(width: 12),
                      const Expanded(child: _UsernameDisplay()),
                      IconButton(
                        onPressed: () => context.read<AuthBloc>().add(
                          const AuthLogoutRequested(),
                        ),
                        icon: const Icon(Iconsax.logout),
                        tooltip: 'Đăng xuất',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const _TopBar(),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEAECEF))),
      ),
      child: Row(
        children: [
          const _AppTitle(),
          const Spacer(),
          Container(
            width: 280,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm...',
                prefixIcon: Icon(Iconsax.search_normal),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const _NotificationButton(),
          const SizedBox(width: 12),
          const _ProfileAvatar(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.storefront_rounded, color: Colors.white),
        ),
        const SizedBox(height: 12),
        const Text(
          'ĐẶC SẢN\nQUÊ HƯƠNG',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final DashboardDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                destination.icon,
                color: selected ? AppColors.primary : Colors.grey.shade700,
              ),
              const SizedBox(width: 14),
              Text(
                destination.label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.primary : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {},
      icon: const Badge(child: Icon(Iconsax.notification)),
    );
  }
}

// FIX Bug #13: Đọc username từ JWT token thay vì hardcode "T"
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  Future<String> _getInitial() async {
    try {
      final token = await SecureStorage.instance.getAccessToken();
      if (token == null) return '?';
      final parts = token.split('.');
      if (parts.length != 3) return '?';
      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final sub = json['sub'] as String? ?? '';
      return sub.isNotEmpty ? sub[0].toUpperCase() : '?';
    } catch (_) {
      return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getInitial(),
      initialData: '?',
      builder: (_, snap) => CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primary,
        child: Text(
          snap.data ?? '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// FIX Bug #13: Hiển thị username thực ở desktop sidebar
class _UsernameDisplay extends StatelessWidget {
  const _UsernameDisplay();

  Future<String> _getUsername() async {
    try {
      final token = await SecureStorage.instance.getAccessToken();
      if (token == null) return 'Người dùng';
      final parts = token.split('.');
      if (parts.length != 3) return 'Người dùng';
      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return json['sub'] as String? ?? 'Người dùng';
    } catch (_) {
      return 'Người dùng';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getUsername(),
      initialData: '...',
      builder: (_, snap) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snap.data ?? '...',
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          const Text(
            'Đang hoạt động',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// FIX Bug #5: PopupMenu cho mobile — cung cấp logout khi không có sidebar
class _ProfilePopupMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Tài khoản',
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: const _ProfileAvatar(),
      onSelected: (value) {
        if (value == 'logout') {
          context.read<AuthBloc>().add(const AuthLogoutRequested());
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: FutureBuilder<String>(
            future: (() async {
              try {
                final token = await SecureStorage.instance.getAccessToken();
                if (token == null) return 'Người dùng';
                final parts = token.split('.');
                if (parts.length != 3) return 'Người dùng';
                String payload = parts[1];
                while (payload.length % 4 != 0) {
                  payload += '=';
                }
                final decoded = utf8.decode(base64Url.decode(payload));
                final json = jsonDecode(decoded) as Map<String, dynamic>;
                return json['sub'] as String? ?? 'Người dùng';
              } catch (_) {
                return 'Người dùng';
              }
            })(),
            initialData: '...',
            builder: (_, snap) => Text(
              snap.data ?? '...',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text('Đăng xuất', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppTitle extends StatelessWidget {
  const _AppTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Đặc Sản Quê Hương',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 2),
        Text(
          'POS Management',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DESTINATIONS
// ─────────────────────────────────────────────────────────────

class DashboardDestination {
  final String label;
  final IconData icon;
  final String route;

  const DashboardDestination({
    required this.label,
    required this.icon,
    required this.route,
  });
}

// 7 destinations — khớp với 7 StatefulShellBranch trong router.
// Mobile bottom nav chỉ lấy 5 đầu (_bottomNavCount).
// Tablet/Desktop rail & sidebar hiển thị tất cả 7.
const dashboardDestinations = [
  DashboardDestination(label: 'POS', icon: Iconsax.shop, route: AppRoutes.pos),
  DashboardDestination(
    label: 'Sản phẩm',
    icon: Iconsax.box,
    route: AppRoutes.products,
  ),
  DashboardDestination(
    label: 'Đơn hàng',
    icon: Iconsax.receipt_text,
    route: AppRoutes.orders,
  ),
  DashboardDestination(
    label: 'Kho',
    icon: Iconsax.archive,
    route: AppRoutes.stock,
  ),
  DashboardDestination(
    label: 'Hóa đơn',
    icon: Iconsax.receipt,
    route: AppRoutes.invoices,
  ),
  DashboardDestination(
    label: 'Báo cáo',
    icon: Iconsax.chart_2,
    route: AppRoutes.reports,
  ),
  DashboardDestination(
    label: 'Nhân viên',
    icon: Iconsax.profile_2user,
    route: AppRoutes.users,
  ),
];
