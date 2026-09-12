import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ════════════════════════════════════════════════════════════════
//  نموذج البيانات — Zekr
// ════════════════════════════════════════════════════════════════
class Zekr {
  final String category;
  final String zekr;
  final String description;
  final int count;
  final String reference;

  const Zekr({
    required this.category,
    required this.zekr,
    required this.description,
    required this.count,
    required this.reference,
  });

  /// تحليل من صف JSON [category, zekr, description, count, reference, search]
  factory Zekr.fromRow(List<dynamic> row) {
    return Zekr(
      category: (row[0] as String?)?.trim() ?? '',
      zekr: (row[1] as String?)?.trim() ?? '',
      description: (row[2] as String?)?.trim() ?? '',
      count: (row[3] is int)
          ? row[3] as int
          : int.tryParse(row[3]?.toString() ?? '') ?? 1,
      reference: (row[4] as String?)?.trim() ?? '',
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  تحديد تصنيفات الأذكار والأدعية
// ════════════════════════════════════════════════════════════════

/// فئات الأذكار (الشاشة الأولى)
const kAthkarCategories = [
  'أذكار الصباح',
  'أذكار المساء',
  'أذكار النوم',
  'أذكار الاستيقاظ من النوم',
];

/// أيقونات التبويبات
const kCategoryIcons = {
  'أذكار الصباح':           '🌅',
  'أذكار المساء':           '🌙',
  'أذكار النوم':            '😴',
  'أذكار الاستيقاظ من النوم': '☀️',
};

// ════════════════════════════════════════════════════════════════
//  حالة البيانات
// ════════════════════════════════════════════════════════════════
class AzkarState {
  final bool isLoading;
  final String? error;
  final Map<String, List<Zekr>> byCategory; // كل الأذكار مصنّفة

  const AzkarState({
    this.isLoading = true,
    this.error,
    this.byCategory = const {},
  });

  AzkarState copyWith({
    bool? isLoading,
    String? error,
    Map<String, List<Zekr>>? byCategory,
  }) {
    return AzkarState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      byCategory: byCategory ?? this.byCategory,
    );
  }

  /// الأذكار حسب فئة معينة
  List<Zekr> getCategory(String cat) => byCategory[cat] ?? [];

  /// جميع الأدعية (ما عدا فئات الأذكار)
  Map<String, List<Zekr>> get duas {
    return Map.fromEntries(
      byCategory.entries
          .where((e) => !kAthkarCategories.contains(e.key)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Notifier
// ════════════════════════════════════════════════════════════════
class AzkarNotifier extends StateNotifier<AzkarState> {
  AzkarNotifier() : super(const AzkarState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/azkar/azkar.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final rows = (json['rows'] as List<dynamic>);

      final map = <String, List<Zekr>>{};
      for (final row in rows) {
        final zekr = Zekr.fromRow(row as List<dynamic>);
        if (zekr.category.isEmpty || zekr.zekr.isEmpty) continue;
        // كل فئة بالاسم الرئيسي (قبل ' - ')
        final cat = zekr.category.split(' - ').first.trim();
        (map[cat] ??= []).add(
          Zekr(
            category: cat,
            zekr: zekr.zekr,
            description: zekr.description,
            count: zekr.count,
            reference: zekr.reference,
          ),
        );
      }

      state = AzkarState(isLoading: false, byCategory: map);
    } catch (e) {
      state = AzkarState(isLoading: false, error: e.toString());
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════
final azkarProvider = StateNotifierProvider<AzkarNotifier, AzkarState>(
  (ref) => AzkarNotifier(),
);

/// Provider مباشر لفئة معينة من الأذكار
final athkarCategoryProvider = Provider.family<List<Zekr>, String>(
  (ref, cat) => ref.watch(azkarProvider).getCategory(cat),
);

/// Provider لجميع الأدعية (مقسمة بالفئة)
final duasProvider = Provider<Map<String, List<Zekr>>>(
  (ref) => ref.watch(azkarProvider).duas,
);
