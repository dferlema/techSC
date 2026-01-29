import 'package:flutter/material.dart';
import 'package:techsc/core/utils/branding_helper.dart';
import 'package:techsc/core/theme/app_colors.dart';

class LegalInfoPage extends StatelessWidget {
  final int initialTabIndex;

  const LegalInfoPage({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: initialTabIndex,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Información Legal'),
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Términos'),
              Tab(text: 'Privacidad'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
          ),
        ),
        body: TabBarView(children: [_buildTermsTab(), _buildPrivacyTab()]),
      ),
    );
  }

  Widget _buildTermsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('TÉRMINOS Y CONDICIONES DE USO'),
          _buildParagraph(
            'Bienvenido a ${BrandingHelper.appName}. Al acceder o utilizar nuestra aplicación, usted acepta estar sujeto a estos términos y condiciones. Por favor, léalos cuidadosamente.',
          ),
          _buildSubHeader('1. Descripción del Servicio'),
          _buildParagraph(
            '${BrandingHelper.appName} es una plataforma tecnológica diseñada para la gestión de servicios técnicos, catálogo de productos y reservas. Los servicios son prestados conforme a la disponibilidad y capacidad técnica de nuestro equipo.',
          ),
          _buildSubHeader('2. Responsabilidad del Usuario'),
          _buildParagraph(
            'El usuario se compromete a proporcionar información veraz, exacta y actualizada durante el registro y uso de la aplicación. Es responsabilidad exclusiva del usuario mantener la confidencialidad de su cuenta y contraseña.',
          ),
          _buildSubHeader('3. Propiedad Intelectual'),
          _buildParagraph(
            'Todo el contenido presente en esta aplicación, incluyendo pero no limitado a logotipos, textos, gráficos, iconos e imágenes, es propiedad de ${BrandingHelper.appName} o de sus proveedores de contenido y está protegido por las leyes de propiedad intelectual de la República del Ecuador.',
          ),
          _buildSubHeader('4. Limitación de Responsabilidad'),
          _buildParagraph(
            '${BrandingHelper.appName} no será responsable por daños directos, indirectos o incidentales que resulten del uso o la imposibilidad de uso del software, incluyendo fallas técnicas fuera de nuestro control.',
          ),
          _buildSubHeader('5. Ley Aplicable y Jurisdicción'),
          _buildParagraph(
            'Estos términos se rigen por las leyes de la República del Ecuador. Cualquier controversia será resuelta ante los jueces competentes de la ciudad de Quito.',
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPrivacyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('POLÍTICA DE PRIVACIDAD Y PROTECCIÓN DE DATOS'),
          _buildParagraph(
            'En cumplimiento con la Ley Orgánica de Protección de Datos Personales (LOPDP) de Ecuador, ${BrandingHelper.appName} informa a sus usuarios sobre el tratamiento de sus datos personales.',
          ),
          _buildSubHeader('1. Responsable del Tratamiento'),
          _buildParagraph(
            'TechSC, con domicilio en Ecuador, es el responsable del tratamiento de los datos personales recopilados a través de esta aplicación.',
          ),
          _buildSubHeader('2. Datos que Recopilamos'),
          _buildParagraph(
            'Recopilamos datos de identificación (nombre, cédula), contacto (teléfono, email, dirección) y datos técnicos necesarios para la prestación del servicio solicitado (tipo de equipo, problema reportado).',
          ),
          _buildSubHeader('3. Finalidad del Tratamiento'),
          _buildParagraph(
            'Sus datos se utilizan exclusivamente para: gestionar sus pedidos y reservas, prestar soporte técnico, enviar notificaciones sobre el estado de sus servicios y mejorar nuestra atención al cliente.',
          ),
          _buildSubHeader('4. Derechos del Titular (Derechos ARCO+)'),
          _buildParagraph(
            'De acuerdo con la LOPDP, usted como titular de los datos personales tiene derecho a:',
          ),
          _buildBulletPoint(
            'Acceso: Conocer qué datos tratamos y cómo lo hacemos.',
          ),
          _buildBulletPoint(
            'Rectificación: Solicitar la corrección de datos inexactos o incompletos.',
          ),
          _buildBulletPoint(
            'Cancelación/Eliminación: Solicitar que se supriman sus datos cuando ya no sean necesarios.',
          ),
          _buildBulletPoint(
            'Oposición: Oponerse al tratamiento de sus datos por motivos legítimos.',
          ),
          _buildBulletPoint(
            'Portabilidad: Recibir sus datos en un formato estructurado y legible.',
          ),
          _buildBulletPoint(
            'Suspensión: Solicitar la limitación del tratamiento en casos específicos conforme a la ley.',
          ),
          _buildSubHeader('5. Seguridad de la Información'),
          _buildParagraph(
            'Implementamos medidas técnicas y organizativas adecuadas para proteger sus datos personales contra el acceso no autorizado, pérdida o alteración.',
          ),
          _buildSubHeader('6. Contacto para Derechos'),
          _buildParagraph(
            'Para ejercer cualquiera de sus derechos ARCO+, puede contactarnos a través de nuestra sección de soporte o enviando un correo a ${BrandingHelper.companyEmail}.',
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSubHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        textAlign: TextAlign.justify,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.justify,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
