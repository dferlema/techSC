# Cotizaciones — Rediseño UI/UX Moderno y Responsive

## Estado
✅ Completo. Todos los cambios pasan `flutter analyze` con 0 errores y 0 warnings.

---

## Cambios: `lib/features/orders/screens/quote_list_page.dart`

### UI Moderna
- AppBar con icono de sección y drag handle visual
- **Modo desktop**: Grid responsive de cards (2-3 columnas según ancho)
- **Modo mobile**: Lista compacta con cards
- **Filtros por estado**: Chips de ChoiceChip con colores semáforicos (Borrador, Enviado, Aprobado, Rechazado, Convertido)
- **Búsqueda en vivo**: TextField en AppBar que filtra por nombre cliente o ID
- **Empty states** contextuales: mensajes diferentes para "sin búsqueda", "sin resultados", "sin items en filtro"
- Cards mejoradas: thumbnails apilados de items, badge de estado colorido, indicador de expiración
- Pull-to-refresh

### Responsive
- `LayoutBuilder` detecta desktop vs mobile
- Grid adaptativo: 3 cols >1400px, 2 cols 720-1400px
- Mobile: lista full-width con horizontal scroll de thumbnails

---

## Cambios: `lib/features/orders/screens/create_quote_page.dart`

### UI Moderna
- AppBar con iconos de acción (PDF preview, save) con fondo semi-transparente
- **Cards elevation=0** con sombra suave para cada sección:
  1. **Datos del Cliente** — con avatar icon, "Buscar Cliente" button
  2. **Forma de Pago** — SegmentedButton con iconos (Efectivo/Tarjeta)
  3. **Items** — tabla compacta con stepper de cantidad, thumbnails, precios y totales por fila
  4. **Resumen Financiero** — Subtotal/IVA/TOTAL con highlight

### Layout Responsive
- **Desktop**: contenido centrado con maxWidth constraint, padding adaptable
- **Mobile**: scroll vertical con padding estándar
- **Formulario de cliente**: LayoutBuilder muestra Cédula + Teléfono en fila (desktop) o columna (mobile)
- **Tabla de items**: responsive — desktop con columnas alineadas, mobile con layout apilado
- **Floating action**: botón "Guardar y Compartir" en bottom bar con SafeArea

### Mejoras UX
- Stepper de cantidad visual (botones circulares con hover)
- Tooltips en precios cash/card para productos
- Preview de imagen de items en thumbnails
- Feedback visual al agregar items (SnackBar)

---

## Cambios: `lib/features/orders/screens/quote_detail_page.dart`

### UI Moderna
- AppBar con status badge integrado (icono + color)
- **Status card** con círculo de color, info de fecha y badge de urgencia
- **Cliente card**: avatar icon + info rows con label:value layout
- **Items table**: headers con fondo gris, rows con thumbnail + nombre + precio + total
- **Totals card**: resumen financiero con currency formatting, total destacado
- **Historial**: ExpansionTile con eventos coloreados por acción

### Layout Responsive
- **Desktop**: two-column layout — contenido (70%) + sidebar con totals e historial (30%)
- **Mobile**: single column, todo apilado verticalmente
- **Items table**: LayoutBuilder detecta ancho — desktop con columnas alineadas, mobile con layout compacto apilado

### Acciones
- Botones de Aprobar/Rechazar en bottom bar (para staff)
- Iconos de acción en AppBar (edit, share PDF)
- Loading state con LinearProgressIndicator
- SnackBars con colores contextuales

---

## Responsive Breakpoints
| Screen | Quote List | Quote Create | Quote Detail |
|--------|-----------|--------------|--------------|
| ≥1200px | Grid 3 cols | Centered max-width | 70/30 sidebar |
| 720-1200px | Grid 2 cols | Normal padding | Single column |
| ≤720px | List full-width | Normal padding | Single column |

---

## Verificación
```
flutter analyze lib/features/orders/screens/quote_*.dart → 0 issues
```
