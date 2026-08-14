import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/features/orders/models/quote_model.dart';
import 'package:tscomputer/features/orders/providers/quote_providers.dart';
import 'package:tscomputer/features/orders/screens/create_quote_page.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/core/utils/pdf_helper.dart';
import 'package:printing/printing.dart';

/// Detalle de una cotización.
///
/// Muestra estado, información del cliente, items, resumen financiero e
/// historial. El personal puede editar (excepto si ya se convirtió en orden)
/// y compartir el PDF; en estado 'sent' se habilitan los botones Aprobar/
/// Rechazar. En pantallas anchas usa dos columnas (detalle + resumen).
class QuoteDetailPage extends ConsumerStatefulWidget {
  final QuoteModel quote;
  final bool isClientView;

  const QuoteDetailPage({
    super.key,
    required this.quote,
    this.isClientView = false,
  });

  @override
  ConsumerState<QuoteDetailPage> createState() => _QuoteDetailPageState();
}

class _QuoteDetailPageState extends ConsumerState<QuoteDetailPage> {
  late QuoteModel _quote;
  bool _isLoading = false;

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
  void initState() {
    super.initState();
    _quote = widget.quote;
  }

  Color get _statusColor => _statusColors[_quote.status] ?? Colors.grey;
  IconData get _statusIcon => _statusIcons[_quote.status] ?? Icons.edit;
  String get _statusText => _statusLabels[_quote.status] ?? 'Borrador';

  String _getActionDescription(String action, String role) {
    String actor = 'cliente';
    if (role == RoleService.ADMIN) actor = 'administrador';
    if (role == RoleService.SELLER) actor = 'vendedor';
    return action == 'approved'
        ? 'Aprobado por $actor'
        : 'Rechazado por $actor';
  }

  Future<void> _approveQuote(String role) async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final historyDesc = _getActionDescription('approved', role);
      final quoteService = ref.read(quoteServiceProvider);
      final orderId = await quoteService.approveQuote(
        _quote.id,
        user.uid,
        historyDescription: historyDesc,
      );

      if (mounted) {
        setState(() {
          _quote = _quote.copyWith(
            status: 'approved',
            history: [
              ..._quote.history,
              QuoteHistoryEvent(
                date: DateTime.now(),
                userId: user.uid,
                action: 'approved',
                description: historyDesc,
              ),
            ],
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cotización aprobada. Orden creada: $orderId'),
            backgroundColor: Colors.green[700],
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectQuote(String role) async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final historyDesc = _getActionDescription('rejected', role);
      final quoteService = ref.read(quoteServiceProvider);
      await quoteService.rejectQuote(
        _quote.id,
        user.uid,
        historyDescription: historyDesc,
      );

      if (mounted) {
        setState(() {
          _quote = _quote.copyWith(
            status: 'rejected',
            history: [
              ..._quote.history,
              QuoteHistoryEvent(
                date: DateTime.now(),
                userId: user.uid,
                action: 'rejected',
                description: historyDesc,
              ),
            ],
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cotización rechazada'),
              backgroundColor: Colors.red[700]),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePdfAndShare() async {
    setState(() => _isLoading = true);
    try {
      final pdfBytes = await PdfHelper.generateQuotePdf(_quote);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Cotizacion_${_quote.id.substring(0, 8)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final roleAsync = user != null
        ? ref.watch(userRoleProvider(user.uid))
        : const AsyncValue.data(RoleService.CLIENT);

    return roleAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('Error: $err'))),
      data: (role) {
        final isAdmin = role == RoleService.ADMIN;
        final isSeller = role == RoleService.SELLER;
        bool canApprove =
            (widget.isClientView || isAdmin || isSeller) &&
            _quote.status == 'sent';
        bool canEdit =
            !widget.isClientView && _quote.status != 'converted';

        return Scaffold(
          backgroundColor: AppColors.backgroundGray,
          appBar: _buildAppBar(context, canEdit),
          body: _buildBody(context, role, canApprove),
          bottomNavigationBar: canApprove && !kIsWeb
              ? _buildActionButtons(role)
              : null,
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, bool canEdit) {
    return AppBar(
      title: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _statusColor.withValues(alpha: 0.12),
            child: Icon(_statusIcon, color: _statusColor, size: 16),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Cotización #${_quote.id.substring(0, 8)}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (canEdit)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Editar Cotización',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateQuotePage(existingQuote: _quote),
                    ),
                  );
                  final freshQuote = await ref
                      .read(quoteServiceProvider)
                      .getQuoteById(_quote.id);
                  if (freshQuote != null && mounted) {
                    setState(() => _quote = freshQuote);
                  }
                },
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.share, size: 20),
            onPressed: _generatePdfAndShare,
            tooltip: 'Compartir PDF',
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4),
        child: _isLoading
            ? const LinearProgressIndicator()
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBody(BuildContext context, String role, bool canApprove) {
    final isWide = MediaQuery.of(context).size.width > 720 || kIsWeb;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, canApprove ? 90 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatusCard(),
                          const SizedBox(height: 16),
                          _buildClientInfo(),
                          const SizedBox(height: 16),
                          _buildItemsCard(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTotalsCard(),
                          const SizedBox(height: 16),
                          if (!widget.isClientView) _buildHistorySection(),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildClientInfo(),
                    const SizedBox(height: 16),
                    _buildItemsCard(),
                    const SizedBox(height: 16),
                    _buildTotalsCard(),
                    if (!widget.isClientView) ...[
                      const SizedBox(height: 16),
                      _buildHistorySection(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  // ── Status Card ──

  Widget _buildStatusCard() {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    return Card(
      elevation: 0,
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(_statusIcon, color: _statusColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estado Actual',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(_statusText,
                      style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(dateFmt.format(_quote.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            if (_quote.status == 'sent' && !widget.isClientView)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                ),
                child: Text('Pendiente',
                    style: TextStyle(
                        color: _statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Client Info ──

  Widget _buildClientInfo() {
    return _card(
      header: _sectionHeader(Icons.person, AppColors.primaryBlue, 'Información General'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Nombre', _quote.clientName),
          _buildInfoRow('Cédula/RUC', _quote.clientId),
          _buildInfoRow('Email', _quote.clientEmail),
          _buildInfoRow('Teléfono', _quote.clientPhone),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                _quote.paymentMethod == 'tarjeta'
                    ? Icons.credit_card
                    : Icons.payments,
                size: 16,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Forma de Pago: ${_quote.paymentMethod == 'tarjeta' ? 'Tarjeta de Crédito' : 'Efectivo'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Items ──

  Widget _buildItemsCard() {
    final fmt = NumberFormat.currency(locale: 'es_EC', symbol: '\$');

    return _card(
      header: _sectionHeader(Icons.inventory_2, Colors.purple, 'Detalle de Items'),
      child: Column(
        children: [
          for (int i = 0; i < _quote.items.length; i++) ...[
            _buildItemRow(_quote.items[i], fmt),
            if (i < _quote.items.length - 1)
              const Divider(height: 1),
          ],
          if (_quote.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Sin items',
                  style: TextStyle(color: Colors.grey[400])),
            ),
        ],
      ),
    );
  }

  Widget _buildItemRow(QuoteItem item, NumberFormat fmt) {
    final bool isProduct = item.type == 'product';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _thumb(item, isProduct, 32),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} × ${fmt.format(item.price)} = ${fmt.format(item.total)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(
                width: 26,
                child: Text('${item.quantity}',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center),
              ),
              Expanded(
                child: Row(
                  children: [
                    _thumb(item, isProduct, 24),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(fmt.format(item.price),
                    style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              ),
              SizedBox(
                width: 70,
                child: Text(fmt.format(item.total),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.right),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _thumb(QuoteItem item, bool isProduct, double size) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey.shade100,
        image: hasImage
            ? DecorationImage(
                image: NetworkImage(item.imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: !hasImage
          ? Icon(isProduct ? Icons.computer : Icons.build,
              size: size * 0.6, color: Colors.grey[400])
          : null,
    );
  }

  // ── Totals ──

  Widget _buildTotalsCard() {
    final fmt = NumberFormat.currency(locale: 'es_EC', symbol: '\$');

    return _card(
      header: _sectionHeader(Icons.account_balance_wallet, Colors.blue, 'Resumen Financiero'),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', fmt.format(_quote.subtotal)),
          _buildTotalRow(
              'IVA (${(_quote.taxRate * 100).toInt()}%)',
              fmt.format(_quote.taxAmount)),
          if (_quote.discountPercentage > 0)
            _buildTotalRow(
                'Descuento (${_quote.discountPercentage.toInt()}%)',
                '-${fmt.format(_quote.discountAmount)}',
                color: Colors.green),
          const Divider(height: 24),
          _buildTotalRow('TOTAL', fmt.format(_quote.total), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value,
      {bool isTotal = false, Color? color}) {
    final colorVal = color ??
        (isTotal ? AppColors.primaryBlue : Colors.grey[700]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: isTotal ? 15 : 13,
                    fontWeight:
                        isTotal ? FontWeight.bold : FontWeight.w500,
                    color:
                        isTotal ? AppColors.primaryBlue : Colors.grey[600]),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  fontSize: isTotal ? 18 : 14,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                  color: colorVal)),
        ],
      ),
    );
  }

  // ── History ──

  Widget _buildHistorySection() {
    final history = _quote.history;

    return _card(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(Icons.history, color: Colors.grey[600], size: 18),
            const SizedBox(width: 8),
            const Text('Historial de Cambios'),
          ],
        ),
        children: history.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay historial disponible',
                      style: TextStyle(color: Colors.grey)),
                )
              ]
            : history.reversed
                .map((event) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history, size: 16),
                      title: Text(event.description,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${DateFormat('dd/MM HH:mm').format(event.date)} • ${event.userId}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500]),
                      ),
                    ))
                .toList(),
      ),
    );
  }

  // ── Helpers ──

  Widget _card({Widget? header, required Widget child}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header,
            if (header != null) const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, Color color, String title) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.10),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ── Action Buttons ──

  Widget _buildActionButtons(String role) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: 16, vertical: kIsWeb ? 24 : 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _rejectQuote(role),
              icon: const Icon(Icons.close, color: Colors.red, size: 18),
              label: const Text('RECHAZAR',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _approveQuote(role),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('APROBAR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}