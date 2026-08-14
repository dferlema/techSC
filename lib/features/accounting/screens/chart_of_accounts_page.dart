import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tscomputer/features/accounting/models/chart_of_account_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';
import 'package:tscomputer/features/accounting/widgets/account_form_dialog.dart';
import 'package:tscomputer/core/services/role_service.dart';

class ChartOfAccountsPage extends ConsumerStatefulWidget {
  const ChartOfAccountsPage({super.key});

  @override
  ConsumerState<ChartOfAccountsPage> createState() => _ChartOfAccountsPageState();
}

enum _SearchMode { code, name, value }

class _ChartOfAccountsPageState extends ConsumerState<ChartOfAccountsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String? _typeFilter;
  _SearchMode _searchMode = _SearchMode.code;
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Plan de Cuentas'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.unfold_more),
            tooltip: 'Expandir todo',
            onPressed: () {
              setState(() {
                _expanded.clear();
                final all = accountsAsync.value ?? [];
                _expanded.addAll(all.where((a) => !a.isLeaf).map((a) => a.id));
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.unfold_less),
            tooltip: 'Contraer todo',
            onPressed: () => setState(() => _expanded.clear()),
          ),
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: 'Recalcular saldos',
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final role = await RoleService().getUserRole(user.uid);
              if (!context.mounted) return;
              if (role == RoleService.ADMIN || role == RoleService.ACCOUNTING) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Recalcular Saldos'),
                    content: const Text(
                      'Se recalcularán todos los saldos del plan de cuentas desde cero, corrigiendo la convención de signos. Esto puede tardar unos segundos. ¿Continuar?',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Recalcular'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🔄 Recalculando saldos...')),
                  );
                  final changes = await ref.read(chartOfAccountsServiceProvider).recalculateAllBalances();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Saldos recalculados: ${changes.length} cuentas procesadas')),
                  );
                }
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Solo administradores y contabilidad pueden recalcular saldos')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerar plan de cuentas',
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final role = await RoleService().getUserRole(user.uid);
              if (!context.mounted) return;
              if (role == RoleService.ADMIN || role == RoleService.ACCOUNTING) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Regenerar Plan de Cuentas'),
                    content: const Text(
                      'Se eliminarán todas las cuentas existentes y se volverán a generar con la nomenclatura legible (A-, P-, PAT-, I-, G-, C-). ¿Continuar?',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Regenerar'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(chartOfAccountsServiceProvider).regenerate();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Plan de cuentas regenerado con nomenclatura legible')),
                    );
                  }
                }
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Solo administradores y contabilidad pueden restaurar el plan de cuentas')),
                );
              }
            },
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No hay cuentas', style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('Agregue una cuenta o restaure los valores por defecto', style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(height: 24),
                  FilledButton.tonalIcon(
                    onPressed: () => _showAccountForm(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Cuenta'),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              // Búsqueda + filtro por tipo
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: switch (_searchMode) {
                            _SearchMode.code => 'Buscar por código...',
                            _SearchMode.name => 'Buscar por nombre...',
                            _SearchMode.value => 'Buscar por valor...',
                          },
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: _searchMode == _SearchMode.value
                            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
                            : TextInputType.text,
                        onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String?>(
                      value: _typeFilter,
                      hint: const Text('Tipo'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                        ...AccountType.values.map((t) => DropdownMenuItem<String?>(
                          value: t.name,
                          child: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                        )),
                      ],
                      onChanged: (v) => setState(() => _typeFilter = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<_SearchMode>(
                    segments: const [
                      ButtonSegment(value: _SearchMode.code, label: Text('Código'), icon: Icon(Icons.tag)),
                      ButtonSegment(value: _SearchMode.name, label: Text('Nombre'), icon: Icon(Icons.label_outline)),
                      ButtonSegment(value: _SearchMode.value, label: Text('Valor'), icon: Icon(Icons.attach_money)),
                    ],
                    selected: {_searchMode},
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
                    ),
                    onSelectionChanged: (s) => setState(() {
                      _searchMode = s.first;
                      _searchController.clear();
                      _search = '';
                    }),
                  ),
                ),
              ),
              Expanded(
                child: _buildTree(accounts),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountForm(context, ref),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Filtra por búsqueda y tipo, y renderiza como árbol jerárquico.
  Widget _buildTree(List<ChartOfAccountModel> accounts) {
    final hasQuery = _search.isNotEmpty || _typeFilter != null;
    List<ChartOfAccountModel> visible;
    if (hasQuery) {
      visible = accounts.where((a) {
        final matchSearch = _matchesSearch(a);
        final matchType = _typeFilter == null || a.type.name == _typeFilter;
        return matchSearch && matchType;
      }).toList();
      // Al filtrar, incluir ancestros para mostrar contexto
      visible = _withAncestors(accounts, visible);
    } else {
      visible = accounts;
    }

    final byParent = <String, List<ChartOfAccountModel>>{};
    final roots = <ChartOfAccountModel>[];
    for (final a in visible) {
      if (a.parentId == null || a.parentId!.isEmpty || !accounts.any((p) => p.code == a.parentId)) {
        roots.add(a);
      } else {
        byParent.putIfAbsent(a.parentId!, () => []).add(a);
      }
    }
    byParent.forEach((_, list) => list.sort((a, b) => a.code.compareTo(b.code)));
    roots.sort((a, b) => a.code.compareTo(b.code));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(accountsStreamProvider),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        itemCount: roots.length,
        itemBuilder: (context, index) =>
            _buildNode(context, roots[index], byParent, accounts),
      ),
    );
  }

  Widget _buildNode(
    BuildContext context,
    ChartOfAccountModel account,
    Map<String, List<ChartOfAccountModel>> byParent,
    List<ChartOfAccountModel> all,
  ) {
    final children = byParent[account.code];
    final hasChildren = children != null && children.isNotEmpty;
    final expanded = _expanded.contains(account.id);
    final indent = account.code.split('.').length - 1;

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: EdgeInsets.only(left: 12.0 + indent * 20, right: 4),
            leading: Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: _typeColor(account.type),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            title: Text(
              '${account.code}  ${account.name}',
              style: TextStyle(
                fontWeight: account.isLeaf ? FontWeight.w500 : FontWeight.bold,
                fontSize: 13,
              ),
            ),
            subtitle: account.description != null
                ? Text(account.description!, style: const TextStyle(fontSize: 11))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _typeBadge(account.type),
                const SizedBox(width: 4),
                Text(
                  '\$${account.balance.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (hasChildren)
                  IconButton(
                    iconSize: 20,
                    icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    tooltip: expanded ? 'Contraer' : 'Expandir',
                    onPressed: () => setState(() {
                      expanded ? _expanded.remove(account.id) : _expanded.add(account.id);
                    }),
                  ),
                PopupMenuButton(
                  iconSize: 20,
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                  onSelected: (val) async {
                    if (val == 'edit') {
                      await _showAccountForm(context, ref, account: account);
                    } else if (val == 'delete') {
                      await ref.read(chartOfAccountsServiceProvider).deleteAccount(account.id);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        if (hasChildren && expanded)
          ...children.map((c) => _buildNode(context, c, byParent, all)),
      ],
    );
  }

  /// Determina si la cuenta coincide con el término de búsqueda según el modo activo.
  bool _matchesSearch(ChartOfAccountModel a) {
    if (_search.isEmpty) return true;
    switch (_searchMode) {
      case _SearchMode.code:
        return a.code.toLowerCase().contains(_search);
      case _SearchMode.name:
        return a.name.toLowerCase().contains(_search) ||
            (a.description?.toLowerCase().contains(_search) ?? false);
      case _SearchMode.value:
        final value = double.tryParse(_search.replaceAll(',', '.').replaceAll('\$', '').trim());
        if (value == null) return false;
        return a.balance.abs() >= value;
    }
  }

  /// Incluye los ancestros de las cuentas filtradas para conservar la jerarquía.
  List<ChartOfAccountModel> _withAncestors(List<ChartOfAccountModel> all, List<ChartOfAccountModel> filtered) {
    final result = <ChartOfAccountModel>{...filtered};
    var changed = true;
    while (changed) {
      changed = false;
      for (final a in all) {
        if (result.contains(a)) continue;
        if (a.parentId != null && result.any((r) => r.parentId == a.code)) {
          result.add(a);
          changed = true;
        }
      }
    }
    return result.toList();
  }

  Color _typeColor(AccountType type) {
    return switch (type) {
      AccountType.activo => Colors.blue,
      AccountType.pasivo => Colors.orange,
      AccountType.patrimonio => Colors.green,
      AccountType.ingreso => Colors.teal,
      AccountType.gasto => Colors.red,
      AccountType.costo => Colors.purple,
    };
  }

  Widget _typeBadge(AccountType type) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(
        type.name[0].toUpperCase(),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _showAccountForm(BuildContext context, WidgetRef ref, {ChartOfAccountModel? account}) async {
    await showDialog(
      context: context,
      builder: (context) => AccountFormDialog(account: account),
    );
  }
}
