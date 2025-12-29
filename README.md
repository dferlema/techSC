# TechSC - Gestión Técnica TechServiceComputer

**TechSC** es una plataforma integral desarrollada en Flutter para la gestión de servicios técnicos, ventas de productos informáticos y seguimiento de reparaciones. Diseñada para conectar a clientes con técnicos especializados, permitiendo un flujo de trabajo optimizado desde la reserva hasta la entrega final.

## 🚀 Funcionalidades Principales

### 🔐 Autenticación y Seguridad
- **Gestión de Roles**: Sistema basado en roles (Administrador, Técnico, Vendedor y Cliente).
- **Seguridad de Sesión**: Cierre de sesión automático tras 10 minutos de inactividad para proteger los datos del usuario.
- **Perfiles Personalizados**: Edición de password, actualización de dirección y gestión de imagen de perfil (almacenamiento local y remoto).
- **Recuperación**: Funcionalidad de "Olvidé mi contraseña" y opción de "Recordarme".

### 🛠️ Módulo de Servicio Técnico
- **Reservas Inteligentes**: Formulario detallado con autocompletado de datos del cliente desde su perfil.
- **Geolocalización**: Captura de coordenadas GPS para servicios a domicilio.
- **Generación de Comprobantes**: Creación automática de PDFs con el resumen de la reserva.
- **Integración con WhatsApp**: Redirección directa al número de soporte técnico con un mensaje pre-formateado de la reserva.
- **Registro Manual**: Los técnicos pueden registrar trabajos para clientes no registrados directamente desde el taller.

### 🛒 Tienda y Pedidos
- **Catálogo de Productos**: Navegación por categorías con detalles técnicos de cada artículo.
- **Carrito de Compras**: Gestión dinámica de artículos, cálculo de totales y generación de pedidos.
- **Gestión de Pedidos**: Los administradores pueden visualizar y controlar el estado de los pedidos generados por los clientes.

### 👨‍🔧 Panel del Técnico
- **Dashboard de Gestión**: Visualización segmentada de trabajos (Pendientes, En Proceso, Historial).
- **Seguimiento Detallado**: Registro de comentarios técnicos, soluciones aplicadas, costos de reparación y repuestos utilizados.
- **Comunicación Directa**: Acceso rápido al WhatsApp del cliente desde la ficha de reparación.

### 🔔 Notificaciones
- **Sistema de Alertas**: Notificaciones en tiempo real sobre cambios de estado en reservas, aprobaciones de presupuestos y nuevos mensajes del sistema.
- **Navegación Inteligente**: Acceso directo al detalle de la reserva o pedido desde la notificación recibida.

## 🛠️ Stack Tecnológico

- **Frontend**: Flutter (Dart) - UI dinámica y responsiva.
- **Backend**: Firebase
  - **Firestore**: Base de datos NoSQL en tiempo real.
  - **Auth**: Autenticación segura.
  - **Storage**: Almacenamiento de imágenes de productos y perfiles.
- **Paquetes Clave**:
  - `google_maps_flutter`: Para integración de mapas y GPS.
  - `pdf` & `printing`: Para la generación y exportación de documentos.
  - `url_launcher`: Para conexión con WhatsApp y llamadas.
  - `shared_preferences`: Gestión de persistencia local y sesiones.

## 📁 Estructura del Proyecto (lib/)

- `models/`: Definición de estructuras de datos (Reservas, Notificaciones, etc.).
- `screens/`: Todas las interfaces de usuario (Home, Admin Panel, Service Form, etc.).
- `services/`: Lógica de negocio y conexión con APIs/Firebase (Auth, Roles, Notificaciones).
- `utils/`: Utilidades generales y formateadores.
- `widgets/`: Componentes de UI reutilizables.

## ⚙️ Configuración

1. Asegúrate de tener Flutter instalado (`flavor` estable).
2. Clona el repositorio.
3. Ejecuta `flutter pub get` para instalar dependencias.
4. Configura el archivo `firebase_options.dart` con tus credenciales de proyecto.
5. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

---
*Desarrollado para TechServiceComputer por Diego lema.*
