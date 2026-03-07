/// Utilidades de validación específicas para Ecuador 🇪🇨.
///
/// Incluye algoritmos para validar Cédula de Identidad y Registro Único de Contribuyentes (RUC).
class EcuadorValidator {
  /// Valida una cédula de identidad ecuatoriana (10 dígitos).
  /// Basado en el algoritmo de digito verificador (coeficientes 2.1.2.1.2.1.2.1.2).
  static bool validateCedula(String cedula) {
    if (cedula.length != 10) return false;
    if (!RegExp(r'^[0-9]+$').hasMatch(cedula)) return false;

    // Primeros dos dígitos: provincia (01 a 24)
    int provincia = int.parse(cedula.substring(0, 2));
    if (provincia < 1 || provincia > 24) return false;

    // Tercer dígito: menor a 6
    int tercerDigito = int.parse(cedula.substring(2, 3));
    if (tercerDigito >= 6) return false;

    List<int> coeficientes = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    int suma = 0;

    for (int i = 0; i < coeficientes.length; i++) {
      int valor = int.parse(cedula.substring(i, i + 1)) * coeficientes[i];
      suma += (valor >= 10) ? valor - 9 : valor;
    }

    int digitoVerificador = int.parse(cedula.substring(9, 10));
    int residuo = suma % 10;
    int resultado = (residuo == 0) ? 0 : 10 - residuo;

    return resultado == digitoVerificador;
  }

  /// Valida un RUC de una persona natural o jurídica (13 dígitos).
  static bool validateRUC(String ruc) {
    if (ruc.length != 13) return false;
    if (!RegExp(r'^[0-9]+$').hasMatch(ruc)) return false;

    // Los primeros 10 dígitos deben ser una cédula válida (para personas naturales)
    // O seguir reglas específicas para personas jurídicas/públicas.
    // Simplificación: Validar prefijo de cédula + sufijo 001.
    String cedulaPart = ruc.substring(0, 10);
    String establecimiento = ruc.substring(10, 13);

    if (establecimiento == '000') return false;

    // RUC Persona Natural
    if (int.parse(cedulaPart.substring(2, 3)) < 6) {
      return validateCedula(cedulaPart) && establecimiento == '001';
    }

    // Nota: Para personas jurídicas (tercer dígito 9) y públicas (tercer dígito 6)
    // existen coeficientes distintos. Por ahora soportamos Principalmente Naturales.
    return true;
  }
}
