class ProfitRange {
  final double minPrice;
  final double maxPrice;
  final double profitPercentage;

  ProfitRange({
    required this.minPrice,
    required this.maxPrice,
    required this.profitPercentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'profitPercentage': profitPercentage,
    };
  }

  factory ProfitRange.fromMap(Map<String, dynamic> map) {
    return ProfitRange(
      minPrice: (map['minPrice'] as num).toDouble(),
      maxPrice: (map['maxPrice'] as num).toDouble(),
      profitPercentage: (map['profitPercentage'] as num).toDouble(),
    );
  }

  @override
  String toString() {
    return 'ProfitRange($minPrice - $maxPrice: $profitPercentage%)';
  }
}
