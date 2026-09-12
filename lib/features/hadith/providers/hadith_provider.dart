import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hadith_collection.dart';
import '../repositories/hadith_repository.dart';

// ════════════════════════════════════════════════════════════════
//  Hadith State
// ════════════════════════════════════════════════════════════════
class HadithState {
  final List<Hadith> hadiths;
  final bool isLoading;
  final String? error;

  const HadithState({
    this.hadiths = const [],
    this.isLoading = false,
    this.error,
  });

  HadithState copyWith({
    List<Hadith>? hadiths,
    bool? isLoading,
    String? error,
  }) {
    return HadithState(
      hadiths: hadiths ?? this.hadiths,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Hadith Notifier
// ════════════════════════════════════════════════════════════════
class HadithNotifier extends StateNotifier<HadithState> {
  HadithNotifier() : super(const HadithState());

  final _repository = HadithRepository();

  Future<void> loadCollection(String collectionId) async {
    // ✅ فحص الـ cache أولاً - إذا موجود، ارجع البيانات فوراً بدون loading
    final cachedData = _repository.getCachedCollection(collectionId);
    
    if (cachedData != null && cachedData.isNotEmpty) {
      debugPrint('⚡ Cache hit! Returning ${cachedData.length} hadiths instantly (no loading)');
      state = state.copyWith(hadiths: cachedData, isLoading: false);
      return;
    }
    
    // فقط إذا لم يكن في cache، اعرض loading
    debugPrint('⏳ Cache miss - showing loading indicator');
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final hadiths = await _repository.loadCollection(collectionId);
      
      // Debug: Print loaded count
      debugPrint('✅ Loaded ${hadiths.length} hadiths for collection: $collectionId');
      
      state = state.copyWith(hadiths: hadiths, isLoading: false);
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading hadiths: $e');
      debugPrint('Stack trace: $stackTrace');
      
      state = state.copyWith(
        isLoading: false,
        error: 'فشل تحميل الأحاديث: ${e.toString()}',
      );
    }
  }

  void clearHadiths() {
    state = const HadithState();
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════
final hadithProvider = StateNotifierProvider<HadithNotifier, HadithState>(
  (ref) => HadithNotifier(),
);
