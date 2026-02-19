import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:techsc/features/reservations/models/reservation_model.dart';
import 'package:techsc/features/reservations/screens/reservation_detail_page.dart';
import 'package:techsc/features/reservations/providers/reservation_providers.dart';
import 'package:techsc/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyReservationsPage extends ConsumerWidget {
  const MyReservationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(myReservationsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/main');
            }
          },
        ),
        title: Text(
          l10n.yourReservations,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: reservationsAsync.when(
        data: (reservations) {
          if (reservations.isEmpty) {
            return _buildEmptyState(context, theme);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final reservation = reservations[index];
              return _buildReservationCard(context, reservation, theme);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 24),
          Text(
            l10n.noReservations,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.reservationEmptyDesc,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationCard(
    BuildContext context,
    ReservationModel reservation,
    ThemeData theme,
  ) {
    final DateTime createdAt = reservation.createdAt.toDate();
    final String status = reservation.status.toLowerCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ReservationDetailPage(reservation: reservation),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      reservation.serviceType,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(context, status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.laptop, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    reservation.device,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM yyyy, HH:mm').format(createdAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ID: ${reservation.id.substring(0, 8).toUpperCase()}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String label;

    switch (status) {
      case 'pendiente':
        color = Colors.orange;
        label = l10n.statusPending;
        break;
      case 'confirmado':
        color = Colors.blue;
        label = l10n.statusConfirmed;
        break;
      case 'en_proceso':
        color = Colors.purple;
        label = l10n.statusInProcess;
        break;
      case 'aprobado':
      case 'completado':
        color = Colors.green;
        label = status == 'aprobado'
            ? l10n.statusApproved
            : l10n.statusCompleted;
        break;
      case 'rechazado':
      case 'cancelado':
        color = Colors.red;
        label = status == 'rechazado'
            ? l10n.statusRejected
            : l10n.statusCancelled;
        break;
      default:
        color = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
