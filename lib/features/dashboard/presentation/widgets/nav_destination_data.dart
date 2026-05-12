// lib/features/dashboard/presentation/widgets/nav_destination_data.dart
import 'package:flutter/material.dart';

class NavDestinationData {
  const NavDestinationData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.color,
    required this.description,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color color;
  final String description;
}

const List<NavDestinationData> kNavDestinations = [
  NavDestinationData(
    label: 'Tổng quan',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
    color: Color(0xFF1A56DB),
    description: 'Thống kê & tổng quan cửa hàng',
  ),
  NavDestinationData(
    label: 'Bán hàng',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale_rounded,
    color: Color(0xFF10B981),
    description: 'Tạo đơn hàng & thanh toán',
  ),
  NavDestinationData(
    label: 'Sản phẩm',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    color: Color(0xFFF59E0B),
    description: 'Quản lý danh mục sản phẩm',
  ),
  NavDestinationData(
    label: 'Kho',
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse_rounded,
    color: Color(0xFF8B5CF6),
    description: 'Tồn kho & nhập xuất kho',
  ),
  NavDestinationData(
    label: 'Hóa đơn',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    color: Color(0xFF0EA5E9),
    description: 'Lịch sử hóa đơn & thanh toán',
  ),
  NavDestinationData(
    label: 'Báo cáo',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart_rounded,
    color: Color(0xFFEF4444),
    description: 'Doanh thu & phân tích',
  ),
  NavDestinationData(
    label: 'Nhân viên',
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
    color: Color(0xFFEC4899),
    description: 'Tài khoản & phân quyền',
  ),
];
