// lib/features/orders/services/pharma_order_id_service.dart
// Adapted from Wetaran Ninja's OrderIdService for pharma (distributor-per-user context)
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DistributorOrderState {
  final String distributorId;
  final String prefix;
  final int counter;

  const _DistributorOrderState({
    required this.distributorId,
    required this.prefix,
    required this.counter,
  });

  Map<String, dynamic> toJson() => {
    'distributorId': distributorId,
    'prefix': prefix,
    'counter': counter,
  };

  factory _DistributorOrderState.fromJson(Map<String, dynamic> j) =>
      _DistributorOrderState(
        distributorId: j['distributorId'] as String,
        prefix: j['prefix'] as String? ?? '',
        counter: j['counter'] as int? ?? 0,
      );
}

class PharmaOrderIdService {
  static final _db = Supabase.instance.client;
  static final Map<String, _DistributorOrderState> _stateMap = {};
  static String? _activeDistributorId;

  static String? get activeDistributorId => _activeDistributorId;

  static _DistributorOrderState? get activeState =>
      _activeDistributorId != null ? _stateMap[_activeDistributorId] : null;

  static ({String prefix, int counter}) _parseTemplate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return (prefix: '', counter: 0);
    }
    final t = value.trim();
    final m = RegExp(r'^(.*?)(\d+)$').firstMatch(t);
    if (m == null) return (prefix: t, counter: 0);
    final prefix = m.group(1)!;
    final digitStr = m.group(2)!;
    final number = int.parse(digitStr);
    final looksLikeYear =
        digitStr.length == 4 && number >= 2000 && number <= 2099;
    if (looksLikeYear && prefix.isNotEmpty) return (prefix: t, counter: 0);
    return (prefix: prefix, counter: number);
  }

  static String buildOrderId(String prefix, int counter) =>
      '$prefix${counter.toString().padLeft(4, '0')}';

  static String get previewNextOrderId {
    final s = activeState;
    if (s == null) return '0001';
    return buildOrderId(s.prefix, s.counter + 1);
  }

  static Future<void> initForDistributors(List<String> distributorIds) async {
    _stateMap.clear();
    if (distributorIds.isEmpty) {
      _activeDistributorId = null;
      await _persistAll();
      return;
    }
    try {
      final rows = await _db
          .from('distributor')
          .select('id, order_id')
          .inFilter('id', distributorIds);
      for (final row in rows) {
        final id = row['id'] as String;
        final parsed = _parseTemplate(row['order_id'] as String?);
        _stateMap[id] = _DistributorOrderState(
          distributorId: id,
          prefix: parsed.prefix,
          counter: parsed.counter,
        );
      }
    } catch (e) {
      debugPrint('PharmaOrderIdService: fetch failed: $e');
    }
    for (final id in distributorIds) {
      _stateMap.putIfAbsent(
        id,
        () => _DistributorOrderState(distributorId: id, prefix: '', counter: 0),
      );
    }
    _activeDistributorId = distributorIds.first;
    await _persistAll();
  }

  static Future<void> setActiveDistributor(String distributorId) async {
    if (!_stateMap.containsKey(distributorId)) {
      await _fetchSingle(distributorId);
    }
    _activeDistributorId = distributorId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pharma_active_distributor_id', distributorId);
    await _persistAll();
  }

  static Future<String> reserveNextOrderId() async {
    final distId = _activeDistributorId;
    if (distId != null) {
      try {
        final result = await _db.rpc(
          'get_next_order_id',
          params: {'p_distributor_id': distId},
        );
        if (result != null && (result as String).trim().isNotEmpty) {
          final newId = result as String;
          final parsed = _parseTemplate(newId);
          _stateMap[distId] = _DistributorOrderState(
            distributorId: distId,
            prefix: parsed.prefix,
            counter: parsed.counter,
          );
          await _persistAll();
          debugPrint('PharmaOrderIdService: reserved $newId');
          return newId;
        }
      } catch (e) {
        debugPrint('PharmaOrderIdService: RPC failed, using local: $e');
      }
    }
    final current = distId != null ? _stateMap[distId] : null;
    final prefix = current?.prefix ?? '';
    final next = (current?.counter ?? 0) + 1;
    final id = buildOrderId(prefix, next);
    if (distId != null) {
      _stateMap[distId] = _DistributorOrderState(
        distributorId: distId,
        prefix: prefix,
        counter: next,
      );
    }
    await _persistAll();
    return id;
  }

  static Future<void> onOrderSaved(String orderId) async {
    final parsed = _parseTemplate(orderId);
    if (parsed.counter <= 0) return;
    final distId = _activeDistributorId;
    if (distId != null) {
      _stateMap[distId] = _DistributorOrderState(
        distributorId: distId,
        prefix: parsed.prefix,
        counter: parsed.counter,
      );
    }
    await _persistAll();
  }

  static Future<void> onDraftDeleted() async {
    final distId = _activeDistributorId;
    if (distId == null) return;
    try {
      final row = await _db
          .from('distributor')
          .select('order_id')
          .eq('id', distId)
          .maybeSingle();
      final parsed = _parseTemplate(row?['order_id'] as String?);
      _stateMap[distId] = _DistributorOrderState(
        distributorId: distId,
        prefix: parsed.prefix,
        counter: parsed.counter,
      );
      await _persistAll();
    } catch (e) {
      debugPrint('PharmaOrderIdService.onDraftDeleted failed: $e');
    }
  }

  static Future<void> _fetchSingle(String distributorId) async {
    try {
      final row = await _db
          .from('distributor')
          .select('id, order_id')
          .eq('id', distributorId)
          .maybeSingle();
      final parsed = _parseTemplate(row?['order_id'] as String?);
      _stateMap[distributorId] = _DistributorOrderState(
        distributorId: distributorId,
        prefix: parsed.prefix,
        counter: parsed.counter,
      );
    } catch (e) {
      debugPrint('PharmaOrderIdService: lazy fetch failed: $e');
      _stateMap[distributorId] = _DistributorOrderState(
        distributorId: distributorId,
        prefix: '',
        counter: 0,
      );
    }
  }

  static Future<void> _persistAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _stateMap.values.map((s) => s.toJson()).toList();
    await prefs.setString('pharma_order_id_state_map', jsonEncode(list));
    if (_activeDistributorId != null) {
      await prefs.setString(
        'pharma_active_distributor_id',
        _activeDistributorId!,
      );
    }
  }
}
