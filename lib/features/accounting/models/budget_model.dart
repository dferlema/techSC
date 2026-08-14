class BudgetModel {
  final String id;
  final int year;
  final int month;
  final String category;
  final double budgetedAmount;
  final String type; // 'ingreso' or 'egreso'

  BudgetModel({
    required this.id,
    required this.year,
    required this.month,
    required this.category,
    required this.budgetedAmount,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'month': month,
      'category': category,
      'budgetedAmount': budgetedAmount,
      'type': type,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map, String docId) {
    return BudgetModel(
      id: docId,
      year: map['year'] ?? DateTime.now().year,
      month: map['month'] ?? DateTime.now().month,
      category: map['category'] ?? '',
      budgetedAmount: (map['budgetedAmount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] ?? 'egreso',
    );
  }
}
