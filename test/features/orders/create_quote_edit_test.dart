import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tscomputer/features/orders/models/quote_model.dart';
import 'package:tscomputer/features/orders/screens/create_quote_page.dart';

QuoteModel _sampleQuote({bool withServices = true, bool extreme = false}) {
  return QuoteModel(
    id: 'q1',
    clientId: '1712345678',
    clientName: extreme ? 'Consumidor Final Empresa de Prueba S.A. de C.V. Muy Largo' : 'Cliente de Prueba',
    clientEmail: 'cliente@test.com',
    clientPhone: '0999999999',
    creatorId: 'user1',
    items: [
      QuoteItem(
        id: 'p1',
        name: extreme
            ? 'Laptop HP Pavilion Gaming 15-dk0097la con procesador Intel Core i7 y tarjeta gráfica dedicada'
            : 'Laptop HP Pavilion Gaming 15 con procesador Intel i7',
        type: 'product',
        price: extreme ? 4850.99 : 850.0,
        quantity: extreme ? 9 : 2,
        description: '',
        imageUrl: '',
        cashPrice: extreme ? 4700.50 : 800.0,
        cardPrice: extreme ? 4850.99 : 850.0,
      ),
      if (withServices)
        QuoteItem(
          id: 's1',
          name: 'Mantenimiento',
          type: 'service',
          price: 60.0,
          quantity: 1,
          description: '',
          imageUrl: null,
        ),
    ],
    history: const [],
    createdAt: DateTime.now(),
    status: 'draft',
    paymentMethod: 'tarjeta',
    applyTax: extreme,
  );
}

void main() {
  testWidgets('Editar cotizacion en movil no lanza excepcion', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CreateQuotePage(existingQuote: _sampleQuote()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Guardar y Compartir (WhatsApp)'), findsOneWidget);
    expect(find.text('Laptop HP Pavilion Gaming 15 con procesador Intel i7'),
        findsOneWidget);
  });

  testWidgets('Editar cotizacion solo productos en movil', (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CreateQuotePage(
              existingQuote: _sampleQuote(withServices: false)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Guardar y Compartir (WhatsApp)'), findsOneWidget);
    expect(find.text('Laptop HP Pavilion Gaming 15 con procesador Intel i7'),
        findsOneWidget);
  });

  testWidgets('Escanear anchos y escalas para encontrar overflow', (tester) async {
    final found = <String>[];
    for (final width in [320.0, 340.0, 360.0, 380.0, 400.0, 411.0, 420.0, 430.0, 450.0, 480.0, 550.0, 600.0]) {
      for (final textScale in [0.85, 1.0, 1.1, 1.2, 1.3]) {
        for (final extreme in [false, true]) {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
                home: CreateQuotePage(
                    existingQuote: _sampleQuote(withServices: false, extreme: extreme)),
              ),
            ),
          );

          await tester.pumpAndSettle();

          final ex = tester.takeException();
          if (ex != null) {
            final lines = ex.toString().split('\n');
            final relevantLine = lines.indexWhere((l) => l.contains('Row:file:'));
            found.add('width=$width textScale=$textScale extreme=$extreme: '
                '${lines.first} | ${relevantLine >= 0 ? lines[relevantLine].trim() : 'n/a'}');
          }
        }
      }
    }
    expect(found, isEmpty,
        reason: 'Overflows encontrados:\n${found.join('\n')}');
  });
}