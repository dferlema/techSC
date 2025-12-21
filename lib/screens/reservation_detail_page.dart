import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/reservation_model.dart';
import '../services/auth_service.dart';

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
    // Basic cleaning of phone number (remove leading 0 if 10 digits, add country code)
    // Assuming Ecuador (+593) based on context (coordinates/currency implies basic integration)
    String phone = widget.reservation.clientPhone;
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    const countryCode = '593';
    final fullPhone = '$countryCode$phone';

    final message = Uri.encodeComponent(
      'Hola ${widget.reservation.clientName}, soy el técnico asignado a su caso de ${widget.reservation.device}...',
    );

    final url = Uri.parse('https://wa.me/$fullPhone?text=$message');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir WhatsApp';
      }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveTechDetails,
            tooltip: 'Guardar cambios',
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
                  _buildStatusHeader(),
                  const SizedBox(height: 20),
                  _buildClientInfoCard(),
                  const SizedBox(height: 20),
                  _buildServiceInfoCard(),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'Gestión Técnica',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildTechForm(),
                  const SizedBox(height: 30),
                  _buildActionButtons(),
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
      case 'rechazado':
        color = Colors.red;
        break;
      case 'en_proceso':
        color = Colors.purple;
        break;
      case 'completado':
        color = Colors.green;
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
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: _launchWhatsApp,
                  tooltip: 'Contactar por WhatsApp',
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
        if (_currentStatus == 'confirmado' || _currentStatus == 'en_proceso')
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
