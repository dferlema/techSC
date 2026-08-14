import 'package:flutter_test/flutter_test.dart';
import 'package:tscomputer/core/services/ai_service.dart';
import 'package:tscomputer/features/accounting/models/accounting_entry_model.dart';
import 'package:tscomputer/features/accounting/models/chart_of_account_model.dart';
import 'package:tscomputer/features/accounting/models/payroll_model.dart';
import 'package:tscomputer/features/accounting/services/accounting_calculator.dart';

/// Pruebas automatizadas del módulo contable (BLOQUE 11).
void main() {
  group('11.1 Importación de cuentas', () {
    test('El plan de cuentas se importa completo desde el Excel (248 cuentas)', () {
      final accounts = ChartOfAccountModel.defaults();
      expect(accounts.length, 248, reason: 'El plan del Excel contiene 248 cuentas');
    });

    test('Cada código de cuenta es único', () {
      final accounts = ChartOfAccountModel.defaults();
      final codes = accounts.map((a) => a.code).toSet();
      expect(codes.length, accounts.length);
    });

    test('Contiene las cuentas clave del sistema', () {
      final accounts = ChartOfAccountModel.defaults();
      final codes = accounts.map((a) => a.code).toSet();
      expect(codes, containsAll([
        '1.1.01.01', // Caja General
        '1.1.01.03', // Bancos
        '1.1.02.01', // Clientes - Facturas
        '1.1.03.02', // Inventario Partes y Piezas
        '1.1.04', // IVA Crédito
        '2.1.01.01', // Proveedores de Equipos
        '2.1.02', // IVA Débito
        '3.1.01', // Capital Social
        '4.1.01.01', // Venta Laptops
        '5.1.01', // Sueldos
        '6.1.01.01', // CMV Computadoras
      ]));
    });
  });

  group('11.2 Venta con COGS', () {
    test('Venta laptop \$1000 con costo \$700 genera los saldos correctos y cuadra', () {
      final entries = [
        _entry([
          _line('1.1.01.01', debit: 1000.0), // Caja
          _line('4.1.01.01', credit: 1000.0), // Venta Laptops
        ]),
        _entry([
          _line('6.1.01.01', debit: 700.0), // CMV Computadoras
          _line('1.1.03.02', credit: 700.0), // Inventario
        ]),
      ];

      final balances = AccountingCalculator.accountBalances(entries);
      expect(AccountingCalculator.sumByPrefix(balances, '1.1.01'), 1000.0); // Caja +$1000
      expect(AccountingCalculator.creditByPrefix(balances, '4.1'), 1000.0); // Venta +$1000
      expect(AccountingCalculator.sumByPrefix(balances, '6.1'), 700.0); // CMV +$700
      expect(AccountingCalculator.sumByPrefix(balances, '1.1.03'), -700.0); // Inv -$700

      final bs = AccountingCalculator.balanceSheet(balances);
      expect(bs['cuadra'], isTrue, reason: 'El balance debe cuadrar');
      expect(bs['diferencia'], closeTo(0, 0.001));
    });
  });

  group('11.3 Compra con IVA', () {
    test('Compra \$1150 con IVA incluido (negocio popular): Inv +1150 (IVA capitalizado), CxP +1150', () {
      final entries = [
        _entry([
          _line('1.1.03.02', debit: 1150.0), // Inventario (total con IVA)
          _line('2.1.01.01', credit: 1150.0), // Proveedores
        ]),
      ];

      final balances = AccountingCalculator.accountBalances(entries);
      expect(AccountingCalculator.sumByPrefix(balances, '1.1.03'), 1150.0);
      expect(AccountingCalculator.sumByPrefix(balances, '1.1.04'), 0.0); // Sin IVA crédito
      expect(AccountingCalculator.creditByPrefix(balances, '2.1.01'), 1150.0);

      final bs = AccountingCalculator.balanceSheet(balances);
      expect(bs['cuadra'], isTrue);
    });
  });

  group('11.4 Cobro de cliente', () {
    test('Cliente paga \$500 que debía: Caja +500, Clientes -500', () {
      final entries = [
        _entry([
          _line('1.1.01.01', debit: 500.0), // Caja
          _line('1.1.02.01', credit: 500.0), // Clientes
        ]),
      ];

      final balances = AccountingCalculator.accountBalances(entries);
      expect(AccountingCalculator.sumByPrefix(balances, '1.1.01'), 500.0);
      expect(AccountingCalculator.sumByPrefix(balances, '1.1.02'), -500.0);

      final bs = AccountingCalculator.balanceSheet(balances);
      expect(bs['cuadra'], isTrue);
    });
  });

  group('11.5 Nómina', () {
    test('Sueldo \$500: gasto +500, IESS personal 9.45% = 47.25, neto 452.75', () {
      final payroll = PayrollModel.build(
        id: 'rol1',
        employeeId: 'e1',
        employeeName: 'Juan',
        employeeIdentification: '123',
        period: '2026-01',
        baseSalary: 500.0,
      );

      expect(payroll.aportePersonal, closeTo(47.25, 0.01));
      expect(payroll.aportePatronal, closeTo(55.75, 0.01)); // 500 * 11.15%
      expect(payroll.netoPagar, closeTo(452.75, 0.01)); // 500 - 47.25
      expect(payroll.decimoTercero, closeTo(41.67, 0.01)); // 500/12
    });

    test('El asiento de rol cuadra (gasto + provisiones = pasivos)', () {
      final payroll = PayrollModel.build(
        id: 'rol2',
        employeeId: 'e2',
        employeeName: 'Ana',
        employeeIdentification: '456',
        period: '2026-01',
        baseSalary: 500.0,
      );

      final entry = _entry([
        _line('5.1.01', debit: 500.0), // Sueldos
        _line('5.1.07', debit: payroll.aportePatronal), // Aporte Patronal
        _line('5.1.04', debit: payroll.decimoTercero), // Décimo Tercero
        _line('5.1.05', debit: payroll.decimoCuarto), // Décimo Cuarto
        _line('5.1.08', debit: payroll.baseSalary / 24), // Vacaciones
        _line('2.1.04.01', credit: payroll.netoPagar), // Sueldos por Pagar
        _line('2.1.04.05', credit: payroll.aportePersonal), // IESS Personal
        _line('2.1.04.06', credit: payroll.aportePatronal), // IESS Patronal
        _line('2.1.04.02', credit: payroll.decimoTercero), // Décimo 3ro por Pagar
        _line('2.1.04.03', credit: payroll.decimoCuarto), // Décimo 4to por Pagar
        _line('2.1.04.07', credit: payroll.baseSalary / 24), // Vacaciones por Pagar
      ]);

      expect(entry.isBalanced, isTrue);
      expect(entry.totalDebit, closeTo(entry.totalCredit, 0.001));
    });
  });

  group('11.6 Balance General', () {
    test('Con todas las operaciones anteriores el balance cuadra', () {
      final payroll = PayrollModel.build(
        id: 'rol3',
        employeeId: 'e3',
        employeeName: 'Luis',
        employeeIdentification: '789',
        period: '2026-01',
        baseSalary: 500.0,
      );

      final entries = [
        // Apertura: Capital \$3000
        _entry([
          _line('1.1.01.01', debit: 1500.0), // Caja
          _line('1.1.01.03', debit: 1500.0), // Bancos
          _line('3.1.01', credit: 3000.0), // Capital Social
        ]),
        // Venta laptop \$1000, costo \$700
        _entry([
          _line('1.1.01.01', debit: 1000.0),
          _line('4.1.01.01', credit: 1000.0),
        ]),
        _entry([
          _line('6.1.01.01', debit: 700.0),
          _line('1.1.03.02', credit: 700.0),
        ]),
        // Compra \$1150 con IVA (negocio popular: IVA capitalizado al inventario)
        _entry([
          _line('1.1.03.02', debit: 1150.0),
          _line('2.1.01.01', credit: 1150.0),
        ]),
        // Cobro \$500
        _entry([
          _line('1.1.01.01', debit: 500.0),
          _line('1.1.02.01', credit: 500.0),
        ]),
        // Nómina
        _entry([
          _line('5.1.01', debit: 500.0),
          _line('5.1.07', debit: payroll.aportePatronal),
          _line('5.1.04', debit: payroll.decimoTercero),
          _line('5.1.05', debit: payroll.decimoCuarto),
          _line('5.1.08', debit: payroll.baseSalary / 24),
          _line('2.1.04.01', credit: payroll.netoPagar),
          _line('2.1.04.05', credit: payroll.aportePersonal),
          _line('2.1.04.06', credit: payroll.aportePatronal),
          _line('2.1.04.02', credit: payroll.decimoTercero),
          _line('2.1.04.03', credit: payroll.decimoCuarto),
          _line('2.1.04.07', credit: payroll.baseSalary / 24),
        ]),
      ];

      final balances = AccountingCalculator.accountBalances(entries);
      final bs = AccountingCalculator.balanceSheet(balances);

      expect(bs['cuadra'], isTrue);
      expect(bs['diferencia'], closeTo(0, 0.001));

      // Verificaciones de montos clave
      expect(bs['activo'], greaterThan(0));
      expect(bs['patrimonio'], greaterThan(0));
    });

    test('Un asiento desbalanceado reporta que el balance NO cuadra', () {
      final entries = [
        _entry([
          _line('1.1.01.01', debit: 1000.0),
          _line('4.1.01.01', credit: 900.0), // Desbalance: falta crédito
        ]),
      ];
      final balances = AccountingCalculator.accountBalances(entries);
      final bs = AccountingCalculator.balanceSheet(balances);
      expect(bs['cuadra'], isFalse);
      expect(bs['diferencia'], isNot(closeTo(0, 0.001)));
    });
  });

  group('11.5 Desglose por cuenta (hojas)', () {
    test('leafAccounts solo lista cuentas sin subcuentas', () {
      final balances = {
        '1.1.01.01': 100.0, // hoja
        '1.1.01': 100.0, // padre (debe excluirse)
        '1.1': 100.0, // padre (debe excluirse)
        '1.2': 0.0, // saldo nulo → excluido
        '2.1.01.01': -50.0, // hoja
      };
      final leaves = AccountingCalculator.leafAccounts(balances, '1');
      expect(leaves.length, 1);
      expect(leaves.first['code'], '1.1.01.01');
      expect(leaves.first['balance'], 100.0);
    });
  });

  group('11.6 Análisis IA de ventas', () {
    test('Detecta producto en pérdida y margen bajo', () {
      final insights = AiService().analyzeSales([
        {
          'name': 'Laptop X', 'revenue': 1000.0, 'profit': 100.0,
          'marginPct': 10.0, 'unitsSold': 2, 'stock': 5, 'orderCount': 1, 'categoryName': 'Equipos',
        },
        {
          'name': 'Mouse Y', 'revenue': 500.0, 'profit': -20.0,
          'marginPct': -4.0, 'unitsSold': 4, 'stock': 1, 'orderCount': 2, 'categoryName': 'Accesorios',
        },
      ]);

      expect(insights.any((i) => i.type == 'alerta' && i.title.contains('pérdida')), isTrue,
          reason: 'Debe alertar sobre el producto con pérdida');
      expect(insights.any((i) => i.title.contains('Margen bajo')), isTrue);
      expect(insights.any((i) => i.title.contains('agotar stock')), isTrue,
          reason: 'Mouse Y tiene alta demanda y stock crítico');
    });

    test('No genera insights cuando no hay datos', () {
      expect(AiService().analyzeSales([]), isEmpty);
    });
  });
}

AccountingEntryLine _line(String code, {double debit = 0.0, double credit = 0.0}) {
  return AccountingEntryLine(
    accountId: code,
    accountCode: code,
    accountName: code,
    debit: debit,
    credit: credit,
  );
}

AccountingEntryModel _entry(List<AccountingEntryLine> lines) {
  return AccountingEntryModel(
    id: 'entry_${lines.hashCode}',
    number: 'AS-0001',
    date: DateTime(2026, 1, 15),
    description: 'Asiento de prueba',
    lines: lines,
    status: EntryStatus.contabilizado,
  );
}
