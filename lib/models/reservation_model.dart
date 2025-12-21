import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationModel {
  final String id;
  final String userId;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final String clientId;
  final String device;
  final String serviceType;
  final String description;
  final String address;
  final Map<String, dynamic>? location;
  final DateTime scheduledDate;
  final String scheduledTime;
  final String status;
  final Timestamp createdAt;

  // Technician fields
  final String? technicianId;
  final String? technicianComments;
  final String? solution;
  final double? repairCost;
  final String? spareParts;

  ReservationModel({
    required this.id,
    required this.userId,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    required this.clientId,
    required this.device,
    required this.serviceType,
    required this.description,
    required this.address,
    this.location,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    required this.createdAt,
    this.technicianId,
    this.technicianComments,
    this.solution,
    this.repairCost,
    this.spareParts,
  });

  factory ReservationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReservationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      clientName: data['clientName'] ?? '',
      clientEmail: data['clientEmail'] ?? '',
      clientPhone: data['clientPhone'] ?? '',
      clientId: data['clientId'] ?? '',
      device: data['device'] ?? '',
      serviceType: data['serviceType'] ?? '',
      description: data['description'] ?? '',
      address: data['address'] ?? '',
      location: data['location'],
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      scheduledTime: data['scheduledTime'] ?? '',
      status: data['status'] ?? 'pendiente',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      technicianId: data['technicianId'],
      technicianComments: data['technicianComments'],
      solution: data['solution'],
      repairCost: (data['repairCost'] as num?)?.toDouble(),
      spareParts: data['spareParts'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'clientPhone': clientPhone,
      'clientId': clientId,
      'device': device,
      'serviceType': serviceType,
      'description': description,
      'address': address,
      'location': location,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'scheduledTime': scheduledTime,
      'status': status,
      'createdAt': createdAt,
      'technicianId': technicianId,
      'technicianComments': technicianComments,
      'solution': solution,
      'repairCost': repairCost,
      'spareParts': spareParts,
    };
  }

  ReservationModel copyWith({
    String? status,
    String? technicianId,
    String? technicianComments,
    String? solution,
    double? repairCost,
    String? spareParts,
  }) {
    return ReservationModel(
      id: id,
      userId: userId,
      clientName: clientName,
      clientEmail: clientEmail,
      clientPhone: clientPhone,
      clientId: clientId,
      device: device,
      serviceType: serviceType,
      description: description,
      address: address,
      location: location,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      status: status ?? this.status,
      createdAt: createdAt,
      technicianId: technicianId ?? this.technicianId,
      technicianComments: technicianComments ?? this.technicianComments,
      solution: solution ?? this.solution,
      repairCost: repairCost ?? this.repairCost,
      spareParts: spareParts ?? this.spareParts,
    );
  }
}
