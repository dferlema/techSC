class Validators {
  /// Valida si una cadena es una cédula (10 dígitos) o RUC (13 dígitos) ecuatoriano válido.
  static bool isValidEcuadorianId(String id) {
    if (id.isEmpty) return false;

    // Verificar longitud (10 para cédula, 13 para RUC)
    if (id.length != 10 && id.length != 13) return false;

    // Verificar que solo contenga dígitos
    if (!RegExp(r'^\d+$').hasMatch(id)) return false;

    // Los primeros 2 dígitos corresponden a la provincia (01-24) o 30
    final provinceCode = int.tryParse(id.substring(0, 2));
    if (provinceCode == null ||
        ((provinceCode < 1 || provinceCode > 24) && provinceCode != 30)) {
      return false;
    }

    // El tercer dígito es el tipo de identificación
    final thirdDigit = int.parse(id[2]);

    if (thirdDigit < 6) {
      // Cédula o RUC Personas Naturales
      return _validateCedula(id.substring(0, 10));
    } else if (thirdDigit == 6) {
      // RUC Sociedades Públicas
      return _validateRucPublic(id);
    } else if (thirdDigit == 9) {
      // RUC Sociedades Privadas
      return _validateRucPrivate(id);
    }

    return false;
  }

  /// Valida Cédula o RUC de Personas Naturales (Módulo 10)
  static bool _validateCedula(String id) {
    final digits = id.split('').map(int.parse).toList();
    int sum = 0;

    for (int i = 0; i < 9; i++) {
      int digit = digits[i];
      if (i % 2 == 0) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }

    final verifier = (sum % 10 == 0) ? 0 : 10 - (sum % 10);
    return verifier == digits[9];
  }

  /// Valida RUC Sociedades Públicas (Módulo 11)
  static bool _validateRucPublic(String id) {
    if (id.length != 13) return false;
    // RUC Público termina en 0001 (generalmente, pero validaremos los primeros 9 + verificador)
    // El dígito verificador es el 4to dígito (índice 3)
    // Los coeficientes son 3, 2, 7, 6, 5, 4, 3, 2

    final digits = id.split('').map(int.parse).toList();
    if (digits[9] != 0 ||
        digits[10] != 0 ||
        digits[11] != 0 ||
        digits[12] != 1) {
      // Aunque la norma dice que termina en 001, a veces varia el establecimiento
      // Pero validemos al menos que tenga establecimiento
      if (id.substring(9) == '0000') return false;
    }

    final coefficients = [3, 2, 7, 6, 5, 4, 3, 2];
    int sum = 0;

    for (int i = 0; i < 8; i++) {
      sum += digits[i] * coefficients[i];
    }

    final remainder = sum % 11;
    final verifier = (remainder == 0) ? 0 : 11 - remainder;

    return verifier == digits[3];
  }

  /// Valida RUC Sociedades Privadas (Módulo 11)
  static bool _validateRucPrivate(String id) {
    if (id.length != 13) return false;
    // El dígito verificador es el 10mo dígito (índice 9)
    // Los coeficientes son 4, 3, 2, 7, 6, 5, 4, 3, 2

    // Validar que tenga establecimiento
    if (id.substring(10) == '000') return false;

    final digits = id.split('').map(int.parse).toList();
    final coefficients = [4, 3, 2, 7, 6, 5, 4, 3, 2];
    int sum = 0;

    for (int i = 0; i < 9; i++) {
      sum += digits[i] * coefficients[i];
    }

    final remainder = sum % 11;
    final verifier = (remainder == 0) ? 0 : 11 - remainder;

    return verifier == digits[9];
  }

  /// Valida número de celular ecuatoriano
  static bool isValidEcuadorianPhone(String phone) {
    if (phone.isEmpty) return false;
    // Debe empezar con 09 y tener 10 dígitos
    return phone.length == 10 &&
        phone.startsWith('09') &&
        RegExp(r'^\d{10}$').hasMatch(phone);
  }
}
