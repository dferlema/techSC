import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/core/services/document_id_service.dart';
import 'package:tscomputer/features/orders/models/quote_model.dart';
import 'package:tscomputer/features/orders/models/order_model.dart';
import 'package:tscomputer/core/services/notification_service.dart';
import 'package:tscomputer/core/utils/firestore_retry.dart';

/// Maneja todas las operaciones de cotizaciones en Firestore.
class QuoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _quotesCollection => _firestore.collection('quotes');
  CollectionReference get _ordersCollection => _firestore.collection('orders');

  final NotificationService _notificationService = NotificationService();

  /// Crea una cotización con ID secuencial (yyyyMMdd-XX).
  Future<String> createQuote(QuoteModel quote) async {
    try {
      final now = DateTime.now();
      final id =
          await DocumentIdService().generateId(prefix: 'Q', useDate: true);
      final docRef = _quotesCollection.doc(id);

      final newQuote = quote.copyWith(
        id: id,
        history: [
          ...quote.history,
          QuoteHistoryEvent(
            date: now,
            userId: quote.creatorId,
            action: 'created',
            description: 'Cotización creada #$id',
          ),
        ],
      );

      await docRef.set(newQuote.toMap());

      if (newQuote.customerUid != null) {
        await _notificationService.sendNotification(
          title: 'Nueva Cotización Recibida',
          body: 'Has recibido una nueva cotización: #${newQuote.id}',
          type: 'quote',
          relatedId: newQuote.id,
          receiverId: newQuote.customerUid,
        );
      }

      return id;
    } catch (e) {
      throw Exception('Error creando cotización: $e');
    }
  }

  /// Actualiza una cotización existente y registra la modificación.
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

  /// Stream de cotizaciones filtradas por cliente, customer o creador.
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

    if (creatorId != null) {
      query = query.where('creatorId', isEqualTo: creatorId);
    }

    return query.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => QuoteModel.fromFirestore(doc)).toList();
    });
  }

  /// Obtiene una cotización por su ID.
  Future<QuoteModel?> getQuoteById(String id) async {
    final doc = await retryFirestore(() => _quotesCollection.doc(id).get());
    if (doc.exists) {
      return QuoteModel.fromFirestore(doc);
    }
    return null;
  }

  Future<String> _generateOrderId() =>
      DocumentIdService().generateId(prefix: 'ord', useDate: true);

  /// Aprueba una cotización y la convierte en una orden (transacción atómica).
  Future<String> approveQuote(
    String quoteId,
    String userId, {
    String? historyDescription,
  }) async {
    QuoteModel? approvedQuoteCaptured;

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

      final approvedQuote = quote.copyWith(
        status: 'approved',
        history: [
          ...quote.history,
          QuoteHistoryEvent(
            date: DateTime.now(),
            userId: userId,
            action: 'approved',
            description:
                historyDescription ?? 'Cotización aprobada por cliente',
          ),
        ],
      );

      transaction.update(quoteRef, approvedQuote.toMap());

      final orderRef = _ordersCollection.doc(customOrderId);

      final newOrder = OrderModel(
        id: orderRef.id,
        quoteId: quote.id,
        originalQuote: approvedQuote,
        status: 'pending',
        paymentStatus: 'unpaid',
        createdAt: DateTime.now(),
      );

      final orderData = newOrder.toMap();
      orderData['userId'] = quote.customerUid ?? quote.clientId;
      orderData['userEmail'] = quote.clientEmail;

      transaction.set(orderRef, orderData);

      return orderRef.id;
    });

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

  /// Rechaza una cotización y actualiza su estado.
  Future<void> rejectQuote(
    String quoteId,
    String userId, {
    String? historyDescription,
  }) async {
    final quoteRef = _quotesCollection.doc(quoteId);

    final doc = await retryFirestore(() => quoteRef.get());
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
          description:
              historyDescription ?? 'Cotización rechazada por cliente',
        ),
      ],
    );

    await quoteRef.update(rejectedQuote.toMap());
  }
}