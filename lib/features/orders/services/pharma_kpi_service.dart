import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_kpi_data.dart';

class PharmaKpiService {
  PharmaKpiService._();
  static final PharmaKpiService instance = PharmaKpiService._();

  final _client = Supabase.instance.client;

  static const _pendingStatuses = ['booked'];
  static const _purchaseStatuses = ['approved', 'dispatched'];

  Future<PharmaKpiData> fetchMonthlyKpis(String pharmaUserId) async {
    final now = DateTime.now();

    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);

    final results = await Future.wait([
      _fetchOrders(
        pharmaUserId: pharmaUserId,
        from: startOfThisMonth,
        to: startOfNextMonth,
        statuses: _pendingStatuses,
      ),
      _fetchOrders(
        pharmaUserId: pharmaUserId,
        from: startOfThisMonth,
        to: startOfNextMonth,
        statuses: _purchaseStatuses,
      ),
      _fetchOrders(
        pharmaUserId: pharmaUserId,
        from: startOfLastMonth,
        to: startOfThisMonth,
        statuses: _purchaseStatuses,
      ),
    ]);

    final pendingRows = results[0];
    final thisMonthPurchaseRows = results[1];
    final lastMonthPurchaseRows = results[2];

    double sumAmount(List<Map<String, dynamic>> rows) => rows.fold<double>(
      0,
      (sum, row) => sum + ((row['total_amount'] as num?)?.toDouble() ?? 0),
    );

    return PharmaKpiData(
      pendingCount: pendingRows.length,
      pendingAmount: sumAmount(pendingRows),
      totalPurchaseThisMonth: sumAmount(thisMonthPurchaseRows),
      totalPurchaseLastMonth: sumAmount(lastMonthPurchaseRows),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchOrders({
    required String pharmaUserId,
    required DateTime from,
    required DateTime to,
    required List<String> statuses,
  }) async {
    final response = await _client
        .from('orders')
        .select('total_amount, status, order_date')
        .eq('pharma_user_id', pharmaUserId)
        .gte('order_date', from.toIso8601String())
        .lt('order_date', to.toIso8601String());

    final rows = List<Map<String, dynamic>>.from(response as List);

    return rows.where((row) {
      final status = (row['status'] as String?)?.toLowerCase() ?? '';
      return statuses.contains(status);
    }).toList();
  }
}
