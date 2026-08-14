import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/features/accounting/models/accounting_entry_model.dart';
import 'package:tscomputer/features/accounting/models/chart_of_account_model.dart';

class ChartOfAccountsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'chart_of_accounts';

  Future<void> saveAccount(ChartOfAccountModel account) async {
    try {
      // Si no trae ID, generar uno legible: A-1.1.01.01, P-2.1.01.01, etc.
      final id = account.id.isNotEmpty
          ? account.id
          : ChartOfAccountModel.buildId(account.type, account.code);
      final accountWithId = account.copyWith(id: id);
      await _firestore.collection(_collection).doc(id).set(accountWithId.toMap());
    } catch (e) {
      debugPrint('Error al guardar cuenta: $e');
      rethrow;
    }
  }

  Future<void> deleteAccount(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Stream<List<ChartOfAccountModel>> getAccountsStream() {
    return _firestore.collection(_collection).orderBy('code').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ChartOfAccountModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<List<ChartOfAccountModel>> getAccounts() async {
    final snapshot = await _firestore.collection(_collection).orderBy('code').get();
    return snapshot.docs.map((doc) => ChartOfAccountModel.fromMap(doc.data(), doc.id)).toList();
  }

  /// Verifica si un ID es legible (formato A-1.1.01.01, P-2.1.01.01, etc.)
  bool _isLegibleId(String id) {
    return id.startsWith('A-') ||
        id.startsWith('P-') ||
        id.startsWith('PAT-') ||
        id.startsWith('I-') ||
        id.startsWith('G-') ||
        id.startsWith('C-');
  }

  /// Regenera el plan de cuentas: elimina las cuentas existentes (incluidas
  /// las que tienen IDs aleatorios de Firestore) y vuelve a sembrar todo con
  /// la nueva nomenclatura legible.
  Future<void> regenerate() async {
    final snapshot = await _firestore.collection(_collection).get();
    for (final doc in snapshot.docs) {
      await _firestore.collection(_collection).doc(doc.id).delete();
    }
    for (final account in ChartOfAccountModel.defaults()) {
      await saveAccount(account);
    }
    debugPrint('✅ Plan de cuentas regenerado con nomenclatura legible (${ChartOfAccountModel.defaults().length} cuentas)');
  }

  Future<void> seedDefaults() async {
    // 1. Obtener cuentas existentes agrupadas por código
    final existing = await _firestore.collection(_collection).get();
    final existingCodes = existing.docs.map((d) => (d.data()['code'] as String?) ?? '').toSet();

    // 2. Si ya existen cuentas con IDs aleatorios (nomenclatura vieja),
    //    regenerar todo con los IDs legibles.
    if (existing.docs.isNotEmpty && existing.docs.any((d) => !_isLegibleId(d.id))) {
      debugPrint('🔁 Detectada nomenclatura vieja en el plan de cuentas. Regenerando...');
      await regenerate();
      return;
    }

    // 3. Si no hay nada, sembrar todo
    if (existingCodes.isEmpty) {
      for (final account in ChartOfAccountModel.defaults()) {
        await saveAccount(account);
      }
      debugPrint('✅ Plan de cuentas completo sembrado (${ChartOfAccountModel.defaults().length} cuentas)');
      return;
    }

    // 4. Si ya hay cuentas, agregar solo las nuevas faltantes
    final defaults = ChartOfAccountModel.defaults();
    int added = 0;
    for (final account in defaults) {
      if (!existingCodes.contains(account.code)) {
        await saveAccount(account);
        added++;
      }
    }
    if (added > 0) {
      debugPrint('✅ $added cuenta(s) nueva(s) agregada(s) al plan de cuentas existente');
    } else {
      debugPrint('ℹ️ Plan de cuentas ya está actualizado');
    }
  }

  Future<void> updateBalance(String accountId, double amountChange) async {
    await _firestore.collection(_collection).doc(accountId).update({
      'balance': FieldValue.increment(amountChange),
    });
  }

  Future<double> getAccountBalance(String accountId) async {
    final doc = await _firestore.collection(_collection).doc(accountId).get();
    if (!doc.exists) return 0.0;
    return (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
  }

  Stream<List<ChartOfAccountModel>> getAccountsByTypeStream(AccountType type) {
    return _firestore.collection(_collection).where('type', isEqualTo: type.name).orderBy('code').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ChartOfAccountModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Recalcula todos los saldos del plan de cuentas desde cero,
  /// leyendo todos los asientos contabilizados.
  ///
  /// Corrige el bug de convención de signos invertida que existía antes.
  /// Retorna mapa accountId → saldo correcto.
  Future<Map<String, double>> recalculateAllBalances() async {
    debugPrint('🔄 Recalculando todos los saldos del plan de cuentas...');

    // 1. Cargar plan de cuentas
    final coaSnapshot = await _firestore.collection(_collection).get();
    final accountMap = <String, ChartOfAccountModel>{};
    for (final doc in coaSnapshot.docs) {
      final acc = ChartOfAccountModel.fromMap(doc.data(), doc.id);
      accountMap[acc.code] = acc;
    }

    // 2. Cargar todos los asientos contabilizados
    final entriesSnapshot = await _firestore
        .collection('accounting_entries')
        .where('status', isEqualTo: EntryStatus.contabilizado.name)
        .get();

    debugPrint('   📄 ${entriesSnapshot.docs.length} asientos contabilizados encontrados');

    // 3. Acumular cambios de saldo por cuenta
    final balanceChanges = <String, double>{};

    for (final doc in entriesSnapshot.docs) {
      final entry = AccountingEntryModel.fromMap(doc.data(), doc.id);
      for (final line in entry.lines) {
        final accountCode = line.accountCode;
        final acc = accountMap[accountCode];
        if (acc == null) {
          debugPrint('   ⚠️ Cuenta $accountCode no encontrada en plan de cuentas');
          continue;
        }

        // Calcular cambio correcto según naturaleza
        final change = _balanceChangeForLine(line, acc.nature.name);
        if (change == 0) continue;

        final key = acc.id;
        balanceChanges[key] = (balanceChanges[key] ?? 0) + change;
      }
    }

    debugPrint('   📊 ${balanceChanges.length} cuentas con movimientos');

    // 4. Actualizar saldos en batch
    final batch = _firestore.batch();
    for (final entry in balanceChanges.entries) {
      final accountRef = _firestore.collection(_collection).doc(entry.key);
      batch.update(accountRef, {'balance': entry.value});
    }

    // También poner en 0 las cuentas que no tienen movimientos
    for (final acc in accountMap.values) {
      if (!balanceChanges.containsKey(acc.id) && acc.balance != 0) {
        final accountRef = _firestore.collection(_collection).doc(acc.id);
        batch.update(accountRef, {'balance': 0});
        balanceChanges[acc.id] = 0;
      }
    }

    await batch.commit();

    debugPrint('✅ Saldos recalculados correctamente (${balanceChanges.length} cuentas)');
    return balanceChanges;
  }

  /// Calcula el cambio de saldo para una línea según naturaleza de cuenta.
  /// Misma lógica que JournalEntryService._balanceChange.
  static double _balanceChangeForLine(AccountingEntryLine line, String nature) {
    final isDeudora = nature == 'deudora';
    if (isDeudora) {
      return line.debit - line.credit;
    } else {
      return line.credit - line.debit;
    }
  }
}
