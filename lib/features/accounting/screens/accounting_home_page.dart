import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/screens/chart_of_accounts_page.dart';
import 'package:tscomputer/features/accounting/screens/journal_entries_page.dart';
import 'package:tscomputer/features/accounting/screens/receivables_page.dart';
import 'package:tscomputer/features/accounting/screens/payables_page.dart';
import 'package:tscomputer/features/accounting/screens/bank_reconciliation_page.dart';
import 'package:tscomputer/features/accounting/screens/financial_reports_page.dart';
import 'package:tscomputer/features/accounting/screens/transactions_page.dart';
import 'package:tscomputer/features/accounting/screens/iva_report_page.dart';
import 'package:tscomputer/features/accounting/screens/profitability_page.dart';
import 'package:tscomputer/features/accounting/screens/budget_page.dart';
import 'package:tscomputer/features/accounting/screens/payroll_page.dart';
import 'package:tscomputer/features/accounting/screens/purchase_invoices_page.dart';
import 'package:tscomputer/features/accounting/screens/investments_page.dart';
import 'package:tscomputer/features/accounting/screens/credits_page.dart';
import 'package:tscomputer/features/accounting/screens/depreciation_page.dart';
import 'package:tscomputer/features/accounting/screens/service_profitability_page.dart';
import 'package:tscomputer/features/accounting/screens/general_ledger_page.dart';
import 'package:tscomputer/features/accounting/screens/setup_wizard_page.dart';
import 'package:tscomputer/features/accounting/services/business_config_service.dart';
import 'package:tscomputer/features/accounting/services/receivable_service.dart';
import 'package:tscomputer/features/accounting/services/payable_service.dart';
import 'package:tscomputer/features/accounting/widgets/transfer_form_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tscomputer/core/services/role_service.dart';

class AccountingHomePage extends ConsumerStatefulWidget {
  const AccountingHomePage({super.key});

  @override
  ConsumerState<AccountingHomePage> createState() => _AccountingHomePageState();
}

class _AccountingHomePageState extends ConsumerState<AccountingHomePage> {
  double _cxcpending = 0, _cxppending = 0;
  bool _loadingCash = true;

  @override
  void initState() {
    super.initState();
    _seedIfPermitted();
    _loadCashFlow();
    _checkInitialSetup();
  }

  /// BLOQUE 10: si la configuración inicial no existe, muestra el wizard.
  Future<void> _checkInitialSetup() async {
    try {
      final configured = await BusinessConfigService().isConfigured();
      if (!configured && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SetupWizardPage()),
        );
        _loadCashFlow();
      }
    } catch (_) {
      // Sin conexión u otro error: no bloquear el módulo.
    }
  }

  Future<void> _seedIfPermitted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final role = await RoleService().getUserRole(user.uid);
    if (role == RoleService.ADMIN || role == RoleService.ACCOUNTING) {
      ref.read(chartOfAccountsServiceProvider).seedDefaults();
    }
  }

  Future<void> _loadCashFlow() async {
    try {
      final receivableSvc = ReceivableService();
      final payableSvc = PayableService();

      final user = FirebaseAuth.instance.currentUser;
      int totalNotifs = 0;
      if (user != null) {
        final role = await RoleService().getUserRole(user.uid);
        if (role == RoleService.ADMIN || role == RoleService.ACCOUNTING) {
          final overdueCxc = await receivableSvc.markOverdue();
          final overdueCxp = await payableSvc.markOverdue();
          totalNotifs = overdueCxc + overdueCxp;
        }
      }

      final cxcp = await receivableSvc.getTotalPending();
      final cxpp = await payableSvc.getTotalPending();
      if (mounted) setState(() { _cxcpending = cxcp; _cxppending = cxpp; _loadingCash = false; });

      if (totalNotifs > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ $totalNotifs cuenta(s) marcada(s) como vencida(s)'),
            backgroundColor: Colors.orange[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCash = false);
    }
  }

  static const List<_AccountingModule> _modules = [
    _AccountingModule('Movimientos', Icons.account_balance, Color(0xFF1565C0), 'Registro de ingresos y egresos'),
    _AccountingModule('Facturas de Compra', Icons.receipt, Color(0xFF283593), 'Compras y gastos con factura'),
    _AccountingModule('Plan de Cuentas', Icons.book, Color(0xFF6A1B9A), 'Catálogo contable'),
    _AccountingModule('Libro Mayor', Icons.menu_book, Color(0xFF00695C), 'Movimientos por cuenta'),
    _AccountingModule('Asientos Contables', Icons.receipt_long, Color(0xFFE65100), 'Asientos de diario'),
    _AccountingModule('Cuentas por Cobrar', Icons.handshake, Color(0xFF00695C), 'Créditos a clientes'),
    _AccountingModule('Cuentas por Pagar', Icons.payment, Color(0xFF880E4F), 'Deudas con proveedores'),
    _AccountingModule('Nómina', Icons.payments, Color(0xFF283593), 'Roles de pago e IESS'),
    _AccountingModule('Conciliación Bancaria', Icons.compare_arrows, Color(0xFF37474F), 'Conciliación de cuentas'),
    _AccountingModule('Reportes de IVA', Icons.receipt, Color(0xFFF57C00), 'IVA compras y ventas'),
    _AccountingModule('Rentabilidad', Icons.trending_up, Color(0xFF2E7D32), 'Margen por producto'),
    _AccountingModule('Servicios', Icons.build, Color(0xFF00838F), 'Rentabilidad por servicio'),
    _AccountingModule('Presupuestos', Icons.account_balance_wallet, Color(0xFF4A148C), 'Presupuesto vs real'),
    _AccountingModule('Reportes Financieros', Icons.assessment, Color(0xFF1B5E20), 'Estados financieros y reportes'),
    _AccountingModule('Inversiones', Icons.trending_up, Color(0xFF2E7D32), 'Aportes de socios e inversiones'),
    _AccountingModule('Créditos', Icons.account_balance_wallet, Color(0xFFE65100), 'Préstamos bancarios y créditos'),
    _AccountingModule('Transferencias', Icons.swap_horiz, Color(0xFF37474F), 'Transferencias entre cuentas'),
    _AccountingModule('Depreciación', Icons.inventory_2, Color(0xFF6A1B9A), 'Activos fijos y depreciación'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Contabilidad'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _loadingCash = true);
          await _loadCashFlow();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSectionTitle('Módulos Contables'),
              const SizedBox(height: 12),
              _buildModulesGrid(),
              const SizedBox(height: 24),
              _buildSectionTitle('Acciones Rápidas'),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModulesGrid() {
    final rows = <Widget>[];
    for (int i = 0; i < _modules.length; i += 2) {
      final row = Row(
        children: [
          Expanded(child: _buildModuleCard(_modules[i])),
          if (i + 1 < _modules.length) ...[
            const SizedBox(width: 12),
            Expanded(child: _buildModuleCard(_modules[i + 1])),
          ] else
            const Expanded(child: SizedBox.shrink()),
        ],
      );
      rows.add(row);
      if (i + 2 < _modules.length) {
        rows.add(const SizedBox(height: 12));
      }
    }
    return Column(children: rows);
  }

  Widget _buildHeader() {
    final flujo = _cxcpending - _cxppending;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.accentBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance, color: Colors.white, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Módulo de Contabilidad',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestión financiera completa para tu negocio',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_loadingCash) ...[
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _cashFlowChip('CxC pendiente', '\$${_cxcpending.toStringAsFixed(0)}', Colors.orange),
                const SizedBox(width: 8),
                _cashFlowChip('CxP pendiente', '\$${_cxppending.toStringAsFixed(0)}', Colors.redAccent),
                const SizedBox(width: 8),
                _cashFlowChip('Flujo neto', '\$${flujo.toStringAsFixed(0)}', flujo >= 0 ? Colors.greenAccent : Colors.redAccent),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cashFlowChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildModuleCard(_AccountingModule module) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToModule(module),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: module.color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(module.icon, color: module.color, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                module.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                module.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToModule(_AccountingModule module) {
    final route = module.title;
    Widget page;
    switch (route) {
      case 'Movimientos':
        page = const TransactionsPage();
        break;
      case 'Facturas de Compra':
        page = const PurchaseInvoicesPage();
        break;
      case 'Plan de Cuentas':
        page = const ChartOfAccountsPage();
        break;
      case 'Libro Mayor':
        page = const GeneralLedgerPage();
        break;
      case 'Asientos Contables':
        page = const JournalEntriesPage();
        break;
      case 'Cuentas por Cobrar':
        page = const ReceivablesPage();
        break;
      case 'Cuentas por Pagar':
        page = const PayablesPage();
        break;
      case 'Nómina':
        page = const PayrollPage();
        break;
      case 'Conciliación Bancaria':
        page = const BankReconciliationPage();
        break;
      case 'Reportes de IVA':
        page = const IvaReportPage();
        break;
      case 'Rentabilidad':
        page = const ProfitabilityPage();
        break;
      case 'Servicios':
        page = const ServiceProfitabilityPage();
        break;
      case 'Presupuestos':
        page = const BudgetPage();
        break;
      case 'Reportes Financieros':
        page = const FinancialReportsPage();
        break;
      case 'Inversiones':
        page = const InvestmentsPage();
        break;
      case 'Créditos':
        page = const CreditsPage();
        break;
      case 'Transferencias':
        showDialog(context: context, builder: (_) => const TransferFormDialog());
        return;
      case 'Depreciación':
        page = const DepreciationPage();
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Sincronizar Ventas',
                Icons.sync,
                AppColors.primaryBlue,
                () async {
                  final count = await ref.read(accountingServiceProvider).syncPastSalesToAccounting();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(count > 0 ? '$count movimiento(s) sincronizado(s)' : 'Todos al día'),
                        backgroundColor: count > 0 ? AppColors.success : Colors.grey,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Categorías',
                Icons.category,
                Colors.orange,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChartOfAccountsPage())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Configuración Inicial',
                Icons.settings,
                Colors.indigo,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupWizardPage())),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountingModule {
  final String title;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _AccountingModule(this.title, this.icon, this.color, this.subtitle);
}
