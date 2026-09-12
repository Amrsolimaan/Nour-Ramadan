import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

// ════════════════════════════════════════════════════════════════
//  Data Model
// ════════════════════════════════════════════════════════════════
class TasbihItem {
  final String id;
  final String label;
  final int count;
  final int target;

  TasbihItem({
    required this.id,
    required this.label,
    required this.count,
    required this.target,
  });

  TasbihItem copyWith({
    String? label,
    int? count,
    int? target,
  }) {
    return TasbihItem(
      id: id,
      label: label ?? this.label,
      count: count ?? this.count,
      target: target ?? this.target,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'count': count,
      'target': target,
    };
  }

  factory TasbihItem.fromJson(Map<String, dynamic> json) {
    return TasbihItem(
      id: json['id'],
      label: json['label'],
      count: json['count'],
      target: json['target'],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  State
// ════════════════════════════════════════════════════════════════
class TasbihState {
  final List<TasbihItem> items;
  final int activeIndex;
  final int dailyTotal;
  final int monthlyTotal;
  final int totalCount; // ✅ إضافة الإجمالي الكلي
  final bool isLoading;

  TasbihState({
    required this.items,
    required this.activeIndex,
    required this.dailyTotal,
    required this.monthlyTotal,
    this.totalCount = 0, // ✅ القيمة الافتراضية
    this.isLoading = true,
  });

  TasbihItem get activeItem => items.isNotEmpty ? items[activeIndex] : 
      TasbihItem(id: '0', label: 'تحميل...', count: 0, target: 100);

  TasbihState copyWith({
    List<TasbihItem>? items,
    int? activeIndex,
    int? dailyTotal,
    int? monthlyTotal,
    int? totalCount, // ✅ إضافة للـ copyWith
    bool? isLoading,
  }) {
    return TasbihState(
      items: items ?? this.items,
      activeIndex: activeIndex ?? this.activeIndex,
      dailyTotal: dailyTotal ?? this.dailyTotal,
      monthlyTotal: monthlyTotal ?? this.monthlyTotal,
      totalCount: totalCount ?? this.totalCount, // ✅ إضافة للـ copyWith
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Notifier
// ════════════════════════════════════════════════════════════════
class TasbihNotifier extends StateNotifier<TasbihState> {
  TasbihNotifier()
      : super(TasbihState(
          items: [],
          activeIndex: 0,
          dailyTotal: 0,
          monthlyTotal: 0,
        )) {
    _init();
  }

  late Box _box;
  final _uuid = const Uuid();

  Future<void> _init() async {
    _box = await Hive.openBox('tasbih_box');
    
    // التحقق من تاريخ اليوم لتصفير العداد اليومي
    final lastDate = _box.get('last_date') as String?;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    int daily = _box.get('daily_total', defaultValue: 0);
    int monthly = _box.get('monthly_total', defaultValue: 0);
    int total = _box.get('total_count', defaultValue: 0); // ✅ تحميل الإجمالي

    if (lastDate != today) {
      daily = 0; // يوم جديد = عداد يومي جديد
      _box.put('daily_total', 0);
      _box.put('last_date', today);
      
      // التصفير الشهري إذا كان شهر جديد
      if (lastDate != null && lastDate.substring(0, 7) != today.substring(0, 7)) {
        monthly = 0;
        _box.put('monthly_total', 0);
      }
    }

    // تحميل القائمة
    final List<dynamic>? rawList = _box.get('items');
    List<TasbihItem> items = [];

    if (rawList == null || rawList.isEmpty) {
      // القيم الافتراضية
      items = [
        TasbihItem(id: _uuid.v4(), label: 'سبحان الله', count: 0, target: 33),
        TasbihItem(id: _uuid.v4(), label: 'الحمد لله', count: 0, target: 33),
        TasbihItem(id: _uuid.v4(), label: 'الله أكبر', count: 0, target: 33),
      ];
      _saveItems(items);
    } else {
      items = rawList.map((e) => TasbihItem.fromJson(Map<String, dynamic>.from(e))).toList();
    }

    state = TasbihState(
      items: items,
      activeIndex: 0,
      dailyTotal: daily,
      monthlyTotal: monthly,
      totalCount: total, // ✅ إضافة الإجمالي للـ state
      isLoading: false,
    );
  }

  Future<void> _saveItems(List<TasbihItem> items) async {
    final jsonList = items.map((e) => e.toJson()).toList();
    await _box.put('items', jsonList);
  }

  void setActive(int index) {
    if (index >= 0 && index < state.items.length) {
      state = state.copyWith(activeIndex: index);
    }
  }

  void increment() {
    if (state.isLoading || state.items.isEmpty) return;

    final updatedItems = [...state.items];
    final currentItem = updatedItems[state.activeIndex];
    
    // زيادة عداد الذكر المحدد
    if (currentItem.count < currentItem.target) {
       updatedItems[state.activeIndex] = currentItem.copyWith(
         count: currentItem.count + 1
       );
    } else {
       // وصل للهدف - يبدأ من جديد (دورة جديدة)
       updatedItems[state.activeIndex] = currentItem.copyWith(count: 1);
    }
    
    final newDaily = state.dailyTotal + 1;
    final newMonthly = state.monthlyTotal + 1;

    // حفظ التغييرات
    _saveItems(updatedItems);
    _box.put('daily_total', newDaily);
    _box.put('monthly_total', newMonthly);
    
    // حفظ الإجمالي الكلي
    final totalCount = _box.get('total_count', defaultValue: 0) as int;
    _box.put('total_count', totalCount + 1);

    state = state.copyWith(
      items: updatedItems,
      dailyTotal: newDaily,
      monthlyTotal: newMonthly,
      totalCount: totalCount + 1, // ✅ تحديث الإجمالي في الـ state
    );
  }

  void resetItem(String id) {
    final updatedItems = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(count: 0);
      }
      return item;
    }).toList();

    _saveItems(updatedItems);
    state = state.copyWith(items: updatedItems);
  }

  void addZekr(String label, int target) {
    final newItem = TasbihItem(
      id: _uuid.v4(),
      label: label,
      count: 0,
      target: target,
    );
    
    final updatedItems = [...state.items, newItem];
    _saveItems(updatedItems);
    
    state = state.copyWith(
      items: updatedItems,
      activeIndex: updatedItems.length - 1, // تفعيل العنصر الجديد
    );
  }

  void editZekr(String id, String newLabel, int newTarget) {
     final updatedItems = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(label: newLabel, target: newTarget);
      }
      return item;
    }).toList();

    _saveItems(updatedItems);
    state = state.copyWith(items: updatedItems);
  }

  void deleteZekr(String id) {
    if (state.items.length <= 1) return; // منع حذف آخر عنصر

    final indexToDelete = state.items.indexWhere((item) => item.id == id);
    if (indexToDelete == -1) return;

    final updatedItems = state.items.where((item) => item.id != id).toList();
    _saveItems(updatedItems);

    // تصحيح المؤشر النشط
    int newIndex = state.activeIndex;
    if (indexToDelete < state.activeIndex) {
      newIndex--;
    } else if (newIndex >= updatedItems.length) {
      newIndex = updatedItems.length - 1;
    }

    state = state.copyWith(items: updatedItems, activeIndex: newIndex);
  }
}

final tasbihProvider = StateNotifierProvider<TasbihNotifier, TasbihState>((ref) {
  return TasbihNotifier();
});
