import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tscomputer/features/reservations/models/reservation_model.dart';
import 'package:tscomputer/features/auth/services/auth_service.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:tscomputer/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/features/accounting/services/reservation_accounting_service.dart';
import 'package:tscomputer/features/receipt/screens/receipt_preview_page.dart';
import 'package:tscomputer/features/receipt/models/receipt_config_model.dart';

class ReservationDetailPage extends ConsumerStatefulWidget {
  final ReservationModel reservation;

  const ReservationDetailPage({super.key, required this.reservation});

  @override
  ConsumerState<ReservationDetailPage> createState() =>
      _ReservationDetailPageState();
}

class _ReservationDetailPageState extends ConsumerState<ReservationDetailPage> {
  late TextEditingController _commentsController;
  late TextEditingController _solutionController;
  late String _currentStatus;
  String _userRole = RoleService.CLIENT;
  bool _isLoading = false;

  // Payment Logic
  late TextEditingController _institutionController;
  late TextEditingController _voucherController;
  bool _isPaid = false;
  String _paymentMethod = 'efectivo'; // efectivo, transferencia, tarjeta

  // Spare Parts Logic
  final List<Map<String, dynamic>> _selectedParts = [];
  double _partsTotal = 0.0;

  // Labor Services Logic
  final List<Map<String, dynamic>> _selectedServices = [];
  double _servicesTotal = 0.0;

  bool _applyVAT = false;

  // Check if reservation is completed (read-only mode)
  bool get isCompleted => _currentStatus == 'completado';

  // Locked when paid OR completed (no editing allowed for tech details)
  bool get isLocked => _isPaid || isCompleted;

  // Payment controls: only locked when fully paid (not when just completed)
  bool get isPaymentLocked => _isPaid;

  @override
  void initState() {
    super.initState();
    _commentsController = TextEditingController(
      text: widget.reservation.technicianComments,
    );
    _solutionController = TextEditingController(
      text: widget.reservation.solution,
    );

    // Initialize Payment Controllers
    _institutionController = TextEditingController(
      text: widget.reservation.paymentInstitution,
    );
    _voucherController = TextEditingController(
      text: widget.reservation.paymentVoucher,
    );
    _isPaid = widget.reservation.isPaid;
    _paymentMethod = widget.reservation.paymentMethod ?? 'efectivo';

    // Restore servicesData from saved reservation
    final savedServices = widget.reservation.servicesData;
    if (savedServices != null && savedServices.isNotEmpty) {
      for (final s in savedServices) {
        _selectedServices.add({
          'name': s['name'],
          'price': (s['price'] as num).toDouble(),
        });
        _servicesTotal += (s['price'] as num).toDouble();
      }
    }

    // Restore partsData from saved reservation
    final savedParts = widget.reservation.partsData;
    if (savedParts != null && savedParts.isNotEmpty) {
      for (final p in savedParts) {
        _selectedParts.add({
          'productId': p['productId'] ?? '',
          'name': p['name'],
          'price': (p['price'] as num).toDouble(),
          'paymentMethod': p['paymentMethod'] ?? 'efectivo',
        });
        _partsTotal += (p['price'] as num).toDouble();
      }
    }

    _currentStatus = widget.reservation.status;
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final role = await RoleService().getUserRole(user.uid);
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentsController.dispose();
    _solutionController.dispose();
    _institutionController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> updateData = {'status': newStatus};

      if (newStatus == 'completado') {
        final double laborCost = _servicesTotal;
        final double totalCost = laborCost + _partsTotal;

        String partsString = widget.reservation.spareParts ?? '';
        if (_selectedParts.isNotEmpty) {
          partsString = _selectedParts
              .map((p) {
                final pm = p['paymentMethod'] ?? 'efectivo';
                final icon = pm == 'tarjeta' ? '💳' : '💵';
                return '${p['name']} ($icon\$${p['price']})';
              })
              .join(', ');
        }

        updateData.addAll({
          'technicianId': AuthService().currentUser?.uid,
          'technicianComments': _commentsController.text.trim(),
          'solution': _solutionController.text.trim(),
          'repairCost': totalCost,
          'spareParts': partsString,
          if (_selectedParts.isNotEmpty)
            'partsData': _selectedParts.map((p) => {
              'productId': p['productId'] ?? '',
              'name': p['name'],
              'price': p['price'],
              'paymentMethod': p['paymentMethod'],
            }).toList(),
          if (_selectedServices.isNotEmpty)
            'servicesData': _selectedServices.map((s) => {
              'name': s['name'],
              'price': s['price'],
            }).toList(),
        });
      }

      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservation.id)
          .update(updateData);

      if (newStatus == 'cancelado' && _currentStatus == 'completado') {
        final svc = ReservationAccountingService();
        await svc.registerReversal(
          reservationId: widget.reservation.id,
          clientName: widget.reservation.clientName,
          clientId: widget.reservation.clientId,
          servicesTotal: _servicesTotal,
          partsTotal: _partsTotal,
          serviceType: widget.reservation.serviceType,
          paymentMethod: _paymentMethod,
          applyVAT: _applyVAT,
        );
      }

      if (newStatus == 'completado') {
        final svc = ReservationAccountingService();
        final userId = AuthService().currentUser?.uid ?? '';

        // Descontar inventario (idempotente dentro del servicio)
        await svc.deductInventoryForParts(
          reservationId: widget.reservation.id,
          clientName: widget.reservation.clientName,
          parts: _selectedParts,
          userId: userId,
        );

        // NO registrar ingreso contable aquí — solo se registra cuando
        // el cliente realiza un pago real. Si ya hay abonos previos,
        // crear CxC por el saldo pendiente.
        if (!_isPaid) {
          final total = _servicesTotal + _partsTotal;
          final totalPaid = widget.reservation.totalPaid ?? 0.0;

          if (totalPaid > 0) {
            // Ya tiene abonos → registrar ingreso por lo pagado y crear CxC por el resto
            await svc.registerIncomeForPayment(
              reservationId: widget.reservation.id,
              serviceType: widget.reservation.serviceType,
              clientName: widget.reservation.clientName,
              clientId: widget.reservation.clientId,
              servicesTotal: _servicesTotal,
              partsTotal: _partsTotal,
              paidAmount: totalPaid,
              paymentMethod: _paymentMethod,
              selectedParts: _selectedParts,
              applyVAT: _applyVAT,
            );
          }
          // Crear CxC por el saldo pendiente (total o diferencia)
          final pendingBalance = (total - totalPaid).clamp(0.0, double.infinity);
          if (pendingBalance > 0) {
            await svc.createReceivableForBalance(
              reservationId: widget.reservation.id,
              clientName: widget.reservation.clientName,
              clientId: widget.reservation.clientId.isNotEmpty ? widget.reservation.clientId : null,
              total: total,
              totalPaid: totalPaid,
              date: DateTime.now(),
              serviceType: widget.reservation.serviceType,
            );
          }
        }
      }

      setState(() {
        _currentStatus = newStatus;
        _isLoading = false;
      });

      if (mounted) {
        String statusLabel = newStatus;
        switch (newStatus) {
          case 'pendiente':
            statusLabel = l10n.statusPending;
            break;
          case 'confirmado':
            statusLabel = l10n.statusConfirmed;
            break;
          case 'en_proceso':
            statusLabel = l10n.statusInProcess;
            break;
          case 'aprobado':
            statusLabel = l10n.statusApproved;
            break;
          case 'completado':
            statusLabel = l10n.statusCompleted;
            break;
          case 'rechazado':
            statusLabel = l10n.statusRejected;
            break;
          case 'cancelado':
            statusLabel = l10n.statusCancelled;
            break;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado actualizado a $statusLabel')),
        );
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e')));
      }
    }
  }

  Future<void> _saveTechDetails() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final double laborCost = _servicesTotal;
      final double totalCost = laborCost + _partsTotal;

      String partsString = widget.reservation.spareParts ?? '';
      if (_selectedParts.isNotEmpty) {
        partsString = _selectedParts
            .map((p) {
              final pm = p['paymentMethod'] ?? 'efectivo';
              final icon = pm == 'tarjeta' ? '💳' : '💵';
              return '${p['name']} ($icon\$${p['price']})';
            })
            .join(', ');
      }

      final techData = {
        'technicianId': AuthService().currentUser?.uid,
        'technicianComments': _commentsController.text.trim(),
        'solution': _solutionController.text.trim(),
        'repairCost': totalCost,
        'spareParts': partsString,
        if (_selectedParts.isNotEmpty)
          'partsData': _selectedParts.map((p) => {
            'productId': p['productId'] ?? '',
            'name': p['name'],
            'price': p['price'],
            'paymentMethod': p['paymentMethod'],
          }).toList(),
        if (_selectedServices.isNotEmpty)
          'servicesData': _selectedServices.map((s) => {
            'name': s['name'],
            'price': s['price'],
          }).toList(),
      };

      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservation.id)
          .update(techData);

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.techDetailsSaved)));
      }
      // ... notifications logic ...
    } catch (e) {
      debugPrint('Error saving details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e')));
      }
    }
  }

  Future<void> _savePaymentDetails() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final resRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservation.id);

      final updates = <String, dynamic>{
        'isPaid': _isPaid,
        'paymentMethod': _paymentMethod,
        'paymentInstitution': _institutionController.text.trim(),
        'paymentVoucher': _voucherController.text.trim(),
      };

      await resRef.update(updates);

      if (_isPaid && _currentStatus == 'completado') {
        final total = _servicesTotal + _partsTotal;
        if (total <= 0) return;

        // Calcular cuánto ya se pagó via abonos
        final paymentsSnap = await resRef.collection('payments').get();
        final hadPriorPayments = paymentsSnap.docs.isNotEmpty;
        double totalPaid = 0;
        for (final p in paymentsSnap.docs) {
          totalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
        }
        final pendingBalance = (total - totalPaid).clamp(0.0, double.infinity);

        // Si queda saldo, registrar un pago por la diferencia
        if (pendingBalance > 0) {
          await resRef.collection('payments').add({
            'amount': pendingBalance,
            'method': _paymentMethod,
            'institution': _institutionController.text.trim(),
            'voucher': _voucherController.text.trim(),
            'note': 'Pago completo al marcar como pagado',
            'date': Timestamp.now(),
            'reservationId': widget.reservation.id,
          });
          totalPaid += pendingBalance;
        }

        // Actualizar totales en la reserva
        await resRef.update({
          'totalPaid': totalPaid,
          'paidAmount': totalPaid,
          'balance': 0.0,
          'paymentStatus': 'paid',
        });

        // Manejar CxC: eliminar si existe (pago completo = no necesita CxC)
        final existingCxC = await FirebaseFirestore.instance
            .collection('accounts_receivable')
            .where('originId', isEqualTo: widget.reservation.id)
            .where('originType', isEqualTo: 'reservation')
            .limit(1)
            .get();
        if (existingCxC.docs.isNotEmpty) {
          await existingCxC.docs.first.reference.delete();
        }

        // Registrar ingreso contable
        final svc = ReservationAccountingService();
        if (!hadPriorPayments) {
          // Sin abonos previos → registrar ingreso completo
          await svc.registerIncome(
            reservationId: widget.reservation.id,
            serviceType: widget.reservation.serviceType,
            clientName: widget.reservation.clientName,
            clientId: widget.reservation.clientId,
            servicesTotal: _servicesTotal,
            partsTotal: _partsTotal,
            paymentMethod: _paymentMethod,
            selectedParts: _selectedParts,
            applyVAT: _applyVAT,
          );
        } else {
          // Había abonos → registrar solo el saldo restante
          await svc.registerRemainingBalance(
            reservationId: widget.reservation.id,
            serviceType: widget.reservation.serviceType,
            clientName: widget.reservation.clientName,
            clientId: widget.reservation.clientId,
            total: total,
            totalPaid: totalPaid - pendingBalance,
            paymentMethod: _paymentMethod,
            applyVAT: _applyVAT,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.paymentDetailsSaved)));
      }
    } catch (e) {
      debugPrint('Error saving payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e')));
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    final phone = widget.reservation.clientPhone.replaceAll(RegExp(r'\D'), '');
    final l10n = AppLocalizations.of(context)!;
    final message = l10n.whatsappMessage(widget.reservation.serviceType);
    final url = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorSaving('WhatsApp'))));
      }
    }
  }

  void _removeService(int index) {
    setState(() {
      _servicesTotal -= (_selectedServices[index]['price'] as double);
      _selectedServices.removeAt(index);
    });
  }

  void _showServicesSelectionDialog() {
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Seleccionar Servicio'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Buscar servicio',
                        hintText: 'Nombre del servicio',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('services')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(child: Text('Error al cargar servicios'));
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final allServices = snapshot.data!.docs;
                          final filtered = searchQuery.isEmpty
                              ? allServices
                              : allServices.where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final name = (data['name'] ?? data['title'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final description = (data['description'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  return name.contains(searchQuery) ||
                                      description.contains(searchQuery);
                                }).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Text(
                                'No se encontraron servicios',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final data =
                                  filtered[index].data() as Map<String, dynamic>;
                              final name = data['name'] ?? data['title'] ?? 'Servicio';
                              final price = (data['price'] as num?)?.toDouble() ?? 0.0;

                              return ListTile(
                                title: Text(name),
                                subtitle: Text(
                                  '\$${price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedServices.add({
                                        'name': name,
                                        'price': price,
                                      });
                                      _servicesTotal += price;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPartsSelectionDialog() {
    String searchQuery = '';
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.selectSpareParts),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    // Search TextField
                    TextField(
                      decoration: InputDecoration(
                        labelText: l10n.searchProduct,
                        hintText: l10n.searchProductHint,
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Products List
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('products')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Text(l10n.errorLoadingProducts);
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          // Filter products based on search query
                          final allProducts = snapshot.data!.docs;
                          final filteredProducts = searchQuery.isEmpty
                              ? allProducts
                              : allProducts.where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final name = (data['name'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final category = (data['category'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final specs = (data['specs'] ?? '')
                                      .toString()
                                      .toLowerCase();

                                  return name.contains(searchQuery) ||
                                      category.contains(searchQuery) ||
                                      specs.contains(searchQuery);
                                }).toList();

                          if (filteredProducts.isEmpty) {
                            return const Center(
                              child: Text(
                                'No se encontraron productos',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final doc = filteredProducts[index];
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              final productId = doc.id;
                              final name = data['name'] ?? 'Producto';
                              final cashPrice = (data['cardPrice'] as num?)?.toDouble() ?? (data['price'] ?? 0).toDouble();
                              final cardPrice = (data['price'] ?? 0).toDouble();
                              final category = data['category'] ?? '';
                              final stock = (data['stock'] as num?)?.toInt() ?? 0;
                              final outOfStock = stock <= 0;

                              return ListTile(
                                title: Text(name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (category.isNotEmpty)
                                      Text(category, style: const TextStyle(fontSize: 12)),
                                    const SizedBox(height: 2),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(fontSize: 12),
                                        children: [
                                          TextSpan(
                                            text: '💵 \$${cashPrice.toStringAsFixed(2)}',
                                            style: TextStyle(color: Colors.green.shade700),
                                          ),
                                          TextSpan(
                                            text: '  💳 \$${cardPrice.toStringAsFixed(2)}',
                                            style: TextStyle(color: Colors.blue.shade700),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      outOfStock ? '🔴 Sin stock' : 'Stock: $stock',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: outOfStock ? Colors.red : Colors.grey[600],
                                        fontWeight: outOfStock ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.add_circle,
                                    color: outOfStock ? Colors.grey : Colors.blue,
                                  ),
                                  onPressed: outOfStock
                                      ? null
                                      : () {
                                          Navigator.pop(context);
                                          _showPaymentMethodPicker(productId, name, cashPrice, cardPrice);
                                        },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPaymentMethodPicker(String productId, String name, double cashPrice, double cardPrice) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.money, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Efectivo: \$${cashPrice.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.credit_card, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('Tarjeta: \$${cardPrice.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Selecciona la forma de pago:'),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedParts.add({
                    'productId': productId,
                    'name': name,
                    'price': cashPrice,
                    'paymentMethod': 'efectivo',
                  });
                  _partsTotal += cashPrice;
                });
                Navigator.pop(context);
              },
              icon: const Icon(Icons.money, color: Colors.green),
              label: Text('Efectivo (\$${cashPrice.toStringAsFixed(2)})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade50,
                foregroundColor: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedParts.add({
                    'productId': productId,
                    'name': name,
                    'price': cardPrice,
                    'paymentMethod': 'tarjeta',
                  });
                  _partsTotal += cardPrice;
                });
                Navigator.pop(context);
              },
              icon: const Icon(Icons.credit_card, color: Colors.blue),
              label: Text('Tarjeta (\$${cardPrice.toStringAsFixed(2)})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade800,
              ),
            ),
          ],
        );
      },
    );
  }

  void _removePart(int index) {
    setState(() {
      _partsTotal -= _selectedParts[index]['price'];
      _selectedParts.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reservationDetailTitle),
        actions: [
          if (_currentStatus == 'completado' || _currentStatus == 'aprobado')
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _openReceiptPreview,
              tooltip: 'Imprimir Recibo',
            ),
          if ((_userRole == RoleService.TECHNICIAN ||
                _userRole == RoleService.ADMIN) && !isLocked)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveTechDetails,
              tooltip: l10n.saveChanges,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLocked)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.reservationCompletedWarning,
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildStatusHeader(),
                  const SizedBox(height: 20),
                  _buildClientInfoCard(),
                  const SizedBox(height: 20),
                  _buildServiceInfoCard(),
                  const SizedBox(height: 20),
                  const SizedBox(height: 10),
                  Text(
                    l10n.managementSection,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTechForm(),
                  const SizedBox(height: 10),
                  _buildPaymentControl(),
                  _buildClientPaymentButton(),
                  if (_currentStatus == 'completado' || _currentStatus == 'aprobado')
                    _buildPrintReceiptButton(),
                  const SizedBox(height: 30),
                  _userRole == RoleService.TECHNICIAN ||
                          _userRole == RoleService.ADMIN
                      ? _buildActionButtons()
                      : _buildClientActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusHeader() {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    switch (_currentStatus) {
      case 'pendiente':
        color = Colors.orange;
        break;
      case 'confirmado':
        color = Colors.blue;
        break;
      case 'en_proceso':
        color = Colors.purple;
        break;
      case 'completado':
      case 'aprobado':
        color = Colors.green;
        break;
      case 'rechazado':
      case 'cancelado':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    String statusLabel = _currentStatus.toUpperCase();
    switch (_currentStatus) {
      case 'pendiente':
        statusLabel = l10n.statusPending.toUpperCase();
        break;
      case 'confirmado':
        statusLabel = l10n.statusConfirmed.toUpperCase();
        break;
      case 'en_proceso':
        statusLabel = l10n.statusInProcess.toUpperCase();
        break;
      case 'aprobado':
        statusLabel = l10n.statusApproved.toUpperCase();
        break;
      case 'completado':
        statusLabel = l10n.statusCompleted.toUpperCase();
        break;
      case 'rechazado':
        statusLabel = l10n.statusRejected.toUpperCase();
        break;
      case 'cancelado':
        statusLabel = l10n.statusCancelled.toUpperCase();
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '${l10n.statusPrefix}: $statusLabel',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildClientInfoCard() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.clientInfoSection,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!isLocked)
                  IconButton(
                    icon: const Icon(Icons.message, color: Colors.green),
                    onPressed: _launchWhatsApp,
                    tooltip: 'Contactar por WhatsApp',
                  ),
              ],
            ),
            const Divider(),
            _buildInfoRow(
              '${l10n.fullNameLabelLabel}:',
              widget.reservation.clientName,
            ),
            _buildInfoRow(
              '${l10n.phoneLabelLabel}:',
              widget.reservation.clientPhone,
            ),
            _buildInfoRow(
              '${l10n.emailLabelLabel}:',
              widget.reservation.clientEmail,
            ),
            _buildInfoRow(
              '${l10n.addressLabelLabel}:',
              widget.reservation.address,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceInfoCard() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.serviceDetailsSection,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow(
              '${l10n.deviceModelLabelLabel}:',
              widget.reservation.device,
            ),
            _buildInfoRow(
              '${l10n.serviceTypeLabelLabel}:',
              widget.reservation.serviceType,
            ),
            _buildInfoRow(
              '${l10n.date}:',
              DateFormat('dd/MM/yyyy').format(widget.reservation.scheduledDate),
            ),
            _buildInfoRow('${l10n.time}:', widget.reservation.scheduledTime),
            const SizedBox(height: 8),
            Text(
              '${l10n.reportedProblemLabel}:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(widget.reservation.description),
          ],
        ),
      ),
    );
  }

  Widget _buildTechForm() {
    final l10n = AppLocalizations.of(context)!;
    if (_userRole != RoleService.TECHNICIAN && _userRole != RoleService.ADMIN) {
      return Column(
        children: [
          _buildInfoRow(
            '${l10n.techCommentsLabel}:',
            widget.reservation.technicianComments ?? l10n.statusPending,
          ),
          _buildInfoRow(
            '${l10n.solutionLabel}:',
            widget.reservation.solution ?? l10n.statusPending,
          ),
          _buildInfoRow(
            '${l10n.repairCostLabel}:',
            widget.reservation.repairCost != null
                ? '\$${widget.reservation.repairCost}'
                : l10n.statusPending,
          ),
          _buildInfoRow(
            '${l10n.sparePartsLabel}:',
            widget.reservation.spareParts ?? '—',
          ),
          if (_selectedServices.isNotEmpty)
            _buildInfoRow(
              'Servicios de Mano de Obra:',
              _selectedServices.map((s) => '${s['name']} (\$${s['price']})').join(', '),
            ),
        ],
      );
    }

    return Column(
      children: [
        TextField(
          controller: _commentsController,
          maxLines: 2,
          enabled: !isLocked,
          decoration: InputDecoration(
            labelText: l10n.techCommentsLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _solutionController,
          maxLines: 2,
          enabled: !isLocked,
          decoration: InputDecoration(
            labelText: l10n.solutionLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        // Labor Services Section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.laborCostLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (!isLocked)
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: _showServicesSelectionDialog,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    tooltip: 'Agregar Servicio',
                  ),
              ],
            ),
            if (_selectedServices.isEmpty)
              Text('—', style: TextStyle(color: Colors.grey[600]))
            else
              Wrap(
                spacing: 8,
                children: List.generate(_selectedServices.length, (index) {
                  final svc = _selectedServices[index];
                  return Chip(
                    avatar: const Icon(Icons.build, size: 16, color: Colors.blue),
                    label: Text(
                      '${svc['name']} (\$${svc['price']})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onDeleted: isLocked
                        ? null
                        : () => _removeService(index),
                    deleteIconColor: Colors.red,
                    visualDensity: VisualDensity.compact,
                  );
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Spare Parts Section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.sparePartsLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (!isLocked)
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: Colors.blue,
                    ),
                    onPressed: _showPartsSelectionDialog,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    tooltip: l10n.selectSpareParts,
                  ),
              ],
            ),
            if (_selectedParts.isEmpty &&
                (widget.reservation.spareParts == null ||
                    widget.reservation.spareParts!.isEmpty))
              Text('—', style: TextStyle(color: Colors.grey[600]))
            else if (_selectedParts.isEmpty &&
                widget.reservation.spareParts != null)
              Text(
                widget.reservation.spareParts!,
                style: const TextStyle(fontSize: 13),
              )
            else
              Wrap(
                spacing: 8,
                children: List.generate(_selectedParts.length, (index) {
                  final part = _selectedParts[index];
                  final pm = part['paymentMethod'] ?? 'efectivo';
                  return Chip(
                    avatar: Icon(
                      pm == 'tarjeta'
                          ? Icons.credit_card
                          : Icons.money,
                      size: 16,
                      color: pm == 'tarjeta'
                          ? Colors.blue
                          : Colors.green,
                    ),
                    label: Text(
                      '${part['name']} (\$${part['price']})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onDeleted: isLocked
                        ? null
                        : () => _removePart(index),
                    deleteIconColor: Colors.red,
                    visualDensity: VisualDensity.compact,
                  );
                }),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_selectedParts.isNotEmpty || _selectedServices.isNotEmpty)
          _buildPaymentMethodSummary(),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${l10n.estimatedTotalLabel}: \$${(_servicesTotal + _partsTotal).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSummary() {
    final cashTotal = _selectedParts
        .where((p) => p['paymentMethod'] == 'efectivo')
        .fold<double>(0.0, (total, p) => total + (p['price'] as double));
    final cardTotal = _selectedParts
        .where((p) => p['paymentMethod'] == 'tarjeta')
        .fold<double>(0.0, (total, p) => total + (p['price'] as double));
    final laborTotal = _servicesTotal;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (cashTotal > 0) ...[
            Icon(Icons.money, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 4),
            Text(
              'Efectivo: \$${cashTotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 16),
          ],
            if (cardTotal > 0) ...[
            Icon(Icons.credit_card, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Text(
              'Tarjeta: \$${cardTotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (laborTotal > 0) ...[
            Icon(Icons.build, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Text(
              'Mano Obra: \$${laborTotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _registerReservationPayment({
    required double amount,
    required String method,
    String? institution,
    String? voucher,
    String? note,
  }) async {
    try {
      final resRef = FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservation.id);
      final resDoc = await resRef.get();
      if (!resDoc.exists) return;

      final data = resDoc.data() as Map<String, dynamic>;
      final total = (data['repairCost'] as num?)?.toDouble() ?? 0.0;
      final prevTotalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
      final newTotalPaid = prevTotalPaid + amount;
      final newBalance = (total - newTotalPaid).clamp(0.0, double.infinity);

      await resRef.collection('payments').add({
        'amount': amount,
        'method': method,
        'institution': institution ?? '',
        'voucher': voucher ?? '',
        'note': note ?? '',
        'date': Timestamp.now(),
        'reservationId': widget.reservation.id,
      });

      final newPaymentStatus = newTotalPaid >= total ? 'paid' : 'partial';
      await resRef.update({
        'totalPaid': newTotalPaid,
        'paidAmount': newTotalPaid,
        'balance': newBalance,
        'paymentStatus': newPaymentStatus,
      });

      // Actualizar CxC existente si la reserva ya fue completada
      final existingCxC = await FirebaseFirestore.instance
          .collection('accounts_receivable')
          .where('originId', isEqualTo: widget.reservation.id)
          .where('originType', isEqualTo: 'reservation')
          .limit(1)
          .get();
      if (existingCxC.docs.isNotEmpty) {
        final cxcRef = existingCxC.docs.first.reference;
        final cxcData = existingCxC.docs.first.data();
        final cxcCurrentPaid = (cxcData['paidAmount'] as num?)?.toDouble() ?? 0.0;
        final cxcTotalAmount = (cxcData['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final newCxcPaid = cxcCurrentPaid + amount;
        final newCxcStatus = newCxcPaid >= cxcTotalAmount ? 'pagada' : 'parcial';
        await cxcRef.update({
          'paidAmount': newCxcPaid,
          'balance': (cxcTotalAmount - newCxcPaid).clamp(0.0, double.infinity),
          'status': newCxcStatus,
          'lastPaymentDate': Timestamp.fromDate(DateTime.now()),
        });
      }

      // Si el servicio ya está completado, registrar ingreso contable por este abono
      if (_currentStatus == 'completado') {
        final svc = ReservationAccountingService();
        await svc.registerIncomeForPayment(
          reservationId: widget.reservation.id,
          serviceType: widget.reservation.serviceType,
          clientName: widget.reservation.clientName,
          clientId: widget.reservation.clientId,
          servicesTotal: _servicesTotal,
          partsTotal: _partsTotal,
          paidAmount: amount,
          paymentMethod: method,
          selectedParts: _selectedParts,
          applyVAT: _applyVAT,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Abono registrado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar abono: $e')),
        );
      }
    }
  }

  Future<void> _showAddReservationPaymentDialog(double total, double totalPaid) async {
    final amountController = TextEditingController();
    final institutionController = TextEditingController();
    final voucherController = TextEditingController();
    final noteController = TextEditingController();
    String method = 'efectivo';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Registrar Abono'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Saldo pendiente: \$${(total - totalPaid).clamp(0.0, double.infinity).toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto del abono *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payment),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                    DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                    DropdownMenuItem(value: 'credito', child: Text('Crédito')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => method = val);
                    }
                  },
                ),
                if (method == 'transferencia') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: institutionController,
                    decoration: const InputDecoration(
                      labelText: 'Institución',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: voucherController,
                    decoration: const InputDecoration(
                      labelText: 'Voucher/Comprobante',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.receipt),
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (amount <= 0) return;
                Navigator.pop(ctx);
                _registerReservationPayment(
                  amount: amount,
                  method: method,
                  institution: institutionController.text.trim().isNotEmpty
                      ? institutionController.text.trim()
                      : null,
                  voucher: voucherController.text.trim().isNotEmpty
                      ? voucherController.text.trim()
                      : null,
                  note: noteController.text.trim().isNotEmpty
                      ? noteController.text.trim()
                      : null,
                );
              },
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Guardar Abono'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentControl() {
    final l10n = AppLocalizations.of(context)!;
    if ((_userRole != RoleService.TECHNICIAN &&
            _userRole != RoleService.ADMIN) ||
        _currentStatus != 'completado') {
      return const SizedBox.shrink();
    }

    final total = _servicesTotal + _partsTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(
          l10n.paymentControlSection,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        // IVA Toggle
        Card(
          child: SwitchListTile(
            title: const Text('Aplicar IVA (15%)', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Solo si el cliente requiere factura con IVA', style: TextStyle(fontSize: 10)),
            value: _applyVAT,
            onChanged: (v) => setState(() => _applyVAT = v),
            dense: true,
            secondary: Icon(Icons.receipt, size: 20, color: _applyVAT ? Colors.indigo : Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        // Selector de método de pago visual
        if (!isPaymentLocked) ...[
          Text('Método de Pago', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _paymentMethodCard('efectivo', 'Efectivo', Icons.money, '1.1.01.01', 'Caja General', Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _paymentMethodCard('tarjeta', 'Tarjeta', Icons.credit_card, '1.1.01.03', 'Bancos', Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _paymentMethodCard('transferencia', 'Transferencia', Icons.account_balance, '1.1.01.03', 'Bancos', Colors.purple)),
            ],
          ),
          const SizedBox(height: 8),
          // Campos adicionales para transferencia/tarjeta
          if (_paymentMethod == 'transferencia' || _paymentMethod == 'tarjeta') ...[
            TextField(
              controller: _institutionController,
              enabled: !isPaymentLocked,
              decoration: InputDecoration(
                labelText: _paymentMethod == 'tarjeta' ? 'Banco / Pasarela' : 'Institución Financiera',
                isDense: true,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.account_balance, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _voucherController,
              enabled: !isPaymentLocked,
              decoration: const InputDecoration(
                labelText: 'Nº Comprobante / Voucher',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.receipt, size: 18),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Toggle pago realizado
          Card(
            child: SwitchListTile(
              title: Text(
                _isPaid ? '✓ Pago Realizado' : 'Marcar como Pagado',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isPaid ? Colors.green[700] : null,
                ),
              ),
              subtitle: Text(
                _isPaid ? 'El cliente ya pagó este servicio' : 'Activar cuando reciba el pago',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              value: _isPaid,
              onChanged: isPaymentLocked
                  ? null
                  : (val) {
                      setState(() => _isPaid = val);
                      _savePaymentDetails();
                    },
              secondary: Icon(
                _isPaid ? Icons.check_circle : Icons.payment,
                color: _isPaid ? Colors.green : Colors.grey,
                size: 24,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Resumen de progreso de pago
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reservations')
              .doc(widget.reservation.id)
              .collection('payments')
              .orderBy('date', descending: false)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.orange, size: 32),
                      const SizedBox(height: 8),
                      Text('Error al cargar datos', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('${snap.error}', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }
            final payments = snap.data?.docs ?? [];
            double totalPaid = 0;
            for (final p in payments) {
              totalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
            }
            final balance = (total - totalPaid).clamp(0.0, double.infinity);
            final progress = total > 0 ? totalPaid / total : 0.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, size: 20, color: Colors.indigo),
                          const SizedBox(width: 8),
                          const Text('Abonos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Spacer(),
                          if (total > 0 && !isPaymentLocked)
                            TextButton.icon(
                              onPressed: () => _showAddReservationPaymentDialog(total, totalPaid),
                              icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFFFF8C00)),
                              label: const Text('Agregar', style: TextStyle(color: Color(0xFFFF8C00))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 1.0 ? Colors.green : const Color(0xFFFF8C00),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pagado: \$${totalPaid.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green[700]),
                          ),
                          Text(
                            'Total: \$${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: balance <= 0 ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: balance <= 0 ? Colors.green.shade200 : Colors.orange.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              balance <= 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                              size: 18,
                              color: balance <= 0 ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              balance <= 0
                                  ? 'Saldo: PAGADO'
                                  : 'Saldo pendiente: \$${balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: balance <= 0 ? Colors.green[800] : Colors.orange[800],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Lista de abonos registrados
                if (payments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...payments.map((p) {
                    final pAmount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                    final pMethod = (p['method'] ?? '').toString();
                    final pDate = p['date'] is Timestamp ? (p['date'] as Timestamp).toDate() : DateTime.now();
                    final pVoucher = p['voucher'] ?? '';
                    final pNote = p['note'] ?? '';
                    IconData methodIcon;
                    Color methodColor;
                    switch (pMethod) {
                      case 'transferencia':
                        methodIcon = Icons.account_balance;
                        methodColor = Colors.purple;
                        break;
                      case 'tarjeta':
                        methodIcon = Icons.credit_card;
                        methodColor = Colors.blue;
                        break;
                      default:
                        methodIcon = Icons.money;
                        methodColor = Colors.green;
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: methodColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(methodIcon, size: 18, color: methodColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pMethod.toUpperCase(),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: methodColor),
                                ),
                                if (pVoucher.toString().isNotEmpty || pNote.toString().isNotEmpty)
                                  Text(
                                    pVoucher.toString() + (pVoucher.toString().isNotEmpty && pNote.toString().isNotEmpty ? ' · ' : '') + pNote.toString(),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${pAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                              ),
                              Text(
                                DateFormat('dd/MM').format(pDate),
                                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _paymentMethodCard(String value, String label, IconData icon, String accountCode, String accountName, Color color) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
        onTap: isPaymentLocked ? null : () {
        setState(() => _paymentMethod = value);
        _savePaymentDetails();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(25) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: color.withAlpha(30), blurRadius: 6, offset: const Offset(0, 2)),
          ] : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[500], size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color.withAlpha(20) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                accountCode,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientPaymentButton() {
    return const SizedBox.shrink();
  }

  Widget _buildPrintReceiptButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openReceiptPreview,
          icon: const Icon(Icons.print),
          label: const Text('Imprimir Recibo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Future<void> _openReceiptPreview() async {
    final r = widget.reservation;

    final services = <ReceiptItem>[];
    final parts = <ReceiptItem>[];

    final servicesData = r.servicesData ?? _selectedServices;
    for (final s in servicesData) {
      final desc = (s['name'] ?? s['serviceName'] ?? s['description'] ?? '').toString();
      final qty = (s['quantity'] ?? s['qty'] ?? 1) as int;
      final unit = (s['unitCost'] ?? s['price'] ?? 0).toDouble();
      services.add(ReceiptItem(description: desc, unitPrice: unit, quantity: qty));
    }

    final partsData = r.partsData ?? _selectedParts;
    for (final p in partsData) {
      final desc = (p['name'] ?? p['partName'] ?? p['description'] ?? '').toString();
      final qty = (p['quantity'] ?? p['qty'] ?? 1) as int;
      final unit = (p['unitCost'] ?? p['price'] ?? 0).toDouble();
      parts.add(ReceiptItem(description: desc, unitPrice: unit, quantity: qty));
    }

    String? techName;
    if (r.technicianId != null && r.technicianId!.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(r.technicianId).get();
        if (doc.exists && doc.data() != null) {
          techName = doc.data()!['name'] ?? doc.data()!['displayName'] ?? r.technicianId;
        }
      } catch (_) {
        techName = r.technicianId;
      }
    }

    final subtotal = _servicesTotal + _partsTotal;
    final iva = _applyVAT ? subtotal * 0.15 : 0.0;
    final discount = 0.0;
    final total = subtotal + iva - discount;
    final pendingBalance = r.isPaid ? 0.0 : total - (r.totalPaid ?? 0.0);

    final data = WorkshopReceiptData(
      saleNumber: r.id.toUpperCase(),
      date: r.scheduledDate,
      clientName: r.clientName,
      clientId: r.clientId,
      clientPhone: r.clientPhone,
      clientEmail: r.clientEmail,
      clientAddress: r.address,
      deviceType: r.serviceType,
      brand: '',
      model: '',
      serialNumber: '',
      accessories: '',
      reportedFault: r.description,
      receptionDate: r.scheduledDate,
      estimatedDeliveryDate: null,
      diagnosis: r.solution ?? '',
      services: services,
      parts: parts,
      warrantyTerms: '30 días sobre mano de obra. No cubre daños por líquidos.',
      subtotal: subtotal,
      iva: iva,
      discount: discount,
      total: total,
      paymentMethod: r.paymentMethod ?? '',
      advance: r.totalPaid ?? 0.0,
      pendingBalance: pendingBalance > 0 ? pendingBalance : 0.0,
      technicianName: techName,
      additionalNotes: r.solution,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptPreviewPage(data: data),
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    if (isLocked) return const SizedBox.shrink();

    return Column(
      children: [
        if (_currentStatus == 'pendiente')
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus('rechazado'),
                  icon: const Icon(Icons.cancel),
                  label: Text(l10n.statusRejected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus('confirmado'),
                  icon: const Icon(Icons.check_circle),
                  label: Text(l10n.statusConfirmed),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[50],
                    foregroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        if (_currentStatus == 'confirmado' || _currentStatus == 'aprobado')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus('en_proceso'),
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.statusInProcess),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blue,
              ),
            ),
          ),
        if (_currentStatus == 'en_proceso')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus('completado'),
              icon: const Icon(Icons.done_all),
              label: Text(l10n.statusCompleted),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildClientActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    if (_currentStatus != 'pendiente' && _currentStatus != 'confirmado') {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text(
          l10n.welcomeBack, // Or appropriate key for "Do you want to proceed?"
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus('cancelado'),
                icon: const Icon(Icons.close),
                label: Text(l10n.statusCancelled),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                ),
              ),
            ),
            if (_currentStatus == 'confirmado') ...[
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus('aprobado'),
                  icon: const Icon(Icons.thumb_up),
                  label: Text(l10n.statusApproved),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[50],
                    foregroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
