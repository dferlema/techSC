import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/core/theme/app_colors.dart';

final _totalClientsProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'cliente')
      .snapshots()
      .map((s) => s.docs.length);
});

final _totalProductsProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map((s) => s.docs.length);
});

final _totalServicesProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('services')
      .snapshots()
      .map((s) => s.docs.length);
});

final _pendingOrdersCountProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'pendiente')
      .snapshots()
      .map((s) => s.docs.length);
});

final _pendingReservationsProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('reservations')
      .where('status', whereIn: ['pendiente', 'confirmado', 'en_proceso', 'aprobado'])
      .snapshots()
      .map((s) => s.docs.length);
});

final _recentOrdersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
});

final _monthlyTransactionsProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);
  return FirebaseFirestore.instance
      .collection('accounting_transactions')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('date', isLessThan: Timestamp.fromDate(end))
      .snapshots()
      .map((s) => s.docs);
});

final _monthlyIncomeProvider = Provider<double>((ref) {
  final snap = ref.watch(_monthlyTransactionsProvider);
  return snap.whenOrNull(
        data: (docs) => docs.fold<double>(0.0, (acc, d) {
          final data = d.data();
          if (data['type'] != 'ingreso') return acc;
          return acc + ((data['total'] as num?)?.toDouble() ?? 0.0);
        }),
      ) ??
      0.0;
});

final _monthlyExpenseProvider = Provider<double>((ref) {
  final snap = ref.watch(_monthlyTransactionsProvider);
  return snap.whenOrNull(
        data: (docs) => docs.fold<double>(0.0, (acc, d) {
          final data = d.data();
          if (data['type'] != 'egreso') return acc;
          return acc + ((data['total'] as num?)?.toDouble() ?? 0.0);
        }),
      ) ??
      0.0;
});

final _pendingRevenueProvider = StreamProvider<double>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('paymentStatus', whereIn: ['unpaid', 'partial'])
      .snapshots()
      .map((s) => s.docs.fold<double>(0.0, (acc, d) {
        final data = d.data();
        final t = (data['total'] as num?)?.toDouble() ?? 0.0;
        final ps = (data['paymentStatus'] ?? '').toString();
        if (ps == 'unpaid') return acc + t;
        final paid = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
        return acc + (t - paid);
      }));
});

final _recentTransactionsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('accounting_transactions')
      .orderBy('date', descending: true)
      .limit(5)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
});

class AdminDashboardView extends ConsumerWidget {
  final void Function(int index) onNavigateTo;

  const AdminDashboardView({super.key, required this.onNavigateTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    final roleAsync = ref.watch(userRoleProvider(user.uid));
    final role = roleAsync.value ?? RoleService.CLIENT;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_totalClientsProvider);
        ref.invalidate(_totalProductsProvider);
        ref.invalidate(_totalServicesProvider);
        ref.invalidate(_pendingOrdersCountProvider);
        ref.invalidate(_pendingReservationsProvider);
        ref.invalidate(_monthlyTransactionsProvider);
        ref.invalidate(_pendingRevenueProvider);
        ref.invalidate(_recentOrdersProvider);
        ref.invalidate(_recentTransactionsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(kIsWeb ? 24 : 16, 24, kIsWeb ? 24 : 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeBanner(context),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Resumen Financiero del Mes', Icons.account_balance_wallet_rounded),
            const SizedBox(height: 12),
            _buildFinancialMetrics(ref),
            const SizedBox(height: 28),
            _buildSectionTitle(context, 'Métricas Rápidas', Icons.bar_chart_rounded),
            const SizedBox(height: 12),
            _buildQuickMetrics(ref),
            const SizedBox(height: 28),
            _buildSectionTitle(context, 'Acceso Rápido', Icons.grid_view_rounded),
            const SizedBox(height: 12),
            _buildQuickAccessGrid(context, role),
            const SizedBox(height: 28),
            _buildSectionTitle(context, 'Actividad Reciente', Icons.history_rounded),
            const SizedBox(height: 12),
            _buildRecentActivity(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context) {
    final today = DateFormat("EEEE, d 'de' MMMM", 'es').format(DateTime.now());
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
            color: AppColors.primaryBlue.withValues(alpha: 0.35),
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
                  today[0].toUpperCase() + today.substring(1),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

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

  Widget _buildFinancialMetrics(WidgetRef ref) {
    final income = ref.watch(_monthlyIncomeProvider);
    final expense = ref.watch(_monthlyExpenseProvider);
    final pending = ref.watch(_pendingRevenueProvider);

    return Row(
      children: [
        Expanded(
          child: _FinancialCard(
            label: 'Ingresos',
            value: income,
            icon: Icons.trending_up_rounded,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FinancialCard(
            label: 'Gastos',
            value: expense,
            icon: Icons.trending_down_rounded,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FinancialCard(
            label: 'Por Cobrar',
            value: pending.value ?? 0.0,
            icon: Icons.receipt_long_rounded,
            color: Colors.orange,
            isLoading: pending.isLoading,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMetrics(WidgetRef ref) {
    final clients = ref.watch(_totalClientsProvider);
    final products = ref.watch(_totalProductsProvider);
    final services = ref.watch(_totalServicesProvider);
    final pendingOrders = ref.watch(_pendingOrdersCountProvider);
    final pendingReservations = ref.watch(_pendingReservationsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = constraints.maxWidth > 900
            ? 5
            : constraints.maxWidth > 600
                ? 3
                : 2;
        final double spacing = constraints.maxWidth > 900 ? 12 : 8;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1.4,
          ),
          itemCount: 5,
          itemBuilder: (context, i) {
            switch (i) {
              case 0:
                return _MetricCard(label: 'Clientes', value: clients, icon: Icons.people_rounded, color: const Color(0xFF1565C0));
              case 1:
                return _MetricCard(label: 'Productos', value: products, icon: Icons.inventory_2_rounded, color: const Color(0xFF6A1B9A));
              case 2:
                return _MetricCard(label: 'Servicios', value: services, icon: Icons.build_rounded, color: const Color(0xFF00695C));
              case 3:
                return _MetricCard(label: 'Órdenes Pend.', value: pendingOrders, icon: Icons.pending_actions_rounded, color: const Color(0xFFE65100));
              case 4:
                return _MetricCard(label: 'Serv. Pend.', value: pendingReservations, icon: Icons.schedule_rounded, color: const Color(0xFFD84315));
              default:
                return const SizedBox.shrink();
            }
          },
        );
      },
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context, String role) {
    final sections = [
      if (role == RoleService.ADMIN || role == RoleService.SELLER || role == RoleService.TECHNICIAN || role == RoleService.ACCOUNTING)
        _QuickSection(index: 1, label: 'Clientes', icon: Icons.people_rounded, color: const Color(0xFF1565C0)),
      _QuickSection(index: 2, label: 'Productos', icon: Icons.inventory_2_rounded, color: const Color(0xFF6A1B9A)),
      _QuickSection(index: 3, label: 'Inventario', icon: Icons.warehouse_rounded, color: const Color(0xFF00695C)),
      _QuickSection(index: 4, label: 'Servicios', icon: Icons.build_rounded, color: const Color(0xFF37474F)),
      _QuickSection(index: 5, label: 'Órdenes', icon: Icons.receipt_long_rounded, color: const Color(0xFFE65100)),
      if (role == RoleService.ADMIN || role == RoleService.SELLER || role == RoleService.ACCOUNTING)
        _QuickSection(index: 6, label: 'Proveedores', icon: Icons.business_rounded, color: const Color(0xFF880E4F)),
      if (role == RoleService.ADMIN)
        _QuickSection(index: 8, label: 'Categorías', icon: Icons.category_rounded, color: const Color(0xFFD84315)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount =
            constraints.maxWidth > 1200 ? 6 :
            constraints.maxWidth > 900 ? 5 :
            constraints.maxWidth > 600 ? 4 :
            constraints.maxWidth > 400 ? 3 : 2;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
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
      },
    );
  }

  Widget _buildRecentActivity(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ref.watch(_recentTransactionsProvider).when(
          loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const SizedBox.shrink(),
          data: (txns) {
            if (txns.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Últimos movimientos contables', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const SizedBox(height: 8),
                ...txns.take(3).map((t) => _TransactionTile(transaction: t)),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
        ref.watch(_recentOrdersProvider).when(
          loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const SizedBox.shrink(),
          data: (orders) {
            if (orders.isEmpty) {
              return Center(child: Text('No hay órdenes recientes', style: TextStyle(color: AppColors.textSecondary)));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Últimas órdenes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const SizedBox(height: 8),
                ...orders.map((o) => _RecentOrderTile(order: o)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool isLoading;

  const _FinancialCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(
                  '\$${value.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final AsyncValue<int> value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          value.when(
            loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, _) => Icon(Icons.error_outline, color: color, size: 16),
            data: (v) => Text(
              '$v',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
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

  const _QuickSection({required this.index, required this.label, required this.icon, required this.color});
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
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [section.color, section.color.withValues(alpha: 0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: section.color.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(section.icon, color: Colors.white, size: 26),
              const SizedBox(height: 6),
              Text(
                section.label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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
      case 'completado': case 'entregado': return Colors.green;
      case 'pendiente': return Colors.orange;
      case 'procesando': case 'confirmado': return Colors.blue;
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'pendiente';
    final clientName = order['clientName'] ?? order['customerName'] ?? 'Cliente';
    final total = order['total'];
    final ps = (order['paymentStatus'] ?? '').toString();
    final color = _statusColor(status.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(width: 5, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clientName.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(status.toString().toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                    if (ps == 'partial')
                      Text(' · ABONO', style: TextStyle(fontSize: 10, color: Colors.blue[700], fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          if (total != null)
            Text('\$${(total as num).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final type = (transaction['type'] ?? '').toString();
    final total = (transaction['total'] as num?)?.toDouble() ?? 0.0;
    final category = transaction['category'] ?? '';
    final description = transaction['description'] ?? '';
    final date = transaction['date'] is Timestamp ? (transaction['date'] as Timestamp).toDate() : DateTime.now();
    final isIncome = type == 'ingreso';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: isIncome ? Colors.green : Colors.red),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(description.toString(), style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isIncome ? Colors.green : Colors.red),
              ),
              Text(DateFormat('dd/MM').format(date), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }
}
