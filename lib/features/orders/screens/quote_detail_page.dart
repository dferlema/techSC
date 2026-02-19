import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:techsc/features/orders/models/quote_model.dart';
import 'package:techsc/features/orders/providers/quote_providers.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/core/utils/pdf_helper.dart';
import 'package:printing/printing.dart';

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

  @override
  void initState() {
    super.initState();
    _quote = widget.quote;
  }

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
          ),
        );
        Navigator.pop(context); // Go back or stay?
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cotización rechazada')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
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
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (role) {
        final isAdmin = role == RoleService.ADMIN;
        final isSeller = role == RoleService.SELLER;
        bool canApprove =
            (widget.isClientView || isAdmin || isSeller) &&
            _quote.status == 'sent';

        return Scaffold(
          appBar: AppBar(
            title: Text('Cotización #${_quote.id.substring(0, 8)}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _generatePdfAndShare,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(),
                const SizedBox(height: 16),
                _buildClientInfo(),
                const SizedBox(height: 16),
                _buildItemsList(),
                const SizedBox(height: 16),
                _buildTotals(),
                if (!widget.isClientView) ...[
                  const SizedBox(height: 16),
                  _buildHistory(),
                ],
              ],
            ),
          ),
          bottomNavigationBar: canApprove ? _buildActionButtons(role) : null,
        );
      },
    );
  }

  Widget _buildStatusCard() {
    Color color;
    IconData icon;
    String statusText;

    switch (_quote.status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        statusText = 'APROBADO';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        statusText = 'RECHAZADO';
        break;
      case 'sent':
        color = Colors.orange;
        icon = Icons.access_time;
        statusText = 'ENVIADO';
        break;
      case 'converted':
        color = Colors.blue;
        icon = Icons.inventory;
        statusText = 'CONVERTIDO';
        break;
      default:
        color = Colors.grey;
        icon = Icons.edit;
        statusText = 'BORRADOR';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado Actual',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy, HH:mm').format(_quote.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información del Cliente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Text('Nombre: ${_quote.clientName}'),
            Text('Cédula/RUC: ${_quote.clientId}'),
            Text('Email: ${_quote.clientEmail}'),
            Text('Teléfono: ${_quote.clientPhone}'),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalle de Items',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ..._quote.items.map(
              (item) => ListTile(
                dense: false,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    image: item.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(item.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: item.imageUrl == null
                      ? Icon(
                          item.type == 'product' ? Icons.computer : Icons.build,
                          color: Colors.grey,
                        )
                      : null,
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${item.quantity} x \$${item.price.toStringAsFixed(2)}',
                ),
                trailing: Text(
                  '\$${item.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotals() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:'),
                Text('\$${_quote.subtotal.toStringAsFixed(2)}'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('IVA (${(_quote.taxRate * 100).toInt()}%):'),
                Text('\$${_quote.taxAmount.toStringAsFixed(2)}'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  '\$${_quote.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return Card(
      child: ExpansionTile(
        title: const Text('Historial de Cambios'),
        children: _quote.history
            .map(
              (event) => ListTile(
                title: Text(event.description),
                subtitle: Text(
                  '${DateFormat('dd/MM HH:mm').format(event.date)} - ${event.userId}',
                ),
                leading: const Icon(Icons.history, size: 16),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildActionButtons(String role) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _rejectQuote(role),
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text(
                'RECHAZAR',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _approveQuote(role),
              icon: const Icon(Icons.check),
              label: const Text('APROBAR'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}
