import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/dashboard_provider.dart';
import 'billing_screen.dart';
import 'products_screen.dart';
import 'customers_screen.dart';
import 'bill_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<DashboardProvider>().fetchStats());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MAHASHAKTI CHANACHUR'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DashboardProvider>().fetchStats(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildStatsGrid(context, isDesktop),
                const SizedBox(height: 32),
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildActionsGrid(context, isDesktop),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, bool isDesktop) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final stats = provider.stats;
        return GridView.count(
          crossAxisCount: isDesktop ? 4 : 2,
          crossAxisSpacing: isDesktop ? 16 : 0,
          mainAxisSpacing: isDesktop ? 16 : 0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _StatCard(
              title: 'Products',
              count: stats['products'] ?? 0,
              icon: Icons.inventory_2,
              color: Colors.blue,
            ),
            _StatCard(
              title: 'Customers',
              count: stats['customers'] ?? 0,
              icon: Icons.people,
              color: Colors.orange,
            ),
            _StatCard(
              title: 'Bills Issued',
              count: stats['bills'] ?? 0,
              icon: Icons.receipt_long,
              color: Colors.green,
            ),
            _StatCard(
              title: 'Low Stock',
              count: stats['lowStock'] ?? 0,
              icon: Icons.warning,
              color: Colors.red,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionsGrid(BuildContext context, bool isDesktop) {
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        _ActionCard(
          title: 'New Bill',
          icon: Icons.add_shopping_cart,
          color: Colors.red,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BillingScreen()),
          ),
        ),
        _ActionCard(
          title: 'Products',
          icon: Icons.inventory,
          color: Colors.blueAccent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductsScreen()),
          ),
        ),
        _ActionCard(
          title: 'Customers',
          icon: Icons.people_alt,
          color: Colors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomersScreen()),
          ),
        ),
        _ActionCard(
          title: 'History',
          icon: Icons.history,
          color: Colors.purple,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BillHistoryScreen()),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const Spacer(),
              Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
