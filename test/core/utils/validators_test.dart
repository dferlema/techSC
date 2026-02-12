import 'package:flutter_test/flutter_test.dart';
import 'package:techsc/core/utils/validators.dart';

void main() {
  group('Validators - Ecuador ID', () {
    test('Valid Cédula', () {
      expect(Validators.isValidEcuadorianId('1710034065'), isTrue);
      expect(
        Validators.isValidEcuadorianId('0923456782'),
        isFalse,
      ); // Actually this one was a guess
      // Another valid one: 1724456783
      expect(Validators.isValidEcuadorianId('1724456783'), isTrue);
    });

    test('Invalid Cédula', () {
      expect(
        Validators.isValidEcuadorianId('1724456789'),
        isFalse,
      ); // Incorrect verifier (should be 3)
      expect(Validators.isValidEcuadorianId('123'), isFalse); // Too short
      expect(
        Validators.isValidEcuadorianId('abcdefghij'),
        isFalse,
      ); // Not digits
    });

    test('Valid RUC Persona Natural', () {
      expect(Validators.isValidEcuadorianId('1710034065001'), isTrue);
    });

    test('Valid RUC Sociedad Privada', () {
      // 1790011674001 is a common example for tests (SRI)
      expect(Validators.isValidEcuadorianId('1790011674001'), isTrue);
    });

    test('Invalid RUC', () {
      expect(
        Validators.isValidEcuadorianId('1790011674000'),
        isFalse,
      ); // No establishment
    });
  });

  group('Validators - Ecuador Phone', () {
    test('Valid Phone', () {
      expect(Validators.isValidEcuadorianPhone('0999999999'), isTrue);
      expect(Validators.isValidEcuadorianPhone('0912345678'), isTrue);
    });

    test('Invalid Phone', () {
      expect(
        Validators.isValidEcuadorianPhone('0899999999'),
        isFalse,
      ); // Not 09
      expect(
        Validators.isValidEcuadorianPhone('099999999'),
        isFalse,
      ); // Too short
      expect(
        Validators.isValidEcuadorianPhone('1999999999'),
        isFalse,
      ); // Not starting with 0
      expect(
        Validators.isValidEcuadorianPhone('099999999a'),
        isFalse,
      ); // Not digits
    });
  });
}
