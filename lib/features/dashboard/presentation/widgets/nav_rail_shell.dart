// lib/features/dashboard/presentation/widgets/nav_rail_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import 'nav_destination_data.dart';

/// Tablet/Desktop layout: NavigationRail (collapsed/extended) + body
class NavRailShell extends StatelessWidget {
  const NavRailShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.isExtended = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _SideRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            isExtended: isExtended,
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.border,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(selectedIndex: selectedIndex, isExtended: isExtended),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Side Navigation Rail ──────────────────────────────────────────────────────
class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.isExtended,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        extended: isExtended,
        minWidth: 72,
        minExtendedWidth: 220,
        backgroundColor: AppColors.surface,
        indicatorColor: Colors.transparent,
        useIndicator: false,
        leading: _RailLeading(isExtended: isExtended),
        trailing: _RailTrailing(isExtended: isExtended),
        labelType: isExtended
            ? NavigationRailLabelType.none
            : NavigationRailLabelType.selected,
        selectedLabelTextStyle: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        unselectedLabelTextStyle: GoogleFonts.dmSans(
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
        destinations: kNavDestinations.asMap().entries.map((entry) {
          final i = entry.key;
          final d = entry.value;
          final isSelected = i == selectedIndex;

          return NavigationRailDestination(
            padding: const EdgeInsets.symmetric(vertical: 4),
            icon: _RailItem(
              d: d,
              isSelected: isSelected,
              isExtended: isExtended,
            ),
            selectedIcon: _RailItem(
              d: d,
              isSelected: true,
              isExtended: isExtended,
            ),
            label:
                const SizedBox.shrink(), // label handled inside _RailItem when extended
          );
        }).toList(),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.d,
    required this.isSelected,
    required this.isExtended,
  });

  final NavDestinationData d;
  final bool isSelected;
  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? d.color : AppColors.textSecondary;

    if (isExtended) {
      return Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? d.color.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? d.color.withValues(alpha: 0.15)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected ? d.selectedIcon : d.icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                d.label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? d.color : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: d.color,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      );
    }

    // Collapsed: just icon with background
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isSelected
            ? d.color.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(isSelected ? d.selectedIcon : d.icon, color: color, size: 22),
    );
  }
}

// ── Leading: Logo / Store name ─────────────────────────────────────────────────
class _RailLeading extends StatelessWidget {
  const _RailLeading({required this.isExtended});
  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    if (isExtended) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
        child: Row(
          children: [
            _LogoIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ĐẶC SẢN',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'QUÊ HƯƠNG',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: _LogoIcon(),
    );
  }
}

class _LogoIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.storefront_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

// ── Trailing: Logout button ───────────────────────────────────────────────────
class _RailTrailing extends StatelessWidget {
  const _RailTrailing({required this.isExtended});
  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    if (isExtended) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: InkWell(
          onTap: () =>
              context.read<AuthBloc>().add(const AuthLogoutRequested()),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Đăng xuất',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: IconButton(
        icon: const Icon(
          Icons.logout_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
        tooltip: 'Đăng xuất',
        onPressed: () =>
            context.read<AuthBloc>().add(const AuthLogoutRequested()),
      ),
    );
  }
}

// ── Top bar (tablet/desktop) ──────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.selectedIndex, required this.isExtended});
  final int selectedIndex;
  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    final dest = kNavDestinations[selectedIndex];

    return Container(
      height: 60,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Page title + breadcrumb
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dest.label,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                dest.description,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Search
          _SearchBox(),
          const SizedBox(width: 12),
          // Notifications
          _IconChip(icon: Icons.notifications_none_rounded, badge: 3),
          const SizedBox(width: 8),
          // Avatar
          _UserAvatar(),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search_rounded, size: 16, color: AppColors.textHint),
          const SizedBox(width: 6),
          Text(
            'Tìm kiếm...',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, this.badge});
  final IconData icon;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 18, color: AppColors.textSecondary),
        ),
        if (badge != null && badge! > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$badge',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          'A',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
