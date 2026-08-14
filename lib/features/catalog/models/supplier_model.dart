import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de datos para un Proveedor.
///
/// Representa la información de un proveedor de productos,
/// incluyendo nombre, información de contacto y sitio web.
class SupplierModel {
  final String id;
  final String name;
  final String ruc;
  final String contactName;
  final String contactPhone;
  final String website;
  final String address;
  final String email;
  final DateTime createdAt;

  SupplierModel({
    required this.id,
    required this.name,
    this.ruc = '',
    required this.contactName,
    required this.contactPhone,
    required this.website,
    this.address = '',
    this.email = '',
    required this.createdAt,
  });

  /// Crea una instancia desde un documento de Firestore
  factory SupplierModel.fromFirestoreMap(Map<String, dynamic> data, String id) {
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
      id: id,
      name: data['name'] ?? '',
      ruc: data['ruc'] ?? '',
      contactName: contactName,
      contactPhone: contactPhone,
      website: data['website'] ?? '',
      address: data['address'] ?? '',
      email: data['email'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory SupplierModel.fromFirestore(DocumentSnapshot doc) {
    return SupplierModel.fromFirestoreMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  /// Convierte el modelo a un Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ruc': ruc,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'website': website,
      'address': address,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  /// Crea una copia del modelo con campos actualizados
  SupplierModel copyWith({
    String? id,
    String? name,
    String? ruc,
    String? contactName,
    String? contactPhone,
    String? website,
    String? address,
    String? email,
    DateTime? createdAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ruc: ruc ?? this.ruc,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      website: website ?? this.website,
      address: address ?? this.address,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
