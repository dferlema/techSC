import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/services/document_id_service.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/features/reservations/models/reservation_model.dart';

final reservationServiceProvider = Provider((ref) => ReservationService());

class ReservationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'reservations';

  Stream<List<ReservationModel>> getReservations(String userId) {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReservationModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> saveReservation(Map<String, dynamic> reservationData) async {
    final id = await DocumentIdService().generateId(prefix: 'R', useDate: true, digits: 4);
    await _db.collection(_collection).doc(id).set(reservationData);
  }
}

final myReservationsProvider = StreamProvider<List<ReservationModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return ref.watch(reservationServiceProvider).getReservations(user.uid).handleError(
    (error) => debugPrint('Stream error [myReservations]: $error'),
  );
});
