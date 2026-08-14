import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tscomputer/core/platform/io_helper.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/accounting_entry_model.dart';
import 'package:tscomputer/features/accounting/models/chart_of_account_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';

class GeneralLedgerPage extends ConsumerStatefulWidget {
  const GeneralLedgerPage({super.key});

  @override
  ConsumerState<GeneralLedgerPage> createState() => _GeneralLedgerPageState();
}

class _GeneralLedgerPageState extends ConsumerState<GeneralLedgerPage> {
  ChartOfAccountModel? _selectedAccount;

  @override
  Widget build(BuildContext context) {
    if (_selectedAccount != null) {
      return _AccountMovementsView(
        account: _selectedAccount!,
        onBack: () => setState(() => _selectedAccount = null),
      );
    }
    return _AccountsListView(
      onAccountSelected: (account) => setState(() => _selectedAccount = account),
    );
  }
}

// ─────────────────────────────────────────────
// VISTA 1: Lista de cuentas con búsqueda
// ─────────────────────────────────────────────
class _AccountsListView extends ConsumerStatefulWidget {
  final ValueChanged<ChartOfAccountModel> onAccountSelected;
  const _AccountsListView({required this.onAccountSelected});

  @override
  ConsumerState<_AccountsListView> createState() => _AccountsListViewState();
}

class _AccountsListViewState extends ConsumerState<_AccountsListView> {
  final _searchController = TextEditingController();
  String _search = '';
  String? _typeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final accounts = accountsAsync.asData?.value ?? [];
    final filtered = accounts.where((a) {
      final q = _search.toLowerCase();
      final matchSearch = a.code.toLowerCase().contains(q) ||
          a.name.toLowerCase().contains(q) ||
          (a.description?.toLowerCase().contains(q) ?? false);
      final matchType = _typeFilter == null || a.type.name == _typeFilter;
      return matchSearch && matchType && a.isLeaf;
    }).toList();

    // Agrupar por tipo para mostrar secciones
    final grouped = <String, List<ChartOfAccountModel>>{};
    for (final a in filtered) {
      grouped.putIfAbsent(a.type.name, () => []).add(a);
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Libro Mayor'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por código o nombre...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
                const SizedBox(height: 8),
                // Filtros de tipo por chips
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip('Todas', null),
                      _filterChip('Activos', 'activo'),
                      _filterChip('Pasivos', 'pasivo'),
                      _filterChip('Patrimonio', 'patrimonio'),
                      _filterChip('Ingresos', 'ingreso'),
                      _filterChip('Gastos', 'gasto'),
                      _filterChip('Costos', 'costo'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Lista de cuentas
          Expanded(
            child: accountsAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : _buildGroupedList(grouped),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? type) {
    final isSelected = _typeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.grey[700])),
        selected: isSelected,
        selectedColor: AppColors.primaryBlue,
        backgroundColor: Colors.grey[100],
        checkmarkColor: Colors.white,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (_) => setState(() => _typeFilter = type),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No se encontraron cuentas',
              style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Intente con otros términos de búsqueda',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildGroupedList(Map<String, List<ChartOfAccountModel>> grouped) {
    final typeOrder = ['activo', 'pasivo', 'patrimonio', 'ingreso', 'gasto', 'costo'];
    final sections = typeOrder.where((t) => grouped.containsKey(t)).toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final typeName = sections[index];
        final accounts = grouped[typeName]!;
        final totalBalance = accounts.fold(0.0, (sum, a) => sum + a.balance);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado de sección
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _typeColor(AccountType.values.firstWhere((t) => t.name == typeName)).withAlpha(20),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _typeColor(AccountType.values.firstWhere((t) => t.name == typeName)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _typeName(typeName),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _typeColor(AccountType.values.firstWhere((t) => t.name == typeName)),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${accounts.length} cuenta(s)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '\$${totalBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _typeColor(AccountType.values.firstWhere((t) => t.name == typeName)),
                    ),
                  ),
                ],
              ),
            ),
            // Cuentas de esta sección
            ...accounts.map((acc) => _buildAccountTile(acc)),
          ],
        );
      },
    );
  }

  Widget _buildAccountTile(ChartOfAccountModel account) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onAccountSelected(account),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icono del tipo
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _typeColor(account.type).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _typeIcon(account.type),
                  color: _typeColor(account.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Info de la cuenta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.code,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (account.description != null && account.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        account.description!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Saldo
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${account.balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: account.balance >= 0 ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(AccountType type) {
    return switch (type) {
      AccountType.activo => const Color(0xFF1565C0),
      AccountType.pasivo => const Color(0xFFE65100),
      AccountType.patrimonio => const Color(0xFF2E7D32),
      AccountType.ingreso => const Color(0xFF00838F),
      AccountType.gasto => const Color(0xFFC62828),
      AccountType.costo => const Color(0xFF6A1B9A),
    };
  }

  IconData _typeIcon(AccountType type) {
    return switch (type) {
      AccountType.activo => Icons.account_balance,
      AccountType.pasivo => Icons.credit_card,
      AccountType.patrimonio => Icons.savings,
      AccountType.ingreso => Icons.trending_up,
      AccountType.gasto => Icons.trending_down,
      AccountType.costo => Icons.receipt,
    };
  }

  String _typeName(String name) {
    return switch (name) {
      'activo' => 'ACTIVOS',
      'pasivo' => 'PASIVOS',
      'patrimonio' => 'PATRIMONIO',
      'ingreso' => 'INGRESOS',
      'gasto' => 'GASTOS',
      'costo' => 'COSTOS',
      _ => name.toUpperCase(),
    };
  }
}

// ─────────────────────────────────────────────
// VISTA 2: Movimientos de una cuenta
// ─────────────────────────────────────────────
class _AccountMovementsView extends ConsumerStatefulWidget {
  final ChartOfAccountModel account;
  final VoidCallback onBack;

  const _AccountMovementsView({required this.account, required this.onBack});

  @override
  ConsumerState<_AccountMovementsView> createState() => _AccountMovementsViewState();
}

class _AccountMovementsViewState extends ConsumerState<_AccountMovementsView> {
  List<_MovementRow> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await ref.read(journalEntryServiceProvider).getEntriesByAccount(widget.account.id);
      // Construir filas con saldo acumulado
      // Ordenar de más antiguo a más reciente para calcular acumulado
      final sorted = List<AccountingEntryModel>.from(entries);
      sorted.sort((a, b) => a.date.compareTo(b.date));

      final rows = <_MovementRow>[];
      double runningBalance = 0;

      for (final entry in sorted) {
        final line = entry.lines.firstWhere(
          (l) => l.accountId == widget.account.id,
          orElse: () => AccountingEntryLine(accountId: '', accountCode: '', accountName: ''),
        );

        final isDeudora = _isDeudora(widget.account.nature);
        final change = isDeudora ? (line.debit - line.credit) : (line.credit - line.debit);
        runningBalance += change;

        rows.add(_MovementRow(
          entry: entry,
          debit: line.debit,
          credit: line.credit,
          balance: runningBalance,
        ));
      }

      // Invertir para mostrar más reciente primero
      rows.sort((a, b) => b.entry.date.compareTo(a.entry.date));

      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool _isDeudora(AccountNature? nature) {
    if (nature == null) return true;
    return nature == AccountNature.deudora;
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final df = DateFormat('dd MMM yyyy');

    // Calcular totales
    double totalDebit = 0, totalCredit = 0;
    for (final row in _rows) {
      totalDebit += row.debit;
      totalCredit += row.credit;
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
            Text(account.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Descargar PDF',
            onPressed: _exportToPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // Tarjeta de resumen
          _buildSummaryCard(account, totalDebit, totalCredit),
          const SizedBox(height: 4),
          // Contador de movimientos
          if (!_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    '${_rows.length} movimiento(s)',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    'Último: ${_rows.isNotEmpty ? df.format(_rows.first.entry.date) : "N/A"}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          // Lista de movimientos
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : _rows.isEmpty
                        ? _buildEmptyMovements()
                        : _buildMovementsList(df),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ChartOfAccountModel account, double totalDebit, double totalCredit) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.primaryBlue.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.primaryBlue.withAlpha(50), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      account.code,
                      style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Saldo actual
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SALDO',
                    style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${account.balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryItem('Débitos', totalDebit, Icons.arrow_upward),
              const SizedBox(width: 16),
              _summaryItem('Créditos', totalCredit, Icons.arrow_downward),
              const SizedBox(width: 16),
              _summaryItem('Saldo Final', account.balance, Icons.account_balance),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, double value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withAlpha(180), size: 16),
            const SizedBox(height: 4),
            Text(
              '\$${value.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text('Error al cargar movimientos', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _loadMovements,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMovements() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Sin movimientos', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Esta cuenta no tiene asientos contables registrados',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMovementsList(DateFormat df) {
    return RefreshIndicator(
      onRefresh: _loadMovements,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: _rows.length,
        itemBuilder: (context, index) {
          final row = _rows[index];
          final entry = row.entry;
          final showDateHeader = index == 0 ||
              _rows[index].entry.date.day != _rows[index - 1].entry.date.day ||
              _rows[index].entry.date.month != _rows[index - 1].entry.date.month;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Separador de fecha
              if (showDateHeader)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
                  child: Text(
                    df.format(entry.date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              // Tarjeta de movimiento
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      // Fila principal: descripción + montos
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Indicador débito/crédito
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: row.debit > 0
                                  ? Colors.blue.withAlpha(25)
                                  : Colors.orange.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              row.debit > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                              color: row.debit > 0 ? Colors.blue[600] : Colors.orange[600],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Descripción
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.description,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _statusBadge(entry.status),
                                    if (entry.number.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        entry.number,
                                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                      ),
                                    ],
                                    if (entry.referenceType != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '· ${entry.referenceType}',
                                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Montos
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (row.debit > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withAlpha(15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+\$${row.debit.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              if (row.credit > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withAlpha(15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '-\$${row.credit.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Fila inferior: saldo acumulado
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Saldo acumulado', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            Text(
                              '\$${row.balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: row.balance >= 0 ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusBadge(EntryStatus status) {
    final (color, label) = switch (status) {
      EntryStatus.contabilizado => (Colors.green, 'CONTABILIZADO'),
      EntryStatus.cancelado => (Colors.red, 'ANULADO'),
      EntryStatus.borrador => (Colors.orange, 'BORRADOR'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color[700]),
      ),
    );
  }

  Future<void> _exportToPdf() async {
    if (_rows.isEmpty) return;
    final account = widget.account;
    final df = DateFormat('dd/MM/yyyy');
    final dfFull = DateFormat('dd/MM/yyyy HH:mm');

    final pdf = pw.Document();

    double totalDebit = 0, totalCredit = 0;
    for (final row in _rows) {
      totalDebit += row.debit;
      totalCredit += row.credit;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('LIBRO MAYOR', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Fecha: ${dfFull.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('Cuenta: ${account.code} — ${account.name}', style: const pw.TextStyle(fontSize: 12)),
            if (account.description != null)
              pw.Text(account.description!, style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('TechServiceComputer — Sistema Contable', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfSummaryItem('Débitos', totalDebit),
                _pdfSummaryItem('Créditos', totalCredit),
                _pdfSummaryItem('Saldo', account.balance),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
            },
            headers: ['Fecha', 'Descripción', 'Débito', 'Crédito', 'Saldo'],
            data: _rows.map((row) {
              return [
                df.format(row.entry.date),
                row.entry.description,
                row.debit > 0 ? '\$${row.debit.toStringAsFixed(2)}' : '',
                row.credit > 0 ? '\$${row.credit.toStringAsFixed(2)}' : '',
                '\$${row.balance.toStringAsFixed(2)}',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('TOTAL: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('D: \$${totalDebit.toStringAsFixed(2)}  '),
                    pw.Text('C: \$${totalCredit.toStringAsFixed(2)}  '),
                    pw.Text('Saldo: \$${account.balance.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    if (mounted) {
      await shareBytes(bytes, 'libro_mayor_${account.code.replaceAll('.', '_')}.pdf');
    }
  }

  pw.Widget _pdfSummaryItem(String label, double value) {
    return pw.Column(
      children: [
        pw.Text(
          '\$${value.toStringAsFixed(2)}',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }
}

// Modelo auxiliar para filas de movimientos
class _MovementRow {
  final AccountingEntryModel entry;
  final double debit;
  final double credit;
  final double balance;

  _MovementRow({
    required this.entry,
    required this.debit,
    required this.credit,
    required this.balance,
  });
}
