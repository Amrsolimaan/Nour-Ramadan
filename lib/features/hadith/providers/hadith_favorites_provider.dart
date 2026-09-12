import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/favorites_service.dart';

// ════════════════════════════════════════════════════════════════
//  HadithFavoritesNotifier — إدارة مفضلات الأحاديث
// ════════════════════════════════════════════════════════════════

class HadithFavoritesNotifier extends StateNotifier<Set<String>> {
  HadithFavoritesNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    state = await FavoritesService.loadHadithFavorites();
  }

  /// إضافة/حذف حديث من المفضلات
  Future<void> toggle(String hadithId) async {
    final isFav = await FavoritesService.toggleHadithFavorite(hadithId);
    if (isFav) {
      state = {...state, hadithId};
    } else {
      state = state.where((id) => id != hadithId).toSet();
    }
  }

  bool isFavorite(String hadithId) => state.contains(hadithId);

  Future<void> clearAll() async {
    await FavoritesService.clearHadithFavorites();
    state = {};
  }
}

/// Provider لمفضلات الأحاديث
final hadithFavoritesProvider =
    StateNotifierProvider<HadithFavoritesNotifier, Set<String>>(
      (ref) => HadithFavoritesNotifier(),
    );
