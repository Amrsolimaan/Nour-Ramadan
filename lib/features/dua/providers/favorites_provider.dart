import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/favorites_service.dart';

// ════════════════════════════════════════════════════════════════
//  FavoritesNotifier — إدارة المفضلات للأدعية
// ════════════════════════════════════════════════════════════════

class DuaFavoritesNotifier extends StateNotifier<Set<String>> {
  DuaFavoritesNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    state = await FavoritesService.loadDuaFavorites();
  }

  /// إضافة/حذف دعاء من المفضلات
  Future<void> toggle(String duaId) async {
    final isFavorite = await FavoritesService.toggleDuaFavorite(duaId);
    if (isFavorite) {
      state = {...state, duaId};
    } else {
      state = state.where((id) => id != duaId).toSet();
    }
  }

  /// التحقق إذا كان الدعاء في المفضلات
  bool isFavorite(String duaId) => state.contains(duaId);

  /// مسح جميع المفضلات
  Future<void> clearAll() async {
    await FavoritesService.clearDuaFavorites();
    state = {};
  }
}

// ════════════════════════════════════════════════════════════════
//  LaylatQadrFavoritesNotifier — إدارة المفضلات لليلة القدر
// ════════════════════════════════════════════════════════════════

class LaylatQadrFavoritesNotifier extends StateNotifier<Set<String>> {
  LaylatQadrFavoritesNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    state = await FavoritesService.loadLaylatQadrFavorites();
  }

  /// إضافة/حذف دعاء من المفضلات
  Future<void> toggle(String itemId) async {
    final isFavorite = await FavoritesService.toggleLaylatQadrFavorite(itemId);
    if (isFavorite) {
      state = {...state, itemId};
    } else {
      state = state.where((id) => id != itemId).toSet();
    }
  }

  /// التحقق إذا كان الدعاء في المفضلات
  bool isFavorite(String itemId) => state.contains(itemId);

  /// مسح جميع المفضلات
  Future<void> clearAll() async {
    await FavoritesService.clearLaylatQadrFavorites();
    state = {};
  }
}

// ════════════════════════════════════════════════════════════════
//  Providers
// ════════════════════════════════════════════════════════════════

/// Provider لمفضلات الأدعية
final duaFavoritesProvider =
    StateNotifierProvider<DuaFavoritesNotifier, Set<String>>(
  (ref) => DuaFavoritesNotifier(),
);

/// Provider لمفضلات ليلة القدر
final laylatQadrFavoritesProvider =
    StateNotifierProvider<LaylatQadrFavoritesNotifier, Set<String>>(
  (ref) => LaylatQadrFavoritesNotifier(),
);
