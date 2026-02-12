import 'package:flutter_test/flutter_test.dart';
import 'package:techsc/core/services/role_service.dart';

void main() {
  group('RoleService - Static helper methods', () {
    test('getRoleName returns localized names', () {
      expect(RoleService.getRoleName(RoleService.ADMIN), 'Administrador');
      expect(RoleService.getRoleName(RoleService.SELLER), 'Vendedor');
      expect(RoleService.getRoleName(RoleService.TECHNICIAN), 'Técnico');
      expect(RoleService.getRoleName(RoleService.CLIENT), 'Cliente');
      expect(RoleService.getRoleName('unknown'), 'Cliente');
    });

    test('getRoleIcon returns correct emoji', () {
      expect(RoleService.getRoleIcon(RoleService.ADMIN), '👑');
      expect(RoleService.getRoleIcon(RoleService.CLIENT), '👤');
    });

    test('getRoleDescription returns correct text', () {
      expect(
        RoleService.getRoleDescription(RoleService.ADMIN),
        contains('Acceso completo'),
      );
    });
  });
}
