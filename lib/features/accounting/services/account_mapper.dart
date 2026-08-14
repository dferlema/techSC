import 'package:tscomputer/features/accounting/models/transaction_model.dart';

/// Mapeo de categorías y códigos de inventario a cuentas del plan contable.
///
/// Centraliza las reglas usadas por los flujos de gastos, compras de inventario
/// y costos de venta (COGS) para que no haya dos criterios distintos.
class AccountMapper {
  AccountMapper._();

  /// Cuenta de gasto según la categoría (egreso manual / factura de gasto).
  static String expenseAccountForCategory(String category, {TransactionType? type}) {
    if (type == TransactionType.ingreso) {
      switch (category) {
        case 'Venta Manual':
          return '4.1';
        case 'Servicio Técnico':
          return '4.2';
        case 'Venta de Activos':
          return '4.3.04';
        case 'Alquiler de Equipos':
          return '4.3.03';
        case 'Ajuste de Saldo':
          return '4.3.06';
        default:
          return '4.3.06';
      }
    }
    switch (category) {
      case 'Arriendo':
        return '5.2.01.01';
      case 'Sueldos':
        return '5.1.01';
      case 'Suministros':
      case 'Material de Oficina':
        return '5.2.03.01';
      case 'Servicios Básicos':
        return '5.2.02';
      case 'Electricidad':
        return '5.2.02.01';
      case 'Agua':
        return '5.2.02.02';
      case 'Teléfono/Internet':
        return '5.2.02.03';
      case 'Combustible':
        return '5.3.01';
      case 'Marketing':
      case 'Publicidad':
        return '5.4.01';
      case 'Comisiones':
        return '5.4.04';
      case 'Honorarios':
        return '5.8.01';
      case 'Gasto General':
      case 'Otros':
        return '5.9.06';
      default:
        return '5.9.06';
    }
  }

  /// Subcuenta de proveedor (2.1.01.xx) según la cuenta de inventario.
  static String supplierAccountFor(String inventoryAccountCode) {
    switch (inventoryAccountCode) {
      case '1.1.03.01':
        return '2.1.01.01';
      case '1.1.03.02':
        return '2.1.01.02';
      case '1.1.03.03':
        return '2.1.01.03';
      case '1.1.03.04':
        return '2.1.01.04';
      case '1.1.03.05':
        return '2.1.01.05';
      default:
        return '2.1.01.06';
    }
  }

  /// Cuenta de costo de venta (grupo 6) según la cuenta de inventario.
  static String cogsAccountFor(String inventoryAccountCode) {
    switch (inventoryAccountCode) {
      case '1.1.03.01':
        return '6.1.01.01';
      case '1.1.03.02':
        return '6.1.02.01';
      case '1.1.03.03':
        return '6.1.04';
      case '1.1.03.04':
        return '6.1.03.01';
      case '1.1.03.05':
        return '6.2.03';
      default:
        return '6.1.02.01';
    }
  }

  /// Cuenta de inventario (1.1.03.xx) según el nombre del producto.
  ///
  /// Unificada entre flujos de pedidos y reservaciones para garantizar
  /// consistencia en el mapeo de COGS.
  static String inventoryAccountForProduct(String productName) {
    final n = productName.toLowerCase();
    if (n.contains('laptop') || n.contains('portatil') || n.contains('notebook') ||
        n.contains('servidor') || n.contains('macbook') || n.contains('mac')) {
      return '1.1.03.01'; // Inventario de Equipos
    }
    if (n.contains('memoria') || n.contains('ram') || n.contains('disco') ||
        n.contains('procesador') || n.contains('parte') || n.contains('repar')) {
      return '1.1.03.02'; // Inventario de Partes y Piezas
    }
    if (n.contains('mouse') || n.contains('teclado') || n.contains('monitor') ||
        n.contains('periferico') || n.contains('accesorio') || n.contains('cable') ||
        n.contains('cargador')) {
      return '1.1.03.03'; // Inventario de Accesorios
    }
    if (n.contains('licencia') || n.contains('software') || n.contains('antivirus')) {
      return '1.1.03.04'; // Inventario de Software y Licencias
    }
    return '1.1.03.05'; // Insumos Técnicos (default para servicio técnico)
  }

  /// Cuenta de inventario (1.1.03.xx) según la categoría del producto.
  ///
  /// Prioriza la categoría real del catálogo sobre el matching por nombre.
  /// Si la categoría no matchea ninguna, retorna null para que se use
  /// el fallback por nombre.
  static String? inventoryAccountForCategory(String categoryName) {
    final c = categoryName.toLowerCase().trim();
    if (c.isEmpty) return null;
    // Equipos
    if (c.contains('equipo') || c.contains('laptop') || c.contains('computadora') ||
        c.contains('computador') || c.contains('servidor') || c.contains('impresora') ||
        c.contains('monitor')) {
      return '1.1.03.01';
    }
    // Partes y piezas
    if (c.contains('parte') || c.contains('pieza') || c.contains('componente') ||
        c.contains('repuesto') || c.contains('interno') || c.contains('memoria') ||
        c.contains('disco') || c.contains('procesador') || c.contains('placa') ||
        c.contains('tarjeta') || c.contains('pantalla') || c.contains('bateria') ||
        c.contains('carga')) {
      return '1.1.03.02';
    }
    // Accesorios
    if (c.contains('accesorio') || c.contains('periferico') || c.contains('cable') ||
        c.contains('cargador') || c.contains('mouse') || c.contains('teclado') ||
        c.contains('funda') || c.contains('soporte') || c.contains('adaptador') ||
        c.contains('hub') || c.contains('dock')) {
      return '1.1.03.03';
    }
    // Software y licencias
    if (c.contains('licencia') || c.contains('software') || c.contains('antivirus') ||
        c.contains('suscripcion') || c.contains('programa')) {
      return '1.1.03.04';
    }
    // Insumos
    if (c.contains('insumo') || c.contains('consumible') || c.contains('herramienta') ||
        c.contains('material') || c.contains('suministro')) {
      return '1.1.03.05';
    }
    return null; // No matchea — usar fallback por nombre
  }

  /// Cuenta de ingreso por servicio técnico (4.2.xx) según el tipo de servicio.
  ///
  /// Unificada entre flujos de pedidos y reservaciones.
  static String serviceIncomeAccount(String serviceType) {
    final s = serviceType.toLowerCase();
    if (s.contains('impresora')) return '4.2.01.03'; // Reparación de Impresoras
    if (s.contains('repar') || s.contains('laptop') || s.contains('computador') || s.contains('pc')) {
      return '4.2.01.01'; // Reparación de Laptops
    }
    if (s.contains('mantenimiento')) return '4.2.02.01'; // Mantenimiento de Equipos
    if (s.contains('instalac')) return '4.2.03.01'; // Instalación SO
    if (s.contains('configur') || s.contains('red')) return '4.2.03.03'; // Configuración de Redes
    if (s.contains('soporte')) return '4.2.04.01'; // Soporte Remoto
    if (s.contains('recuper')) return '4.2.05.01'; // Recuperación de Discos
    return '4.2.01.04'; // Reparación de Otros Equipos (default)
  }

  /// Cuenta de ingreso por venta de producto (4.1.xx) según el nombre del item.
  static String productIncomeAccount(String itemName) {
    final n = itemName.toLowerCase();
    if (n.contains('laptop') || n.contains('portatil') || n.contains('notebook') || n.contains('macbook') || n.contains('mac')) return '4.1.01.01';
    if (n.contains('servidor')) return '4.1.01.02';
    if (n.contains('memoria') || n.contains('ram') || n.contains('disco') || n.contains('procesador')) return '4.1.02.01';
    if (n.contains('mouse') || n.contains('teclado') || n.contains('monitor') || n.contains('periferico')) return '4.1.02.02';
    if (n.contains('licencia') || n.contains('software') || n.contains('antivirus')) return '4.1.03.01';
    return '4.1.01.03'; // Venta de Otros Equipos (default)
  }

  /// Cuenta de efectivo/bancos según método de pago.
  static String cashAccountForMethod(String method) {
    switch (method) {
      case 'efectivo': return '1.1.01.01';
      case 'transferencia': return '1.1.01.03';
      case 'tarjeta': return '1.1.01.03';
      case 'payphone': return '1.1.01.03';
      case 'credito': return '1.1.02.01';
      default: return '1.1.01.01';
    }
  }
}
