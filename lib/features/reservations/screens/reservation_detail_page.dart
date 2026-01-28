import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:techsc/features/reservations/models/reservation_model.dart';
import 'package:techsc/features/auth/services/auth_service.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/core/services/notification_service.dart';

class ReservationDetailPage extends StatefulWidget {
  final ReservationModel reservation;

  const ReservationDetailPage({super.key, required this.reservation});

  @override
  State<ReservationDetailPage> createState() => _ReservationDetailPageState();
}

class _ReservationDetailPageState extends State<ReservationDetailPage> {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado actualizado a $newStatus')),
        );
      }

      // Notificaciones logic...
      if (newStatus == 'aprobado' || newStatus == 'cancelado') {
        await NotificationService().sendNotification(
          title: 'Trabajo ${newStatus.toUpperCase()}',
          body:
              'El cliente ha $newStatus el trabajo para ${widget.reservation.device}.',
          type: 'authorization',
          relatedId: widget.reservation.id,
          receiverId: widget.reservation.technicianId,
          receiverRole: widget.reservation.technicianId == null
              ? RoleService.TECHNICIAN
              : null,
        );
      }

      if (newStatus == 'confirmado' ||
          newStatus == 'completado' ||
          newStatus == 'en_proceso') {
        await NotificationService().sendNotification(
          title: 'Actualización de Estado',
          body:
              'Tu reserva esta ahora: ${newStatus.replaceAll('_', ' ').toUpperCase()}',
          type: 'reservation',
          relatedId: widget.reservation.id,
          receiverId: widget.reservation.userId,
        );
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _saveTechDetails() async {
    setState(() => _isLoading = true);
    try {
      final double laborCost =
          double.tryParse(_laborCostController.text.trim()) ?? 0.0;

      // Calculate Total
      final double totalCost = laborCost + _partsTotal;

      // Format Spare Parts String
      String partsString = widget.reservation.spareParts ?? '';
      if (_selectedParts.isNotEmpty) {
        final newPartsList = _selectedParts
            .map((p) => '${p['name']} (\$${p['price']})')
            .join(', ');
        // If there was previous text, append it or replace?
        // Let's replace if we have new selections, or append?
        // Safer to just store the new comprehensive list if selected, otherwise keep old.
        // Actually, let's concatenate for safety if both exist, or prioritize the new "clean" list.
        partsString = newPartsList;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Detalles técnicos guardados')),
        );
      }

      await NotificationService().sendNotification(
        title: 'Diagnostico Actualizado',
        body:
            'Se han actualizado los detalles de tu reserva. Por favor revisa para autorizar.',
        type: 'comment',
        relatedId: widget.reservation.id,
        receiverId: widget.reservation.userId,
      );
    } catch (e) {
      debugPrint('Error saving details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _savePaymentDetails() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Detalles de pago guardados')),
        );
      }
    } catch (e) {
      debugPrint('Error saving payment: $e');
      if (mounted) {
        setState(() => _isSavingPayment = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar pago: $e')));
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    // ... (Existing WhatsApp logic) ...
    // Re-implementing briefly for context completeness or skipping if not changing
    // Assuming the tool handles partial replacement correctly, I need to keep this.
    String phone = widget.reservation.clientPhone.replaceAll(RegExp(r'\D'), '');
    if (phone.length == 9 && phone.startsWith('9')) {
      phone = '593$phone';
    } else if (phone.length == 10 && phone.startsWith('0')) {
      phone = '593${phone.substring(1)}';
    }
    final message = Uri.encodeComponent(
      'Hola ${widget.reservation.clientName}, soy el técnico asignado a su caso de ${widget.reservation.device}...',
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al abrir WhatsApp: $e')));
      }
    }
  }

  void _showPartsSelectionDialog() {
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Seleccionar Repuestos'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    // Search TextField
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Buscar producto',
                        hintText: 'Nombre, categoría...',
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
                            return const Text('Error al cargar productos');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Reserva'),
        actions:
            _userRole == RoleService.TECHNICIAN ||
                _userRole == RoleService.ADMIN
            ? [
                if (!isCompleted)
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _saveTechDetails,
                    tooltip: 'Guardar cambios',
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
                              'Esta reserva está completada y no puede ser modificada',
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
                  const Text(
                    'Gestión y Seguimiento',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          'ESTADO: ${_currentStatus.toUpperCase()}',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Datos del Cliente',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_userRole == RoleService.TECHNICIAN ||
                    _userRole == RoleService.ADMIN)
                  InkWell(
                    onTap: _launchWhatsApp,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: SvgPicture.network(
                        'https://static.whatsapp.net/rsrc.php/yZ/r/JvsnINJ2CZv.svg',
                        width: 32,
                        height: 32,
                        placeholderBuilder: (BuildContext context) =>
                            const Icon(Icons.phone, color: Colors.green),
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(),
            _buildInfoRow('Nombre:', widget.reservation.clientName),
            _buildInfoRow('Teléfono:', widget.reservation.clientPhone),
            _buildInfoRow('Email:', widget.reservation.clientEmail),
            _buildInfoRow('Dirección:', widget.reservation.address),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalles del Servicio',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow('Dispositivo:', widget.reservation.device),
            _buildInfoRow('Tipo Servicio:', widget.reservation.serviceType),
            _buildInfoRow(
              'Fecha:',
              DateFormat('dd/MM/yyyy').format(widget.reservation.scheduledDate),
            ),
            _buildInfoRow('Hora:', widget.reservation.scheduledTime),
            const SizedBox(height: 8),
            const Text(
              'Problema Reportado:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(widget.reservation.description),
          ],
        ),
      ),
    );
  }

  Widget _buildTechForm() {
    if (_userRole != RoleService.TECHNICIAN && _userRole != RoleService.ADMIN) {
      return Column(
        children: [
          _buildInfoRow(
            'Comentarios:',
            widget.reservation.technicianComments ?? 'Pendiente',
          ),
          _buildInfoRow(
            'Solución:',
            widget.reservation.solution ?? 'Pendiente',
          ),
          _buildInfoRow(
            'Costo:',
            widget.reservation.repairCost != null
                ? '\$${widget.reservation.repairCost}'
                : 'Pendiente',
          ),
          _buildInfoRow(
            'Repuestos:',
            widget.reservation.spareParts ?? 'Ninguno',
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
          decoration: const InputDecoration(
            labelText: 'Comentarios Técnicos',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _solutionController,
          maxLines: 2,
          enabled: !isCompleted,
          decoration: const InputDecoration(
            labelText: 'Solución Aplicada',
            border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Mano de Obra (\$)',
                  border: OutlineInputBorder(),
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
                      const Text(
                        'Repuestos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (!isCompleted)
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blue,
                          ),
                          onPressed: _showPartsSelectionDialog,
                          tooltip: 'Agregar',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  if (_selectedParts.isEmpty)
                    const Text('Ninguno', style: TextStyle(color: Colors.grey)),
                  if (_selectedParts.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: _selectedParts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final part = entry.value;
                        return Chip(
                          label: Text('${part['name']}'),
                          onDeleted: isCompleted
                              ? null
                              : () => _removePart(index),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
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
            'Total Estimado: \$${((double.tryParse(_laborCostController.text.trim()) ?? 0.0) + _partsTotal).toStringAsFixed(2)}',
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
    if ((_userRole != RoleService.TECHNICIAN &&
            _userRole != RoleService.ADMIN) ||
        _currentStatus != 'completado') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text(
          'Control de Pagos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _paymentLinkController,
                decoration: const InputDecoration(
                  labelText: 'Link de Pago',
                  hintText: 'https://...',
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
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
          initialValue: _paymentMethod,
          decoration: const InputDecoration(
            labelText: 'Método de Pago',
            isDense: true,
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.payment),
          ),
          items: const [
            DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
            DropdownMenuItem(
              value: 'transferencia',
              child: Text('Transferencia'),
            ),
            DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
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
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el link de pago')),
        );
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

    return Container(
      margin: const EdgeInsets.only(top: 20),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _launchPaymentLink(_paymentLinkController.text.trim()),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.payment),
        label: const Text(
          'PAGAR AHORA',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    // Don't show action buttons if reservation is completed
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
                  label: const Text('Rechazar'),
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
                  label: const Text('Confirmar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[50],
                    foregroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        if (_currentStatus == 'confirmado' ||
            _currentStatus == 'en_proceso' ||
            _currentStatus == 'aprobado')
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus('en_proceso'),
                  icon: const Icon(Icons.build),
                  label: const Text('En Proceso'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[50],
                    foregroundColor: Colors.purple,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus('completado'),
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Finalizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[50],
                    foregroundColor: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildClientActionButtons() {
    // Don't show action buttons if reservation is completed
    if (isCompleted) return const SizedBox.shrink();

    // Only show if there's a cost and technical comments (implying a diagnosis was made)
    // and status is not already finalized/cancelled
    bool canAct =
        (_currentStatus == 'pendiente' ||
            _currentStatus == 'confirmado' ||
            _currentStatus == 'en_proceso') &&
        widget.reservation.repairCost != null;

    if (!canAct) return const SizedBox.shrink();

    return Column(
      children: [
        const Text(
          '¿Deseas proceder con el trabajo propuesto?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus('cancelado'),
                icon: const Icon(Icons.close),
                label: const Text('Rechazar Trabajo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus('aprobado'),
                icon: const Icon(Icons.thumb_up),
                label: const Text('Aprobar Trabajo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[50],
                  foregroundColor: Colors.green,
                ),
              ),
            ),
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
            width: 100,
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
