import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Genera identificadores secuenciales y legibles para documentos,
/// usando un contador atómico en Firestore (colección `_counters`).
///
/// Ejemplos de salida:
/// - `Q-20260813-001`  (con `useDate: true`, prefijo 'Q')
/// - `ord-001`         (con `useDate: false`)
class DocumentIdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Genera el siguiente ID para un prefijo dado.
  ///
  /// [prefix]   identificador base del documento (p. ej. 'Q', 'ord').
  /// [useDate]  si es `true`, incluye la fecha `yyyyMMdd` en el ID y el
  ///            contador se reinicia cada día (la clave del contador
  ///            incorpora la fecha).
  /// [digits]   cantidad de dígitos del contador (con ceros a la izquierda).
  Future<String> generateId({
    required String prefix,
    bool useDate = false,
    int digits = 3,
  }) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);

    // Clave del contador: con fecha => contador diario; sin fecha => contador global.
    final counterKey = useDate ? '${prefix}_$dateStr' : prefix;

    final ref = _firestore.collection('_counters').doc(counterKey);

    // Transacción atómica: lee el contador, lo incrementa y lo persiste.
    // Firestore garantiza que dos llamadas simultáneas no obtengan el mismo número.
    final result = await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      final current = (doc.data()?['current'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      transaction.set(ref, {'current': next, 'updatedAt': FieldValue.serverTimestamp()});
      return next;
    });

    final seq = result.toString().padLeft(digits, '0');

    if (useDate) {
      return '$prefix-$dateStr-$seq';
    }
    return '$prefix-$seq';
  }
}