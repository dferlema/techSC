import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:techsc/features/reservations/models/reservation_model.dart';
import 'package:techsc/features/auth/services/auth_service.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  late TextEditingController _laborCostController;
  late String _currentStatus;
  String _userRole = RoleService.CLIENT;
  bool _isLoading = false;

  // Payment Logic
  late TextEditingController _paymentLinkController;
  late TextEditingController _institutionController;
  late TextEditingController _voucherController;
  bool _isPaid = false;
  bool _isSavingPayment = false;
  String _paymentMethod = 'efectivo'; // efectivo, transferencia, tarjeta

  // Spare Parts Logic
  final List<Map<String, dynamic>> _selectedParts = [];
  double _partsTotal = 0.0;

  // Check if reservation is completed (read-only mode)
  bool get isCompleted => _currentStatus == 'completado';

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
    _paymentLinkController = TextEditingController(
      text: widget.reservation.paymentLink,
    );
    _institutionController = TextEditingController(
      text: widget.reservation.paymentInstitution,
    );
    _voucherController = TextEditingController(
      text: widget.reservation.paymentVoucher,
    );
    _isPaid = widget.reservation.isPaid;
    _paymentMethod = widget.reservation.paymentMethod ?? 'efectivo';

    // Initialize Labor Cost (Total - Parts, or just Total if parsing fails)
    // Ideally we would have stored laborCost separately, but we only have repairCost (Total)
    // and spareParts (String). We will try to rely on user input or defaults.
    // For now, init with the total repair cost. The user can adjust labor.
    _laborCostController = TextEditingController(
      text: widget.reservation.repairCost?.toString() ?? '',
    );

    // We can't easily parse the existing 'spareParts' string back into objects
    // without a structured field. So if there's already a string, we might treat it as legacy text.
    // For this implementation, we will append new selections to existing text or just replace.
    // Let's assume we start fresh or just append to the string field for now.

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
    _laborCostController.dispose();
    _paymentLinkController.dispose();
    _institutionController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservation.id)
          .update({'status': newStatus});

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
      // ... notifications logic remains the same for internal IDs ...
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
      // ... logic for laborCost and totalCost ...
      final double laborCost =
          double.tryParse(_laborCostController.text.trim()) ?? 0.0;
      final double totalCost = laborCost + _partsTotal;

      String partsString = widget.reservation.spareParts ?? '';
      if (_selectedParts.isNotEmpty) {
        partsString = _selectedParts
            .map((p) => '${p['name']} (\$${p['price']})')
            .join(', ');
      }

      final techData = {
        'technicianId': AuthService().currentUser?.uid,
        'technicianComments': _commentsController.text.trim(),
        'solution': _solutionController.text.trim(),
        'repairCost': totalCost,
        'spareParts': partsString,
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
    setState(() => _isSavingPayment = true);
    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservation.id)
          .update({
            'paymentLink': _paymentLinkController.text.trim(),
            'isPaid': _isPaid,
            'paymentMethod': _paymentMethod,
            'paymentInstitution': _institutionController.text.trim(),
            'paymentVoucher': _voucherController.text.trim(),
          });

      setState(() => _isSavingPayment = false);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.paymentDetailsSaved)));
      }
    } catch (e) {
      debugPrint('Error saving payment: $e');
      if (mounted) {
        setState(() => _isSavingPayment = false);
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
                              final data =
                                  filteredProducts[index].data()
                                      as Map<String, dynamic>;
                              final name = data['name'] ?? 'Producto';
                              final price = (data['price'] ?? 0).toDouble();
                              final category = data['category'] ?? '';

                              return ListTile(
                                title: Text(name),
                                subtitle: Text(
                                  category.isNotEmpty
                                      ? '$category • \$${price.toStringAsFixed(2)}'
                                      : '\$${price.toStringAsFixed(2)}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedParts.add({
                                        'name': name,
                                        'price': price,
                                      });
                                      _partsTotal += price;
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
        actions:
            _userRole == RoleService.TECHNICIAN ||
                _userRole == RoleService.ADMIN
            ? [
                if (!isCompleted)
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _saveTechDetails,
                    tooltip: l10n.saveChanges,
                  ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCompleted)
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
        color: color.withOpacity(0.1),
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
                if (!isCompleted)
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
        ],
      );
    }

    return Column(
      children: [
        TextField(
          controller: _commentsController,
          maxLines: 2,
          enabled: !isCompleted,
          decoration: InputDecoration(
            labelText: l10n.techCommentsLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _solutionController,
          maxLines: 2,
          enabled: !isCompleted,
          decoration: InputDecoration(
            labelText: l10n.solutionLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _laborCostController,
                keyboardType: TextInputType.number,
                enabled: !isCompleted,
                decoration: InputDecoration(
                  labelText: '${l10n.laborCostLabel} (\$)',
                  border: const OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                onChanged: (val) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.sparePartsLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (!isCompleted)
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
                        return Chip(
                          label: Text(
                            '${part['name']} (\$${part['price']})',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: isCompleted
                              ? null
                              : () => _removePart(index),
                          deleteIconColor: Colors.red,
                          visualDensity: VisualDensity.compact,
                        );
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${l10n.estimatedTotalLabel}: \$${((double.tryParse(_laborCostController.text.trim()) ?? 0.0) + _partsTotal).toStringAsFixed(2)}',
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

  Widget _buildPaymentControl() {
    final l10n = AppLocalizations.of(context)!;
    if ((_userRole != RoleService.TECHNICIAN &&
            _userRole != RoleService.ADMIN) ||
        _currentStatus != 'completado') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(
          l10n.paymentControlSection,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _paymentLinkController,
                decoration: InputDecoration(
                  labelText: l10n.paymentLinkLabel,
                  hintText: 'https://...',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _isSavingPayment
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: _savePaymentDetails,
                    icon: const Icon(Icons.save, color: Colors.blue),
                    tooltip: 'Guardar Link',
                  ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Pago Realizado:'),
            Switch(
              value: _isPaid,
              onChanged: (val) {
                setState(() => _isPaid = val);
                _savePaymentDetails();
              },
              activeThumbColor: Colors.green,
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          value: _paymentMethod,
          decoration: InputDecoration(
            labelText: l10n.paymentMethodLabel,
            isDense: true,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.payment),
          ),
          items: [
            DropdownMenuItem(value: 'efectivo', child: Text(l10n.paymentCash)),
            DropdownMenuItem(
              value: 'transferencia',
              child: Text(l10n.paymentTransfer),
            ),
            DropdownMenuItem(value: 'tarjeta', child: Text(l10n.paymentCard)),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _paymentMethod = val);
              _savePaymentDetails();
            }
          },
        ),
        if (_paymentMethod == 'transferencia') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _institutionController,
            decoration: const InputDecoration(
              labelText: 'Institución Financiera',
              isDense: true,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.account_balance),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _voucherController,
            decoration: const InputDecoration(
              labelText: 'Número de Comprobante/Voucher',
              isDense: true,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.receipt),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _savePaymentDetails,
              icon: const Icon(Icons.save_alt, size: 16),
              label: const Text('Guardar Detalles Transferencia'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _launchPaymentLink(String urlString) async {
    final l10n = AppLocalizations.of(context)!;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorSaving('Link'))));
      }
    }
  }

  Widget _buildClientPaymentButton() {
    if (_userRole == RoleService.TECHNICIAN || _userRole == RoleService.ADMIN) {
      return const SizedBox.shrink();
    }

    if (_currentStatus != 'completado') return const SizedBox.shrink();

    final hasLink = _paymentLinkController.text.trim().isNotEmpty;
    if (!hasLink || _isPaid) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    if (_userRole != RoleService.CLIENT ||
        _currentStatus != 'completado' ||
        widget.reservation.paymentLink == null ||
        widget.reservation.paymentLink!.isEmpty ||
        _isPaid) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ElevatedButton.icon(
        onPressed: () => _launchPaymentLink(widget.reservation.paymentLink!),
        icon: const Icon(Icons.payment, size: 24),
        label: Text(
          l10n.reserveButton.toUpperCase(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context)!;
    if (isCompleted) return const SizedBox.shrink();

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
