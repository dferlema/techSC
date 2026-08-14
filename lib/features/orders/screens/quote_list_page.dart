import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/orders/models/quote_model.dart';
import 'package:tscomputer/features/orders/providers/quote_providers.dart';
import 'package:tscomputer/features/orders/screens/create_quote_page.dart';
import 'package:tscomputer/features/orders/screens/quote_detail_page.dart';
import 'package:tscomputer/core/widgets/app_loading_indicator.dart';
import 'package:tscomputer/core/widgets/app_error_widget.dart';

/// Pantalla principal de cotizaciones.
///
/// Muestra la lista de cotizaciones con búsqueda por cliente/número y filtros
/// por estado. En pantallas anchas (>720dp) usa un grid de tarjetas; en móvil
/// una lista vertical. Los clientes solo ven sus propias cotizaciones
/// (filtro `customerUid`) y no pueden crear/editar; el personal (admin/vendedor)
/// ve todas y puede crear, editar y aprobar.
class QuoteListPage extends ConsumerStatefulWidget {
  const QuoteListPage({super.key});
  @override
  ConsumerState<QuoteListPage> createState() => _QuoteListPageState();
}

class _QuoteListPageState extends ConsumerState<QuoteListPage> {
  String _activeFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  static const Map<String, Color> _statusColors = {
    'draft': Colors.grey,
    'sent': Colors.orange,
    'approved': Colors.green,
    'rejected': Colors.red,
    'converted': Colors.blue,
  };

  static const Map<String, IconData> _statusIcons = {
    'draft': Icons.edit,
    'sent': Icons.access_time,
    'approved': Icons.check_circle,
    'rejected': Icons.cancel,
    'converted': Icons.inventory,
  };

  static const Map<String, String> _statusLabels = {
    'draft': 'Borrador',
    'sent': 'Enviado',
    'approved': 'Aprobado',
    'rejected': 'Rechazado',
    'converted': 'Convertido',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Inicia sesión')));
    }

    final roleAsync = ref.watch(userRoleProvider(user.uid));

    return roleAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('Error: $err'))),
      data: (role) {
        final isClient = role == RoleService.CLIENT;
        final isStaff = !isClient;
        final quotesFilters =
            QuotesFilters(customerUid: isClient ? user.uid : null);

        final quotesAsync = ref.watch(quotesProvider(quotesFilters));

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          appBar: _buildAppBar(context, role),
          body: quotesAsync.when(
            loading: () => const AppLoadingIndicator(),
            error: (err, _) => AppErrorWidget(
              error: err,
              onRetry: () => ref.invalidate(quotesProvider(quotesFilters)),
            ),
            data: (quotes) {
              final filtered = _applySearchAndFilter(quotes);
              return _buildBody(filtered, isStaff, isClient);
            },
          ),
          floatingActionButton: isStaff
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateQuotePage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva Cotización'),
                )
              : null,
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, String role) {
    final bool showFilters = role != RoleService.CLIENT;
    return AppBar(
      title: Row(
        children: [
          Icon(Icons.description_outlined,
              color: Theme.of(context).colorScheme.onPrimary),
          const SizedBox(width: 8),
          const Text('Cotizaciones'),
        ],
      ),
      bottom: showFilters
          ? PreferredSize(
              preferredSize: const Size.fromHeight(112),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar por cliente o número...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white
                              .withValues(alpha: kIsWeb ? 0.92 : 0.96),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  _buildFilterChips(),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      _FilterItem('all', 'Todas', AppColors.primaryBlue),
      _FilterItem('sent', 'Enviadas', Colors.orange),
      _FilterItem('approved', 'Aprobadas', Colors.green),
      _FilterItem('rejected', 'Rechazadas', Colors.red),
      _FilterItem('draft', 'Borradores', Colors.grey),
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) => _buildFilterChip(f)).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChip(_FilterItem f) {
    final bool selected = _activeFilter == f.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(f.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            )),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _activeFilter = f.value;
          });
        },
        selectedColor: f.color.withValues(alpha: 0.15),
        backgroundColor: Colors.white,
        side: BorderSide(
            color: selected
                ? f.color.withValues(alpha: 0.5)
                : Colors.grey.shade300,
            width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  List<QuoteModel> _applySearchAndFilter(List<QuoteModel> quotes) {
    final query = _searchController.text.toLowerCase();
    return quotes
        .where((q) => _activeFilter == 'all' || q.status == _activeFilter)
        .where((q) =>
            query.isEmpty ||
            q.clientName.toLowerCase().contains(query) ||
            q.id.toLowerCase().contains(query))
        .toList();
  }

  Widget _buildBody(List<QuoteModel> quotes, bool isStaff, bool isClient) {
    if (quotes.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        final filters = QuotesFilters(
            customerUid:
                isClient ? ref.read(authServiceProvider).currentUser?.uid : null);
        ref.invalidate(quotesProvider(filters));
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth > 720;
          if (isDesktop) {
            return _buildDesktopGrid(quotes, isClient, isStaff);
          }
          return _buildMobileList(quotes, isClient);
        },
      ),
    );
  }

  Widget _buildDesktopGrid(
      List<QuoteModel> quotes, bool isClient, bool isStaff) {
    final int crossAxisCount = MediaQuery.of(context).size.width > 1000 ? 3 : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      itemCount: quotes.length,
      itemBuilder: (context, index) {
        final quote = quotes[index];
        return _QuoteCard(
          quote: quote,
          isClient: isClient,
          statusColor: _statusColors[quote.status] ?? Colors.grey,
          statusIcon: _statusIcons[quote.status] ?? Icons.edit,
          statusText: _statusLabels[quote.status] ?? 'Borrador',
          onTap: () => _openDetail(context, quote, isClient),
          onEdit: isStaff
              ? () => _openEdit(context, quote)
              : null,
        );
      },
    );
  }

  Widget _buildMobileList(List<QuoteModel> quotes, bool isClient) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: quotes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final quote = quotes[index];
        return _QuoteCard(
          quote: quote,
          isClient: isClient,
          statusColor: _statusColors[quote.status] ?? Colors.grey,
          statusIcon: _statusIcons[quote.status] ?? Icons.edit,
          statusText: _statusLabels[quote.status] ?? 'Borrador',
          onTap: () => _openDetail(context, quote, isClient),
          onEdit: null,
        );
      },
    );
  }

  void _openDetail(BuildContext context, QuoteModel quote, bool isClient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuoteDetailPage(
          quote: quote,
          isClientView: isClient,
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, QuoteModel quote) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateQuotePage(existingQuote: quote),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.isNotEmpty;

    String message = 'No hay cotizaciones registradas.';
    IconData icon = Icons.description_outlined;

    if (hasSearch) {
      message = 'No se encontraron resultados.';
      icon = Icons.search_off;
    } else if (_activeFilter != 'all') {
      message = 'No hay cotizaciones en "$_activeFilter".';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
                color: Colors.grey[600], fontSize: 15, height: 1.4),
            textAlign: TextAlign.center,
          ),
          if (hasSearch) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              child: const Text('Limpiar búsqueda'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterItem {
  final String value;
  final String label;
  final Color color;
  const _FilterItem(this.value, this.label, this.color);
}

// ────────────────────────────────────────────
//  Quote Card (responsive: funciona en grid y en lista)
//
//  Tarjeta única que se adapta tanto al grid de escritorio como a la lista
//  móvil. Muestra cliente, fecha, estado, nº de items y total, además de un
//  botón compacto de edición (solo personal) cuando aplica.
// ────────────────────────────────────────────

class _QuoteCard extends StatelessWidget {
  final QuoteModel quote;
  final bool isClient;
  final Color statusColor;
  final IconData statusIcon;
  final String statusText;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _QuoteCard({
    required this.quote,
    required this.isClient,
    required this.statusColor,
    required this.statusIcon,
    required this.statusText,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_EC', symbol: '\$');
    final dateFmt = DateFormat('dd MMM yyyy');
    final daysLeft = quote.expirationDate?.difference(DateTime.now()).inDays;
    final bool isExpiring = daysLeft != null && daysLeft <= 3 && daysLeft >= 0;

    return Card(
      elevation: 0,
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quote.clientName.isEmpty
                          ? 'Cliente Desconocido'
                          : quote.clientName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isExpiring) ...[
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateFmt.format(quote.createdAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              const SizedBox(height: 10),
              if (quote.items.isNotEmpty)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${quote.items.length} '
                        '${quote.items.length == 1 ? 'item' : 'items'}',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (onEdit != null) _CompactEditButton(onEdit: onEdit!),
                  ],
                ),
              if (quote.items.isEmpty)
                Text('Sin items',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total:',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text(fmt.format(quote.total),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primaryBlue)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactEditButton extends StatelessWidget {
  final VoidCallback onEdit;
  const _CompactEditButton({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit,
                size: 13, color: AppColors.primaryBlue),
            const SizedBox(width: 3),
            Text('Editar',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}