import 'package:tscomputer/features/accounting/models/accounting_entry_model.dart';

/// Calculador contable puro (sin dependencias de Firestore).
///
/// Permite calcular saldos por cuenta, estados financieros y verificar que el
/// balance cuadre a partir de una lista de asientos. Se usa tanto en el
/// servicio de reportes como en los tests automatizados (BLOQUE 11).
class AccountingCalculator {
  /// Balance de comprobación por código de cuenta.
  /// saldo = Σ débitos - Σ créditos de los asientos contabilizados.
  static Map<String, double> accountBalances(List<AccountingEntryModel> entries) {
    final balances = <String, double>{};
    for (final entry in entries) {
      for (final line in entry.lines) {
        balances[line.accountCode] = (balances[line.accountCode] ?? 0.0) + line.debit - line.credit;
      }
    }
    return balances;
  }

  /// Suma de saldos netos de todas las cuentas cuyo código comienza con [prefix].
  static double sumByPrefix(Map<String, double> balances, String prefix) {
    return balances.entries
        .where((e) => e.key == prefix || e.key.startsWith('$prefix.'))
        .fold(0.0, (sum, e) => sum + e.value);
  }

  /// Saldo acreedor neto de un grupo (créditos menos débitos).
  static double creditByPrefix(Map<String, double> balances, String prefix) {
    return -sumByPrefix(balances, prefix);
  }

  /// Cuentas "hoja" (sin subcuentas) bajo [prefix] con saldo no nulo, ordenadas por código.
  /// Cada elemento: {code, balance}. Útil para desglosar estados financieros por cuenta.
  static List<Map<String, dynamic>> leafAccounts(Map<String, double> balances, String prefix) {
    final codes = balances.keys
        .where((k) => k == prefix || k.startsWith('$prefix.'))
        .where((k) => !balances.keys.any((other) => other != k && other.startsWith('$k.')))
        .toList()
      ..sort();
    return codes
        .map((k) => {'code': k, 'balance': balances[k]!})
        .where((e) => (e['balance'] as double).abs() > 0.004)
        .toList();
  }

  /// Balance General al cierre [asOf] a partir de asientos del año.
  static Map<String, dynamic> balanceSheet(Map<String, double> balances) {
    // Presentación (clamped para no mostrar activos/pasivos negativos)
    final efectivo = sumByPrefix(balances, '1.1.01').clamp(0.0, double.infinity);
    final cuentasPorCobrar = sumByPrefix(balances, '1.1.02').clamp(0.0, double.infinity);
    final inventario = sumByPrefix(balances, '1.1.03').clamp(0.0, double.infinity);
    final otrosActivos = sumByPrefix(balances, '1.1.04') +
        sumByPrefix(balances, '1.1.05') +
        sumByPrefix(balances, '1.2');
    final activo = efectivo + cuentasPorCobrar + inventario + otrosActivos;

    final cuentasPorPagar = creditByPrefix(balances, '2.1.01').clamp(0.0, double.infinity);
    final ivaCredito = sumByPrefix(balances, '1.1.04');
    final ivaDebito = creditByPrefix(balances, '2.1.02');
    final ivaPorPagar = (ivaDebito - ivaCredito).clamp(0.0, double.infinity);
    final otrosPasivos = creditByPrefix(balances, '2.1.03') +
        creditByPrefix(balances, '2.1.04') +
        creditByPrefix(balances, '2.1.05') +
        creditByPrefix(balances, '2.1.06') +
        creditByPrefix(balances, '2.1.07') +
        creditByPrefix(balances, '2.2');
    final pasivo = cuentasPorPagar + ivaPorPagar + otrosPasivos;

    final ingresos = creditByPrefix(balances, '4').clamp(0.0, double.infinity);
    final gastos = sumByPrefix(balances, '5').clamp(0.0, double.infinity) +
        sumByPrefix(balances, '6').clamp(0.0, double.infinity);
    final utilidad = ingresos - gastos;
    final capital = creditByPrefix(balances, '3').clamp(0.0, double.infinity);
    final patrimonio = capital + utilidad;

    // Verificación contable con valores BRUTOS (sin clamp):
    //   Activo = Pasivo + Patrimonio  ⇔  Σ(1)+Σ(2)+Σ(3)+Σ(4)+Σ(5)+Σ(6) = 0
    final activoBruto = sumByPrefix(balances, '1');
    final pasivoBruto = creditByPrefix(balances, '2');
    final patrimonioBruto = creditByPrefix(balances, '3') +
        creditByPrefix(balances, '4') -
        sumByPrefix(balances, '5') -
        sumByPrefix(balances, '6');
    final diferencia = activoBruto - (pasivoBruto + patrimonioBruto);
    final cuadra = diferencia.abs() < 0.01;

    return {
      'efectivo': efectivo,
      'cuentasPorCobrar': cuentasPorCobrar,
      'inventario': inventario,
      'otrosActivos': otrosActivos,
      'activo': activo,
      'cuentasPorPagar': cuentasPorPagar,
      'ivaPorPagar': ivaPorPagar,
      'otrosPasivos': otrosPasivos,
      'pasivo': pasivo,
      'capital': capital,
      'patrimonio': patrimonio,
      'utilidad': utilidad,
      'ingresos': ingresos,
      'gastos': gastos,
      'diferencia': diferencia,
      'cuadra': cuadra,
    };
  }

  /// Estado de Resultados para el rango [start, end].
  static Map<String, dynamic> incomeStatement(Map<String, double> balances) {
    final ingresosVentas = creditByPrefix(balances, '4.1').clamp(0.0, double.infinity);
    final ingresosServicios = creditByPrefix(balances, '4.2').clamp(0.0, double.infinity);
    final ingresosOtros = creditByPrefix(balances, '4.3').clamp(0.0, double.infinity);
    final totalIngresos = ingresosVentas + ingresosServicios + ingresosOtros;

    final gastosCogs = sumByPrefix(balances, '6').clamp(0.0, double.infinity);
    final gastosPersonal = sumByPrefix(balances, '5.1').clamp(0.0, double.infinity);
    final gastosOperativos = sumByPrefix(balances, '5.2').clamp(0.0, double.infinity);
    final otrosGastos = sumByPrefix(balances, '5.3') +
        sumByPrefix(balances, '5.4') +
        sumByPrefix(balances, '5.5') +
        sumByPrefix(balances, '5.6') +
        sumByPrefix(balances, '5.7') +
        sumByPrefix(balances, '5.8') +
        sumByPrefix(balances, '5.9');
    final totalGastos = gastosCogs + gastosPersonal + gastosOperativos + otrosGastos;
    final utilidad = totalIngresos - totalGastos;

    return {
      'ingresosVentas': ingresosVentas,
      'ingresosServicios': ingresosServicios,
      'ingresosOtros': ingresosOtros,
      'totalIngresos': totalIngresos,
      'gastosCogs': gastosCogs,
      'gastosPersonal': gastosPersonal,
      'gastosOperativos': gastosOperativos,
      'gastosAdmin': otrosGastos,
      'totalGastos': totalGastos,
      'utilidad': utilidad,
    };
  }
}
