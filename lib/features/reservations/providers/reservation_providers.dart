import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/features/reservations/models/reservation_model.dart';

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
    await _db.collection(_collection).add(reservationData);
  }
}

final myReservationsProvider = StreamProvider<List<ReservationModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return ref.watch(reservationServiceProvider).getReservations(user.uid);
});
