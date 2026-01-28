import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de datos para un Proveedor.
///
/// Representa la información de un proveedor de productos,
/// incluyendo nombre, información de contacto y sitio web.
class SupplierModel {
  final String id;
  final String name;
  final String contactName;
  final String contactPhone;
  final String website;
  final DateTime createdAt;

  SupplierModel({
    required this.id,
    required this.name,
    required this.contactName,
    required this.contactPhone,
    required this.website,
    required this.createdAt,
  });

  /// Crea una instancia desde un documento de Firestore
  factory SupplierModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Backward compatibility: handle old contactInfo field
    String contactName = data['contactName'] ?? '';
    String contactPhone = data['contactPhone'] ?? '';

    // If new fields are empty but old contactInfo exists, use it
    if (contactName.isEmpty &&
        contactPhone.isEmpty &&
        data['contactInfo'] != null) {
      final oldContactInfo = data['contactInfo'] as String;
      // Try to extract phone number if it exists in the old format
      final phoneRegex = RegExp(r'\d{9,}');
      final phoneMatch = phoneRegex.firstMatch(oldContactInfo);
      if (phoneMatch != null) {
        contactPhone = phoneMatch.group(0) ?? '';
        contactName = oldContactInfo
            .replaceAll(phoneMatch.group(0) ?? '', '')
            .trim();
      } else {
        contactName = oldContactInfo;
      }
    }

    return SupplierModel(
      id: doc.id,
      name: data['name'] ?? '',
      contactName: contactName,
      contactPhone: contactPhone,
      website: data['website'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convierte el modelo a un Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'website': website,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Crea una copia del modelo con campos actualizados
  SupplierModel copyWith({
    String? id,
    String? name,
    String? contactName,
    String? contactPhone,
    String? website,
    DateTime? createdAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      website: website ?? this.website,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
