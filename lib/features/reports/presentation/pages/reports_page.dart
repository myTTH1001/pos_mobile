import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),

            const SizedBox(height: 24),

            Row(
              children: const [
                Expanded(
                  child: _StatCard(
                    title: 'Doanh thu hôm nay',
                    value: '₫12,450,000',
                    icon: Iconsax.money_recive,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Số đơn',
                    value: '128',
                    icon: Iconsax.receipt_2,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Khách hàng',
                    value: '82',
                    icon: Iconsax.people,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text(
                    'Biểu đồ doanh thu',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Iconsax.chart_2, size: 32),
        SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Báo cáo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 4),
            Text(
              'Tổng quan hoạt động kinh doanh',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),

          const SizedBox(height: 20),

          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
