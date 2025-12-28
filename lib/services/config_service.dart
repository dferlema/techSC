import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _brandingDoc = 'app_config/branding';

  Future<Map<String, dynamic>> getBrandingConfig() async {
    try {
      final doc = await _firestore.doc(_brandingDoc).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error loading branding config: $e');
    }
    return _getDefaultBranding();
  }

  Map<String, dynamic> _getDefaultBranding() {
    return {
      'splash': {
        'title': 'TechService Pro',
        'subtitle': 'Soluciones Tecnológicas de Calidad',
        'imageUrl': null,
      },
      'onboarding': [
        {
          'title': 'Reparación Profesional',
          'description':
              'Servicios técnicos especializados para computadoras, laptops y servidores.',
          'imageUrl': null,
          'icon': 'computer',
        },
        {
          'title': 'Seguridad y Confianza',
          'description':
              'Tus datos están protegidos. Trabajamos con estándares de seguridad certificados.',
          'imageUrl': null,
          'icon': 'security',
        },
        {
          'title': 'Soporte 24/7',
          'description':
              'Nuestro equipo de expertos está disponible las 24 horas, los 7 días de la semana.',
          'imageUrl': null,
          'icon': 'support_agent',
        },
      ],
    };
  }

  Future<void> updateBrandingConfig(Map<String, dynamic> config) async {
    await _firestore.doc(_brandingDoc).set(config, SetOptions(merge: true));
  }
}
