import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/reservation_model.dart';
import '../services/auth_service.dart';
import '../services/role_service.dart';
import '../services/notification_service.dart';

class ReservationDetailPage extends StatefulWidget {
  final ReservationModel reservation;

  const ReservationDetailPage({super.key, required this.reservation});

  @override
  State<ReservationDetailPage> createState() => _ReservationDetailPageState();
}

class _ReservationDetailPageState extends State<ReservationDetailPage> {
  late TextEditingController _commentsController;
  late TextEditingController _solutionController;
  late TextEditingController _costController;
  late TextEditingController _partsController;
  late String _currentStatus;
  String _userRole = RoleService.CLIENT; // Default to client
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _commentsController = TextEditingController(
      text: widget.reservation.technicianComments,
    );
    _solutionController = TextEditingController(
      text: widget.reservation.solution,
    );
    _costController = TextEditingController(
      text: widget.reservation.repairCost?.toString() ?? '',
    );
    _partsController = TextEditingController(
      text: widget.reservation.spareParts,
    );
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
    _costController.dispose();
    _partsController.dispose();
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

      // Notificaciones
      // 1. Cliente aprueba/rechaza -> Notificar Técnico
      if (newStatus == 'aprobado' || newStatus == 'cancelado') {
        await NotificationService().sendNotification(
          title: 'Trabajo ${newStatus.toUpperCase()}',
          body:
              'El cliente ha ${newStatus} el trabajo para ${widget.reservation.device}.',
          type: 'authorization',
          relatedId: widget.reservation.id,
          receiverId:
              widget.reservation.technicianId, // Si hay un técnico asignado
          receiverRole: widget.reservation.technicianId == null
              ? RoleService.TECHNICIAN
              : null,
        );
      }

      // 2. Técnico confirma/completa -> Notificar Cliente
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
      final double? cost = double.tryParse(_costController.text.trim());

      final techData = {
        'technicianId': AuthService().currentUser?.uid,
        'technicianComments': _commentsController.text.trim(),
        'solution': _solutionController.text.trim(),
        'repairCost': cost,
        'spareParts': _partsController.text.trim(),
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

      // Notificar al cliente que hay una actualización (diagnóstico/costo)
      await NotificationService().sendNotification(
        title: 'Diagnostico Actualizado',
        body:
            'Se han actualizado los detalles de tu reserva. Por favor revisa para autorizar.',
        type: 'comment', // O 'authorization'
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

  Future<void> _launchWhatsApp() async {
    String phone = widget.reservation.clientPhone.replaceAll(RegExp(r'\D'), '');

    // Add default country code if missing (assuming Ecuador +593 if starts with 0 or has 9 digits)
    if (phone.length == 9 && phone.startsWith('9')) {
      phone = '593$phone';
    } else if (phone.length == 10 && phone.startsWith('0')) {
      phone = '593${phone.substring(1)}';
    }

    final message = Uri.encodeComponent(
      'Hola ${widget.reservation.clientName}, soy el técnico asignado a su caso de ${widget.reservation.device}...',
    );

    // Using the official universal link format
    final url = Uri.parse('https://wa.me/$phone?text=$message');

    try {
      // For mobile apps, externalApplication mode is preferred for WhatsApp
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al abrir WhatsApp: $e')));
      }
    }
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
          decoration: const InputDecoration(
            labelText: 'Comentarios Técnicos',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _solutionController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Solución Aplicada',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Costo (\$)',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _partsController,
                decoration: const InputDecoration(
                  labelText: 'Repuestos',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
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
