import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ════════════════════════════════════════════════════════════════
//  LaylatQadrState
// ════════════════════════════════════════════════════════════════
class LaylatQadrState {
  const LaylatQadrState({
    this.isLoading = true,
    this.error,
  });

  final bool isLoading;
  final String? error;

  LaylatQadrState copyWith({bool? isLoading, String? error}) {
    return LaylatQadrState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  LaylatQadrItem
// ════════════════════════════════════════════════════════════════
class LaylatQadrItem {
  const LaylatQadrItem({
    required this.category,
    required this.zekr,
    required this.description,
    required this.count,
    required this.reference,
    required this.search,
  });

  final String category;
  final String zekr;
  final String description;
  final int count;
  final String reference;
  final String search;

  factory LaylatQadrItem.fromJson(List<dynamic> row) {
    return LaylatQadrItem(
      category: row[0] as String,
      zekr: row[1] as String,
      description: row[2] as String,
      count: row[3] as int,
      reference: row[4] as String,
      search: row[5] as String,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  LaylatQadrNotifier
// ════════════════════════════════════════════════════════════════
class LaylatQadrNotifier extends StateNotifier<LaylatQadrState> {
  LaylatQadrNotifier() : super(const LaylatQadrState()) {
    _load();
  }

  List<LaylatQadrItem> _items = [];

  Future<void> _load() async {
    try {
      print('🔄 بدء تحميل laila_qadr.json');
      final jsonStr = await rootBundle.loadString('assets/azkar/laila_qadr.json');
      print('✅ تم قراءة الملف بنجاح');
      
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final rows = data['rows'] as List<dynamic>;
      print('📊 عدد الصفوف: ${rows.length}');

      _items = rows.map((row) => LaylatQadrItem.fromJson(row as List<dynamic>)).toList();
      print('✅ تم تحويل ${_items.length} عنصر');

      state = state.copyWith(isLoading: false);
    } catch (e) {
      print('❌ خطأ في التحميل: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  List<LaylatQadrItem> get items => _items;
}

// ════════════════════════════════════════════════════════════════
//  Providers
// ════════════════════════════════════════════════════════════════
final laylatQadrProvider = StateNotifierProvider<LaylatQadrNotifier, LaylatQadrState>((ref) {
  print('🚀 إنشاء LaylatQadrNotifier');
  return LaylatQadrNotifier();
});

final laylatQadrContentProvider = Provider<Map<String, List<LaylatQadrItem>>>((ref) {
  final state = ref.watch(laylatQadrProvider);
  final notifier = ref.read(laylatQadrProvider.notifier);
  
  print('📦 laylatQadrContentProvider - isLoading: ${state.isLoading}, items: ${notifier.items.length}');
  
  if (state.isLoading) return {};
  
  final items = notifier.items;
  final grouped = <String, List<LaylatQadrItem>>{};
  
  for (final item in items) {
    grouped.putIfAbsent(item.category, () => []).add(item);
  }
  
  print('✅ تم تجميع ${grouped.length} فئة');
  return grouped;
});
