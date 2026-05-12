// lib/features/dashboard/presentation/widgets/bottom_nav_shell.dart
import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
// import '../../../auth/presentation/bloc/auth_bloc.dart';
// import '../../../auth/presentation/bloc/auth_event.dart';
import 'dashboard_drawer.dart';
import 'nav_destination_data.dart';

/// Phone layout: AppBar + Drawer + BottomNavigationBar
class BottomNavShell extends StatelessWidget {
  const BottomNavShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  // Chỉ hiển thị 5 item đầu trên bottom nav (Nhân viên & Báo cáo vào drawer)
  static const int _kBottomNavCount = 5;

  @override
  Widget build(BuildContext context) {
    final dest = kNavDestinations[selectedIndex];
    final effectiveIndex = selectedIndex < _kBottomNavCount ? selectedIndex : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, dest),
      drawer: DashboardDrawer(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          Navigator.of(context).pop();
          onDestinationSelected(i);
        },
      ),
      body: body,
      bottomNavigationBar: _buildBottomNav(context, effectiveIndex),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    NavDestinationData dest,
  ) {
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.border,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          color: AppColors.textPrimary,
          tooltip: 'Menu',
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: dest.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(dest.selectedIcon, color: dest.color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            dest.label,
            style: GoogleFonts.dmSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          color: AppColors.textSecondary,
          onPressed: () {},
          tooltip: 'Thông báo',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context, int effectiveIndex) {
    return NavigationBar(
      selectedIndex: effectiveIndex,
      onDestinationSelected: (i) {
        // Nếu tap lại cùng index → không làm gì
        if (i != effectiveIndex) onDestinationSelected(i);
      },
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: AppColors.border,
      elevation: 8,
      height: 64,
      indicatorColor: kNavDestinations[effectiveIndex].color.withValues(
        alpha: 0.12,
      ),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      destinations: kNavDestinations
          .take(_kBottomNavCount)
          .toList()
          .asMap()
          .entries
          .map((entry) {
            final d = entry.value;
            final isSelected = entry.key == effectiveIndex;
            return NavigationDestination(
              icon: Icon(
                d.icon,
                color: isSelected ? d.color : AppColors.textSecondary,
              ),
              selectedIcon: Icon(d.selectedIcon, color: d.color),
              label: d.label,
              tooltip: d.description,
            );
          })
          .toList(),
    );
  }
}
