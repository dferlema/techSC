import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Providers de métricas rápidas
// ---------------------------------------------------------------------------

final _totalClientsProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'cliente')
      .snapshots()
      .map((s) => s.size);
});

final _totalProductsProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map((s) => s.size);
});

final _pendingOrdersProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'pendiente')
      .snapshots()
      .map((s) => s.size);
});

final _totalServicesProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('services')
      .snapshots()
      .map((s) => s.size);
});

// Provider para las últimas órdenes
final _recentOrdersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
});

// ---------------------------------------------------------------------------
// Dashboard principal
// ---------------------------------------------------------------------------

class AdminDashboardView extends ConsumerWidget {
  /// Callback para navegar a una sección específica desde el grid de acceso rápido.
  /// El índice corresponde al índice del [IndexedStack] en [AdminPanelPage]:
  ///   1=Clientes, 2=Productos, 3=Inventario, 4=Servicios, 5=Órdenes,
  ///   6=Proveedores, 7=Contabilidad
  final void Function(int index) onNavigateTo;

  const AdminDashboardView({super.key, required this.onNavigateTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(context),
          const SizedBox(height: 24),
          _buildSectionTitle(
            context,
            'Resumen Rápido',
            Icons.bar_chart_rounded,
          ),
          const SizedBox(height: 12),
          _buildMetricsRow(ref),
          const SizedBox(height: 28),
          _buildSectionTitle(context, 'Acceso Rápido', Icons.grid_view_rounded),
          const SizedBox(height: 12),
          _buildQuickAccessGrid(context),
          const SizedBox(height: 28),
          _buildSectionTitle(
            context,
            'Actividad Reciente',
            Icons.history_rounded,
          ),
          const SizedBox(height: 12),
          _buildRecentOrders(ref, context),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Banner de bienvenida
  // -------------------------------------------------------------------------
  Widget _buildWelcomeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.accentBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panel de Control',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gestiona tu negocio en un solo lugar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sección: título con ícono
  // -------------------------------------------------------------------------
  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Fila de métricas con StreamProviders
  // -------------------------------------------------------------------------
  Widget _buildMetricsRow(WidgetRef ref) {
    final clients = ref.watch(_totalClientsProvider);
    final products = ref.watch(_totalProductsProvider);
    final pending = ref.watch(_pendingOrdersProvider);
    final services = ref.watch(_totalServicesProvider);

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Clientes',
            value: clients,
            icon: Icons.people_rounded,
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: 'Productos',
            value: products,
            icon: Icons.inventory_2_rounded,
            color: const Color(0xFF6A1B9A),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: 'Pendientes',
            value: pending,
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFFE65100),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: 'Servicios',
            value: services,
            icon: Icons.build_rounded,
            color: const Color(0xFF00695C),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Grid de acceso rápido
  // -------------------------------------------------------------------------
  Widget _buildQuickAccessGrid(BuildContext context) {
    final sections = [
      _QuickSection(
        index: 1,
        label: 'Clientes',
        icon: Icons.people_rounded,
        color: const Color(0xFF1565C0),
      ),
      _QuickSection(
        index: 2,
        label: 'Productos',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF6A1B9A),
      ),
      _QuickSection(
        index: 3,
        label: 'Inventario',
        icon: Icons.warehouse_rounded,
        color: const Color(0xFF00695C),
      ),
      _QuickSection(
        index: 4,
        label: 'Servicios',
        icon: Icons.build_rounded,
        color: const Color(0xFF37474F),
      ),
      _QuickSection(
        index: 5,
        label: 'Órdenes',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFE65100),
      ),
      _QuickSection(
        index: 6,
        label: 'Proveedores',
        icon: Icons.business_rounded,
        color: const Color(0xFF880E4F),
      ),
      _QuickSection(
        index: 7,
        label: 'Contabilidad',
        icon: Icons.calculate_rounded,
        color: const Color(0xFF1B5E20),
      ),
      _QuickSection(
        index: 8,
        label: 'Categorías',
        icon: Icons.category_rounded,
        color: const Color(0xFFD84315),
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final s = sections[i];
        return _QuickAccessCard(
          section: s,
          onTap: () {
            if (s.index == 8) {
              Navigator.pushNamed(context, '/category-management');
            } else {
              onNavigateTo(s.index);
            }
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Lista de órdenes recientes
  // -------------------------------------------------------------------------
  Widget _buildRecentOrders(WidgetRef ref, BuildContext context) {
    final ordersAsync = ref.watch(_recentOrdersProvider);
    return ordersAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Text(
              'No hay órdenes recientes',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return Column(
          children: orders.map((o) => _RecentOrderTile(order: o)).toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------------------------

class _MetricCard extends StatelessWidget {
  final String label;
  final AsyncValue<int> value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          value.when(
            loading: () => SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
            error: (_, __) => Icon(Icons.error_outline, color: color, size: 18),
            data: (count) => Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.85),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickSection {
  final int index;
  final String label;
  final IconData icon;
  final Color color;

  const _QuickSection({
    required this.index,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _QuickAccessCard extends StatelessWidget {
  final _QuickSection section;
  final VoidCallback onTap;

  const _QuickAccessCard({required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [section.color, section.color.withOpacity(0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: section.color.withOpacity(0.30),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(section.icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(
                section.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final Map<String, dynamic> order;

  const _RecentOrderTile({required this.order});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completado':
      case 'entregado':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'procesando':
      case 'confirmado':
        return Colors.blue;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'pendiente';
    final clientName =
        order['clientName'] ?? order['customerName'] ?? 'Cliente';
    final total = order['total'];
    final color = _statusColor(status.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clientName.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  status.toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (total != null)
            Text(
              '\$${(total as num).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
