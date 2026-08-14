import 'dart:math';

/// Insight generado por el análisis de ventas.
class SalesInsight {
  final String type; // 'oportunidad' | 'alerta' | 'recomendacion'
  final String title;
  final String detail;
  final double score; // 0..100, mayor = más importante

  SalesInsight({
    required this.type,
    required this.title,
    required this.detail,
    required this.score,
  });
}

class AiService {
  static final AiService _instance = AiService._();
  AiService._();
  factory AiService() => _instance;

  // ─── TF-IDF Búsqueda Semántica ──────────────────────────────────

  Map<String, double> _tf(String text) {
    final words = text.toLowerCase().split(RegExp(r'[^a-záéíóúñ\w]+'));
    final freq = <String, double>{};
    for (final w in words) {
      if (w.length < 2) continue;
      freq[w] = (freq[w] ?? 0) + 1;
    }
    final total = freq.values.fold(0.0, (a, b) => a + b);
    return total > 0 ? freq.map((k, v) => MapEntry(k, v / total)) : freq;
  }

  Map<String, double> _idf(List<Map<String, double>> tfs) {
    final n = tfs.length;
    final df = <String, int>{};
    for (final tf in tfs) {
      for (final term in tf.keys) {
        df[term] = (df[term] ?? 0) + 1;
      }
    }
    return df.map((k, v) => MapEntry(k, log((n + 1) / (v + 1)) + 1));
  }

  List<double> _vectorize(
    Map<String, double> tf,
    Map<String, double> idf,
    List<String> vocab,
  ) {
    return vocab.map((w) => (tf[w] ?? 0) * (idf[w] ?? 0)).toList();
  }

  double _cosine(List<double> a, List<double> b) {
    double dot = 0, na = 0, nb = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    final denom = sqrt(na) * sqrt(nb);
    return denom == 0 ? 0 : dot / denom;
  }

  /// Busca productos por similitud semántica (TF-IDF + Coseno).
  List<(int index, double score)> search<T>(
    String query,
    List<String> corpus,
  ) {
    if (query.trim().isEmpty || corpus.isEmpty) return [];

    final tfs = corpus.map((c) => _tf(c)).toList();
    final idf = _idf(tfs);
    final vocab = idf.keys.toList()..sort();

    final qTf = _tf(query);
    final qVec = _vectorize(qTf, idf, vocab);

    final scored = <(int, double)>[];
    for (var i = 0; i < corpus.length; i++) {
      final vec = _vectorize(tfs[i], idf, vocab);
      final sim = _cosine(qVec, vec);
      if (sim > 0) scored.add((i, sim));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored;
  }

  // ─── Productos Similares (Co-ocurrencia en Órdenes) ────────────

  /// Calcula productos frecuentemente comprados juntos.
  /// [ordersByProducts] es un map de `productId → veces comprado`,
  /// [coOccurrence] es un map de `(productA, productB) → veces juntos`.
  List<String> similarProducts(
    String productId,
    Map<String, int> ordersByProduct,
    Map<(String, String), int> coOccurrence, {
    int topK = 5,
  }) {
    final candidates = <(String, int)>{};
    for (final entry in coOccurrence.entries) {
      final (a, b) = entry.key;
      if (a == productId) candidates.add((b, entry.value));
      if (b == productId) candidates.add((a, entry.value));
    }
    final sorted = candidates.toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return sorted.take(topK).map((e) => e.$1).toList();
  }

  // ─── Análisis de Rentabilidad de Ventas (Reglas + Heurísticas) ──

  /// Análisis de ventas por producto con reglas heurísticas (open source, sin API).
  ///
  /// [products] lista de mapas con claves: name, revenue, profit, marginPct,
  /// unitsSold, stock, orderCount, categoryName.
  List<SalesInsight> analyzeSales(List<Map<String, dynamic>> products) {
    final insights = <SalesInsight>[];
    if (products.isEmpty) return insights;

    final totalProfit = products.fold(0.0, (a, p) => a + (p['profit'] as num).toDouble());

    // Ordenar por contribución a la utilidad
    final sortedByProfit = [...products]..sort((a, b) => (b['profit'] as num).compareTo(a['profit'] as num));

    // Productos TOP (regla 80/20 aproximada)
    double accProfit = 0;
    final topProducts = <Map<String, dynamic>>[];
    for (final p in sortedByProfit) {
      accProfit += (p['profit'] as num).toDouble();
      topProducts.add(p);
      if (totalProfit > 0 && accProfit / totalProfit >= 0.8) break;
    }

    if (topProducts.isNotEmpty) {
      final names = topProducts.take(3).map((p) => p['name']).join(', ');
      insights.add(SalesInsight(
        type: 'recomendacion',
        title: 'Productos estrella',
        detail: '$names concentran la mayor parte de la utilidad. Prioriza su stock y promoción.',
        score: 90,
      ));
    }

    // Productos con margen bajo
    final lowMargin = products.where((p) => (p['revenue'] as num).toDouble() > 0 && (p['marginPct'] as num).toDouble() < 15).toList()
      ..sort((a, b) => (a['marginPct'] as num).compareTo(b['marginPct'] as num));
    if (lowMargin.isNotEmpty) {
      final names = lowMargin.take(3).map((p) => '${p['name']} (${(p['marginPct'] as num).toStringAsFixed(0)}%)').join(', ');
      insights.add(SalesInsight(
        type: 'alerta',
        title: 'Margen bajo detectado',
        detail: '$names. Considera renegociar el costo de compra o ajustar el precio.',
        score: 70,
      ));
    }

    // Productos con pérdida
    final losing = products.where((p) => (p['profit'] as num).toDouble() < 0).toList();
    if (losing.isNotEmpty) {
      final names = losing.take(3).map((p) => p['name']).join(', ');
      insights.add(SalesInsight(
        type: 'alerta',
        title: 'Productos en pérdida',
        detail: '$names se venden por debajo de su costo. Revisa precio o costo de compra.',
        score: 85,
      ));
    }

    // Stock bajo con demanda alta
    final hotItems = products.where((p) =>
        (p['unitsSold'] as num).toInt() >= 3 && (p['stock'] as num).toInt() <= 2).toList();
    if (hotItems.isNotEmpty) {
      final names = hotItems.take(3).map((p) => p['name']).join(', ');
      insights.add(SalesInsight(
        type: 'alerta',
        title: 'Riesgo de agotar stock',
        detail: '$names tienen alta demanda y stock crítico. Recomendado reabastecer.',
        score: 75,
      ));
    }

    // Mejor margen relativo
    final bestMargin = products.where((p) => (p['unitsSold'] as num).toInt() >= 2).toList()
      ..sort((a, b) => (b['marginPct'] as num).compareTo(a['marginPct'] as num));
    if (bestMargin.isNotEmpty) {
      final b = bestMargin.first;
      insights.add(SalesInsight(
        type: 'oportunidad',
        title: 'Mayor rentabilidad relativa',
        detail: '${b['name']} rinde ${(b['marginPct'] as num).toStringAsFixed(1)}% de margen. Ideal para upselling.',
        score: 65,
      ));
    }

    insights.sort((a, b) => b.score.compareTo(a.score));
    return insights;
  }

  /// Agrupa productos por similitud semántica de nombre (TF-IDF + Coseno).
  /// Retorna pares de productos que suelen venderse juntos por co-ocurrencia.
  List<(String productA, String productB)> findBundles(
    List<Map<String, dynamic>> salesByProduct,
  ) {
    // salesByProduct: [{productId, name, revenue}]
    if (salesByProduct.length < 2) return [];

    final corpus = salesByProduct.map((s) => s['name'] as String).toList();
    final tfs = corpus.map((c) => _tf(c)).toList();
    final idf = _idf(tfs);
    final vocab = idf.keys.toList()..sort();

    final results = <(String, String, double)>[];
    for (var i = 0; i < salesByProduct.length; i++) {
      for (var j = i + 1; j < salesByProduct.length; j++) {
        final a = _vectorize(tfs[i], idf, vocab);
        final b = _vectorize(tfs[j], idf, vocab);
        final sim = _cosine(a, b);
        if (sim > 0.35) {
          results.add((salesByProduct[i]['productId'] as String, salesByProduct[j]['productId'] as String, sim));
        }
      }
    }
    results.sort((x, y) => y.$3.compareTo(x.$3));
    return results.take(5).map((r) => (r.$1, r.$2)).toList();
  }

  // ─── Sugerencia de Diagnóstico (Keyword Matching) ──────────────

  /// Empareja la descripción de un problema con soluciones previas.
  /// [pastCases] es una lista de `(problema, solución)` de reservas anteriores.
  List<(String problem, String solution, double score)> suggestDiagnosis(
    String description,
    List<(String problem, String solution)> pastCases,
  ) {
    if (description.trim().isEmpty || pastCases.isEmpty) return [];

    final corpus = pastCases.map((c) => c.$1).toList();
    final results = search(description, corpus);
    return results
        .where((r) => r.$2 > 0.05)
        .map((r) => (
          pastCases[r.$1].$1,
          pastCases[r.$1].$2,
          r.$2,
        ))
        .toList();
  }

  // ─── Análisis de Rentabilidad por Servicio (Reglas + Heurísticas) ──

  /// Análisis de servicios técnicos con reglas heurísticas.
  ///
  /// [services] lista de mapas con claves: name, revenue, partsCost,
  /// laborRevenue, marginPct, avgRepairTime, completionRate, totalServices.
  /// [technicians] lista de mapas con claves: name, revenue, partsCost,
  /// completionRate, avgRepairTime, marginPct, completedServices.
  /// [timeAnalysis] lista de mapas con claves: name, avgHours, medianHours.
  /// [recurringIssues] lista de mapas con claves: device, issue, count.
  List<SalesInsight> analyzeServiceProfitability({
    required List<Map<String, dynamic>> services,
    required List<Map<String, dynamic>> technicians,
    required List<Map<String, dynamic>> timeAnalysis,
    required List<Map<String, dynamic>> recurringIssues,
  }) {
    final insights = <SalesInsight>[];
    if (services.isEmpty) return insights;

    final totalRevenue =
        services.fold(0.0, (a, s) => a + (s['revenue'] as num).toDouble());
    final totalPartsCost =
        services.fold(0.0, (a, s) => a + (s['partsCost'] as num).toDouble());
    final totalLabor = totalRevenue - totalPartsCost;

    // ── Servicios estrella (Pareto 80/20 por mano de obra) ──
    final sortedByLabor = [...services]
      ..sort((a, b) =>
          (b['laborRevenue'] as num).compareTo(a['laborRevenue'] as num));

    double accLabor = 0;
    final starServices = <Map<String, dynamic>>[];
    for (final s in sortedByLabor) {
      accLabor += (s['laborRevenue'] as num).toDouble();
      starServices.add(s);
      if (totalLabor > 0 && accLabor / totalLabor >= 0.8) break;
    }
    if (starServices.isNotEmpty) {
      final names = starServices.take(3).map((s) => s['name']).join(', ');
      insights.add(SalesInsight(
        type: 'recomendacion',
        title: 'Servicios más rentables',
        detail:
            '$names generan la mayor parte de la mano de obra. Prioriza capacidades en estos servicios.',
        score: 92,
      ));
    }

    // ── Costo de piezas alto (>50% del revenue) ──
    final highParts = services.where((s) {
      final rev = (s['revenue'] as num).toDouble();
      final parts = (s['partsCost'] as num).toDouble();
      return rev > 0 && parts / rev > 0.5;
    }).toList()
      ..sort((a, b) {
        final rA = (a['partsCost'] as num).toDouble() /
            (a['revenue'] as num).toDouble();
        final rB = (b['partsCost'] as num).toDouble() /
            (b['revenue'] as num).toDouble();
        return rB.compareTo(rA);
      });
    if (highParts.isNotEmpty) {
      final names =
          highParts.take(3).map((s) => '${s['name']} (${((s['partsCost'] as num).toDouble() / (s['revenue'] as num).toDouble() * 100).toStringAsFixed(0)}%)').join(', ');
      insights.add(SalesInsight(
        type: 'alerta',
        title: 'Costo de piezas elevado',
        detail:
            '$names gastan más del 50% en piezas. Considera negociar proveedores o ajustar precios.',
        score: 80,
      ));
    }

    // ── Técnicos top (mejor tasa completado + menor tiempo) ──
    if (technicians.isNotEmpty) {
      final ranked = [...technicians]..sort((a, b) {
          final scoreA = (a['completionRate'] as num).toDouble() * 0.6 -
              (a['avgRepairTime'] as num).toDouble() * 0.4;
          final scoreB = (b['completionRate'] as num).toDouble() * 0.6 -
              (b['avgRepairTime'] as num).toDouble() * 0.4;
          return scoreB.compareTo(scoreA);
        });
      final top = ranked.first;
      insights.add(SalesInsight(
        type: 'recomendacion',
        title: 'Técnico destacado',
        detail:
            '${top['name']} tiene ${(top['completionRate'] as num).toStringAsFixed(0)}% completado con tiempo promedio de ${(top['avgRepairTime'] as num).toStringAsFixed(1)}h.',
        score: 70,
      ));
    }

    // ── Dispositivos problemáticos (recurrentes) ──
    if (recurringIssues.isNotEmpty) {
      final topIssue = recurringIssues.first;
      final solutions = (topIssue['solutions'] as List<dynamic>?) ?? [];
      final solText = solutions.isNotEmpty
          ? ' Soluciones previas: ${solutions.take(2).join("; ")}.'
          : '';
      insights.add(SalesInsight(
        type: 'alerta',
        title: 'Problema recurrente detectado',
        detail:
            '${topIssue['device']} con "${topIssue['issue']}" aparece ${topIssue['count']} veces.$solText',
        score: 75,
      ));
    }

    // ── Tiempo excesivo (>2x promedio de su tipo) ──
    for (final t in timeAnalysis) {
      final avg = (t['avgHours'] as num).toDouble();
      final max_ = (t['maxHours'] as num?)?.toDouble() ?? 0;
      if (avg > 0 && max_ > avg * 2) {
        insights.add(SalesInsight(
          type: 'alerta',
          title: 'Tiempo variable en ${t['name']}',
          detail:
              'Tiempo promedio ${avg.toStringAsFixed(1)}h pero máximo ${max_.toStringAsFixed(1)}h. Considera estandarizar el proceso.',
          score: 55,
        ));
        break;
      }
    }

    // ── Oportunidad: servicios de bajo margen con alto volumen ──
    final lowMarginHighVol = services.where((s) {
      final margin = (s['marginPct'] as num).toDouble();
      final count = (s['totalServices'] as num).toInt();
      return margin < 20 && count >= 3;
    }).toList();
    if (lowMarginHighVol.isNotEmpty) {
      final names = lowMarginHighVol
          .take(3)
          .map((s) => '${s['name']} (${(s['marginPct'] as num).toStringAsFixed(0)}%)')
          .join(', ');
      insights.add(SalesInsight(
        type: 'oportunidad',
        title: 'Servicios de alto volumen, bajo margen',
        detail:
            '$names tienen muchos servicios pero poco margen. Optimiza tiempos o sube precios.',
        score: 60,
      ));
    }

    insights.sort((a, b) => b.score.compareTo(a.score));
    return insights;
  }
}
