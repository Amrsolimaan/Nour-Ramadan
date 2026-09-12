import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════
//  FavoritesService — خدمة حفظ المفضلات محلياً
// ════════════════════════════════════════════════════════════════

class FavoritesService {
  static const String _keyDuas = 'favorites_duas';
  static const String _keyLaylatQadr = 'favorites_laylat_qadr';
  static const String _keyHadiths = 'favorites_hadiths';

  // ══════════════════════════════════════════════════════════════
  //  حفظ وقراءة المفضلات
  // ══════════════════════════════════════════════════════════════

  /// حفظ قائمة المفضلات للأدعية
  static Future<void> saveDuaFavorites(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDuas, jsonEncode(favorites.toList()));
  }

  /// قراءة قائمة المفضلات للأدعية
  static Future<Set<String>> loadDuaFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyDuas);
    if (json == null) return {};
    final list = jsonDecode(json) as List<dynamic>;
    return Set<String>.from(list);
  }

  /// حفظ قائمة المفضلات لليلة القدر
  static Future<void> saveLaylatQadrFavorites(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLaylatQadr, jsonEncode(favorites.toList()));
  }

  /// قراءة قائمة المفضلات لليلة القدر
  static Future<Set<String>> loadLaylatQadrFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyLaylatQadr);
    if (json == null) return {};
    final list = jsonDecode(json) as List<dynamic>;
    return Set<String>.from(list);
  }

  // ══════════════════════════════════════════════════════════════
  //  إضافة وحذف مفضلة
  // ══════════════════════════════════════════════════════════════

  /// إضافة/حذف دعاء من المفضلات
  static Future<bool> toggleDuaFavorite(String duaId) async {
    final favorites = await loadDuaFavorites();
    if (favorites.contains(duaId)) {
      favorites.remove(duaId);
      await saveDuaFavorites(favorites);
      return false;
    } else {
      favorites.add(duaId);
      await saveDuaFavorites(favorites);
      return true;
    }
  }

  /// إضافة/حذف دعاء ليلة القدر من المفضلات
  static Future<bool> toggleLaylatQadrFavorite(String itemId) async {
    final favorites = await loadLaylatQadrFavorites();
    if (favorites.contains(itemId)) {
      favorites.remove(itemId);
      await saveLaylatQadrFavorites(favorites);
      return false;
    } else {
      favorites.add(itemId);
      await saveLaylatQadrFavorites(favorites);
      return true;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  التحقق من المفضلات
  // ══════════════════════════════════════════════════════════════

  /// التحقق إذا كان الدعاء في المفضلات
  static Future<bool> isDuaFavorite(String duaId) async {
    final favorites = await loadDuaFavorites();
    return favorites.contains(duaId);
  }

  /// التحقق إذا كان دعاء ليلة القدر في المفضلات
  static Future<bool> isLaylatQadrFavorite(String itemId) async {
    final favorites = await loadLaylatQadrFavorites();
    return favorites.contains(itemId);
  }

  // ══════════════════════════════════════════════════════════════
  //  مسح جميع المفضلات
  // ══════════════════════════════════════════════════════════════

  /// مسح جميع مفضلات الأدعية
  static Future<void> clearDuaFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDuas);
  }

  /// مسح جميع مفضلات ليلة القدر
  static Future<void> clearLaylatQadrFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLaylatQadr);
  }

  // ══════════════════════════════════════════════════════════════
  //  الأحاديث
  // ══════════════════════════════════════════════════════════════

  static Future<Set<String>> loadHadithFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyHadiths);
    if (json == null) return {};
    final list = jsonDecode(json) as List<dynamic>;
    return Set<String>.from(list);
  }

  static Future<void> saveHadithFavorites(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHadiths, jsonEncode(favorites.toList()));
  }

  static Future<bool> toggleHadithFavorite(String hadithId) async {
    final favorites = await loadHadithFavorites();
    if (favorites.contains(hadithId)) {
      favorites.remove(hadithId);
      await saveHadithFavorites(favorites);
      return false;
    } else {
      favorites.add(hadithId);
      await saveHadithFavorites(favorites);
      return true;
    }
  }

  static Future<void> clearHadithFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHadiths);
  }
}
