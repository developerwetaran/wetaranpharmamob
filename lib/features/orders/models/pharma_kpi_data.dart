class PharmaKpiData {
  final int pendingCount;
  final double pendingAmount;
  final double totalPurchaseThisMonth;
  final double totalPurchaseLastMonth;

  const PharmaKpiData({
    required this.pendingCount,
    required this.pendingAmount,
    required this.totalPurchaseThisMonth,
    required this.totalPurchaseLastMonth,
  });

  double? get growthPercent {
    if (totalPurchaseLastMonth == 0) return null;
    return ((totalPurchaseThisMonth - totalPurchaseLastMonth) /
            totalPurchaseLastMonth) *
        100;
  }

  bool get isGrowthPositive => (growthPercent ?? 0) >= 0;

  String get totalPurchaseFormatted => _formatLakh(totalPurchaseThisMonth);

  static String _formatLakh(double value) {
    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)}L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }
    return '₹${value.toStringAsFixed(0)}';
  }
}
