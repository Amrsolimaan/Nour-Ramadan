import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ════════════════════════════════════════════════════════════════
//  FeaturesState — حالة الميزات فقط
// ════════════════════════════════════════════════════════════════

class FeaturesState {
  const FeaturesState({
    this.laylatQadrEnabled = true,
    this.isLoading = true,
  });

  final bool laylatQadrEnabled;
  final bool isLoading;

  FeaturesState copyWith({
    bool? laylatQadrEnabled,
    bool? isLoading,
  }) {
    return FeaturesState(
      laylatQadrEnabled: laylatQadrEnabled ?? this.laylatQadrEnabled,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  FeaturesNotifier
// ════════════════════════════════════════════════════════════════
class FeaturesNotifier extends StateNotifier<FeaturesState> {
  FeaturesNotifier() : super(const FeaturesState()) {
    _init();
  }

  static const _featuresCacheBoxName = 'features_cache_v1'; // كاش للميزات
  Box<Map>? _featuresCacheBox;
  StreamSubscription<DocumentSnapshot>? _featuresSubscription;

  Future<void> _init() async {
    try {
      _featuresCacheBox = await Hive.openBox<Map>(_featuresCacheBoxName);

      // تحميل الميزات من الكاش
      _loadFeaturesFromCache();

      // Stream للميزات من Firebase
      _setupFeaturesListener();

      state = state.copyWith(isLoading: false);
    } catch (e) {
      debugPrint('خطأ في تهيئة FeaturesNotifier: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  // ── تحميل الميزات من الكاش ─────────────────────────────────
  bool _loadFeaturesFromCache() {
    try {
      final cached = _featuresCacheBox?.get('features');
      if (cached == null) return false;

      final laylatQadrEnabled = cached['laylatQadrEnabled'] as bool? ?? true;

      state = state.copyWith(
        laylatQadrEnabled: laylatQadrEnabled,
      );

      debugPrint('✅ تم تحميل الميزات من الكاش: laylatQadr=$laylatQadrEnabled');
      return true;
    } catch (e) {
      debugPrint('خطأ في تحميل كاش الميزات: $e');
      return false;
    }
  }

  // ── Stream للميزات من Firebase ────────────────────────────────
  void _setupFeaturesListener() {
    _featuresSubscription?.cancel();

    _featuresSubscription = FirebaseFirestore.instance
        .collection('app_config')
        .doc('features')
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists) {
              debugPrint('⚠️ مستند features غير موجود، استخدام القيم الافتراضية');
              return;
            }
            _handleFeaturesUpdate(snapshot.data()!);
          },
          onError: (error) {
            debugPrint('خطأ في stream الميزات: $error');
          },
        );
  }

  // ── معالجة تحديث الميزات من Firebase ───────────────────────────
  void _handleFeaturesUpdate(Map<String, dynamic> data) {
    try {
      final laylatQadrEnabled = data['laylatQadrEnabled'] as bool? ?? true;

      // ✅ حفظ في الكاش
      _featuresCacheBox?.put('features', {
        'laylatQadrEnabled': laylatQadrEnabled,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // تحديث الحالة فوراً
      state = state.copyWith(
        laylatQadrEnabled: laylatQadrEnabled,
      );

      debugPrint('✅ تم تحديث الميزات: laylatQadr=$laylatQadrEnabled');
    } catch (e) {
      debugPrint('خطأ في معالجة تحديث الميزات: $e');
    }
  }

  @override
  void dispose() {
    _featuresSubscription?.cancel();
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════
final featuresProvider =
    StateNotifierProvider<FeaturesNotifier, FeaturesState>((ref) {
  return FeaturesNotifier();
});
