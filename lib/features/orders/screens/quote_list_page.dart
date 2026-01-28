import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:techsc/features/orders/models/quote_model.dart';
import 'package:techsc/features/orders/services/quote_service.dart';
import 'package:techsc/features/auth/services/auth_service.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/features/orders/screens/create_quote_page.dart';
import 'package:techsc/features/orders/screens/quote_detail_page.dart';

class QuoteListPage extends StatefulWidget {
  const QuoteListPage({super.key});

  @override
  State<QuoteListPage> createState() => _QuoteListPageState();
}

class _QuoteListPageState extends State<QuoteListPage> {
  final QuoteService _quoteService = QuoteService();
  final AuthService _authService = AuthService();
  final RoleService _roleService = RoleService();

  String? _userRole;
  String? _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = _authService.currentUser;
    if (user != null) {
      final role = await _roleService.getUserRole(user.uid);
      if (mounted) {
        setState(() {
          _userId = user.uid;
          _userRole = role;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_userId == null) {
      return const Scaffold(body: Center(child: Text('Inicia sesión')));
    }

    final isClient = _userRole == RoleService.CLIENT;
    final isStaff = !isClient;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotizaciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.pushReplacementNamed(context, '/main');
            }
          },
        ),
        actions: [
          // Filter button could go here
        ],
      ),
      body: StreamBuilder<List<QuoteModel>>(
        stream: _quoteService.getQuotes(
          customerUid: isClient ? _userId : null,
          creatorId:
              null, // Staff sees all? Or restrict? Let's show all for now.
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final quotes = snapshot.data ?? [];

          if (quotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isClient
                        ? 'No tienes cotizaciones.'
                        : 'No hay cotizaciones registradas.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: quotes.length,
            itemBuilder: (context, index) {
              final quote = quotes[index];
              return _buildQuoteCard(quote, isClient);
            },
          );
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
  }

  Widget _buildQuoteCard(QuoteModel quote, bool isClient) {
    Color statusColor;
    String statusText;
    switch (quote.status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'APROBADO';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'RECHAZADO';
        break;
      case 'sent':
        statusColor = Colors.orange;
        statusText = 'ENVIADO';
        break;
      case 'converted':
        statusColor = Colors.blue;
        statusText = 'CONVERTIDO';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'BORRADOR';
    }

    final canEdit = !isClient && quote.status == 'draft';

    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  QuoteDetailPage(quote: quote, isClientView: isClient),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header: Client/ID + Date + Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isClient
                              ? 'Cotización #${quote.id.isNotEmpty ? quote.id.substring(0, 5).toUpperCase() : '---'}'
                              : (quote.clientName.isEmpty
                                    ? 'Cliente Desconocido'
                                    : quote.clientName),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'dd MMM yyyy, HH:mm',
                          ).format(quote.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canEdit)
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 20,
                        color: Colors.blue,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 24,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CreateQuotePage(existingQuote: quote),
                          ),
                        );
                      },
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              // Body: Thumbnails & Total
              Row(
                children: [
                  // Thumbnails using visual stacking
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: Stack(
                        children: [
                          if (quote.items.isEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Sin productos',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          for (
                            int i = 0;
                            i < quote.items.length && i < 4;
                            i++
                          ) ...[
                            Positioned(
                              left: i * 28.0,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  backgroundColor: Colors.grey[100],
                                  backgroundImage:
                                      quote.items[i].imageUrl != null
                                      ? NetworkImage(quote.items[i].imageUrl!)
                                      : null,
                                  child: quote.items[i].imageUrl == null
                                      ? Icon(
                                          quote.items[i].type == 'product'
                                              ? Icons.computer
                                              : Icons.build,
                                          size: 18,
                                          color: Colors.grey[400],
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                          if (quote.items.length > 4)
                            Positioned(
                              left: 4 * 28.0,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '+${quote.items.length - 4}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Total price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                      Text(
                        '\$${quote.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
