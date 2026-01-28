import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:techsc/features/orders/models/quote_model.dart';
import 'package:techsc/features/orders/models/order_model.dart';
import 'package:techsc/core/services/notification_service.dart';

/// Service to handle all Quote-related operations in Firestore.
/// This includes creating, updating, approving, and rejecting quotes.
class QuoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection References
  CollectionReference get _quotesCollection => _firestore.collection('quotes');
  CollectionReference get _ordersCollection => _firestore.collection('orders');
  final NotificationService _notificationService = NotificationService();

  /// Creates a new quote with a custom sequential ID (format: yyyyMMdd-XX).
  /// Sends a notification to the client if [QuoteModel.customerUid] is present.
  Future<String> createQuote(QuoteModel quote) async {
    try {
      final now = DateTime.now();
      final datePrefix = DateFormat('yyyyMMdd').format(now);

      // Define today's range
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day + 1);

      // Get current day's quotes to count them
      final snapshot = await _quotesCollection
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      final nextIndex = snapshot.docs.length + 1;
      final sequenceId = '$datePrefix-${nextIndex.toString().padLeft(2, '0')}';

      // Create document with the custom ID
      final docRef = _quotesCollection.doc(sequenceId);

      // Update the quote with the new ID and creation history
      final newQuote = quote.copyWith(
        id: sequenceId,
        history: [
          ...quote.history,
          QuoteHistoryEvent(
            date: now,
            userId: quote.creatorId,
            action: 'created',
            description: 'Cotización creada #$sequenceId',
          ),
        ],
      );

      await docRef.set(newQuote.toMap());

      // 3. Send Notification to Client if customerUid is available
      if (newQuote.customerUid != null) {
        await _notificationService.sendNotification(
          title: 'Nueva Cotización Recibida',
          body: 'Has recibido una nueva cotización: #${newQuote.id}',
          type: 'quote',
          relatedId: newQuote.id,
          receiverId: newQuote.customerUid,
        );
      }

      return sequenceId;
    } catch (e) {
      throw Exception('Error creando cotización: $e');
    }
  }

  /// Updates an existing quote and records the modification in its history.
  Future<void> updateQuote(
    QuoteModel quote,
    String userId,
    String modificationDescription,
  ) async {
    try {
      final updatedQuote = quote.copyWith(
        history: [
          ...quote.history,
          QuoteHistoryEvent(
            date: DateTime.now(),
            userId: userId,
            action: 'updated',
            description: modificationDescription,
          ),
        ],
      );

      await _quotesCollection.doc(quote.id).update(updatedQuote.toMap());
    } catch (e) {
      throw Exception('Error actualizando cotización: $e');
    }
  }

  /// Returns a stream of quotes filtered by customer, client, or creator.
  /// Used for both client views and staff dashboards.
  Stream<List<QuoteModel>> getQuotes({
    String? customerUid,
    String? clientId,
    String? creatorId,
  }) {
    Query query = _quotesCollection;

    if (customerUid != null) {
      query = query.where('customerUid', isEqualTo: customerUid);
    } else if (clientId != null) {
      query = query.where('clientId', isEqualTo: clientId);
    }

    // If not client, maybe we want to filter by creator (e.g. for sellers seeing their own)
    // Note: Admins likely want to see all, so we might not pass creatorId for them.
    if (creatorId != null) {
      query = query.where('creatorId', isEqualTo: creatorId);
    }

    return query.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => QuoteModel.fromFirestore(doc)).toList();
    });
  }

  /// Fetches a single quote by its custom [id].
  Future<QuoteModel?> getQuoteById(String id) async {
    final doc = await _quotesCollection.doc(id).get();
    if (doc.exists) {
      return QuoteModel.fromFirestore(doc);
    }
    return null;
  }

  /// Helper to generate a sequential Order ID (PyyyyMMdd-XX)
  Future<String> _generateOrderId() async {
    final now = DateTime.now();
    final datePrefix = DateFormat('yyyyMMdd').format(now);

    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day + 1);

    final snapshot = await _ordersCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final nextIndex = snapshot.docs.length + 1;
    return 'P$datePrefix-${nextIndex.toString().padLeft(2, '0')}';
  }

  /// Atomically approves a quote and converts it into a new [OrderModel].
  /// This operation is performed within a Firestore transaction for consistency.
  Future<String> approveQuote(String quoteId, String userId) async {
    QuoteModel? approvedQuoteCaptured;

    // Generate the ID *before* the transaction.
    // Note: In high concurrency, this might cause collision, but for this scale it's acceptable.
    // Ideally we would read-modify-write a counter in the transaction.
    final customOrderId = await _generateOrderId();

    final orderId = await _firestore.runTransaction((transaction) async {
      final quoteRef = _quotesCollection.doc(quoteId);
      final quoteDoc = await transaction.get(quoteRef);

      if (!quoteDoc.exists) {
        throw Exception('Quote not found');
      }

      final quote = QuoteModel.fromFirestore(quoteDoc);
      approvedQuoteCaptured = quote;

      if (quote.status == 'approved' || quote.status == 'converted') {
        throw Exception('Quote is already approved or converted');
      }

      // 1. Update Quote Status
      final approvedQuote = quote.copyWith(
        status: 'approved',
        history: [
          ...quote.history,
          QuoteHistoryEvent(
            date: DateTime.now(),
            userId: userId,
            action: 'approved',
            description: 'Cotización aprobada por cliente',
          ),
        ],
      );

      transaction.update(quoteRef, approvedQuote.toMap());

      // 2. Create Order with userId and other fields
      // Use the custom ID
      final orderRef = _ordersCollection.doc(customOrderId);

      final newOrder = OrderModel(
        id: orderRef.id,
        quoteId: quote.id,
        originalQuote: approvedQuote,
        status: 'pending',
        paymentStatus: 'unpaid',
        createdAt: DateTime.now(),
      );

      // Convert to map and add userId (customerUid from quote, or fallback to clientId)
      final orderData = newOrder.toMap();
      orderData['userId'] = quote.customerUid ?? quote.clientId;
      orderData['userEmail'] = quote.clientEmail;

      transaction.set(orderRef, orderData);

      return orderRef.id;
    });

    // Post-transaction Notification
    if (approvedQuoteCaptured != null) {
      try {
        final q = approvedQuoteCaptured!;
        await _notificationService.notifyOrderCreated(
          orderId: orderId,
          clientName: q.clientName,
          customerUid: q.customerUid ?? q.clientId,
        );
      } catch (e) {
        debugPrint('Error sending notification: $e');
      }
    }

    return orderId;
  }

  /// Rejects a quote and updates its status.
  Future<void> rejectQuote(String quoteId, String userId) async {
    final quoteRef = _quotesCollection.doc(quoteId);

    // Retrieve first to add history
    final doc = await quoteRef.get();
    if (!doc.exists) return;
    final quote = QuoteModel.fromFirestore(doc);

    final rejectedQuote = quote.copyWith(
      status: 'rejected',
      history: [
        ...quote.history,
        QuoteHistoryEvent(
          date: DateTime.now(),
          userId: userId,
          action: 'rejected',
          description: 'Cotización rechazada por cliente',
        ),
      ],
    );

    await quoteRef.update(rejectedQuote.toMap());
  }
}
