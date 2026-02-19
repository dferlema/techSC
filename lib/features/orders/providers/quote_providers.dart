import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/features/orders/models/quote_model.dart';
import 'package:techsc/features/orders/services/quote_service.dart';

/// Provider for QuoteService singleton
final quoteServiceProvider = Provider<QuoteService>((ref) {
  return QuoteService();
});

/// StreamProvider for quotes with optional filters
final quotesProvider = StreamProvider.family<List<QuoteModel>, QuotesFilters>((
  ref,
  filters,
) {
  final quoteService = ref.watch(quoteServiceProvider);
  return quoteService.getQuotes(
    customerUid: filters.customerUid,
    clientId: filters.clientId,
    creatorId: filters.creatorId,
  );
});

/// FutureProvider for a specific quote
final quoteByIdProvider = FutureProvider.family<QuoteModel?, String>((ref, id) {
  final quoteService = ref.watch(quoteServiceProvider);
  return quoteService.getQuoteById(id);
});

/// Filter class for Quotes
class QuotesFilters {
  final String? customerUid;
  final String? clientId;
  final String? creatorId;

  const QuotesFilters({this.customerUid, this.clientId, this.creatorId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuotesFilters &&
          runtimeType == other.runtimeType &&
          customerUid == other.customerUid &&
          clientId == other.clientId &&
          creatorId == other.creatorId;

  @override
  int get hashCode =>
      customerUid.hashCode ^ clientId.hashCode ^ creatorId.hashCode;
}
