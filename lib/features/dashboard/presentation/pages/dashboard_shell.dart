import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _mobileBreakpoint = 600;
  static const _tabletBreakpoint = 1024;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= _tabletBreakpoint) {
      return _DesktopLayout(navigationShell: navigationShell);
    }

    if (width >= _mobileBreakpoint) {
      return _TabletLayout(navigationShell: navigationShell);
    }

    return _MobileLayout(navigationShell: navigationShell);
  }
}

// ─────────────────────────────────────────────────────────────
// MOBILE
// ─────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: const _AppTitle(),
        actions: const [
          _NotificationButton(),
          SizedBox(width: 8),
          _ProfileAvatar(),
          SizedBox(width: 16),
        ],
      ),

      body: navigationShell,

      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: dashboardDestinations
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
                      const _ProfileAvatar(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Thu ngân',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Đang hoạt động',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Iconsax.logout),
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
// SHARED
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary,
      child: Text(
        'T',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
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

const dashboardDestinations = [
  DashboardDestination(label: 'POS', icon: Iconsax.shop, route: AppRoutes.pos),
  DashboardDestination(
    label: 'Sản phẩm',
    icon: Iconsax.box,
    route: AppRoutes.products,
  ),
  DashboardDestination(
    label: 'Kho',
    icon: Iconsax.archive,
    route: AppRoutes.stock,
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
