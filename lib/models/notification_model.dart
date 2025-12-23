import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String type; // 'order', 'reservation', 'comment', 'authorization'
  final String relatedId; // ID of the order or reservation
  final String? receiverRole; // If null, specific to a user
  final String? receiverId; // If null, broadcast to role

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    required this.type,
    required this.relatedId,
    this.receiverRole,
    this.receiverId,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      type: data['type'] ?? '',
      relatedId: data['relatedId'] ?? '',
      receiverRole: data['receiverRole'],
      receiverId: data['receiverId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'type': type,
      'relatedId': relatedId,
      'receiverRole': receiverRole,
      'receiverId': receiverId,
    };
  }
}
