import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════
//  Remote Config Service — خدمة Firebase Remote Config
// ════════════════════════════════════════════════════════════════

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  FirebaseRemoteConfig? _remoteConfig;
  static const String _websiteUrlKey = 'privacy_policy_website_url';
  static const String _cachedUrlKey = 'cached_website_url';
  static const String _defaultUrl = 'https://code-zeen.vercel.app/en';

  /// تهيئة Remote Config
  Future<void> initialize() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      
      // إعدادات Remote Config
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(minutes: 1), // للتحديث السريع
        ),
      );

      // القيم الافتراضية
      await _remoteConfig!.setDefaults(const {
        _websiteUrlKey: _defaultUrl,
      });

      // جلب القيم من Firebase
      await _remoteConfig!.fetchAndActivate();
      
      // حفظ القيمة محلياً
      final url = _remoteConfig!.getString(_websiteUrlKey);
      await _cacheUrl(url);
      
      debugPrint('✅ Remote Config initialized successfully');
      debugPrint('📍 Website URL: $url');
    } catch (e) {
      debugPrint('❌ Error initializing Remote Config: $e');
    }
  }

  /// الحصول على رابط الموقع
  Future<String> getWebsiteUrl() async {
    try {
      // محاولة الحصول على القيمة من Remote Config
      if (_remoteConfig != null) {
        await _remoteConfig!.fetchAndActivate();
        final url = _remoteConfig!.getString(_websiteUrlKey);
        
        if (url.isNotEmpty && url != _defaultUrl) {
          // حفظ القيمة الجديدة محلياً
          await _cacheUrl(url);
          debugPrint('🔄 Updated website URL from Firebase: $url');
          return url;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching from Remote Config: $e');
    }

    // إذا فشل، استخدم القيمة المحفوظة محلياً
    final cachedUrl = await _getCachedUrl();
    if (cachedUrl != null) {
      debugPrint('📦 Using cached URL: $cachedUrl');
      return cachedUrl;
    }

    // إذا لم يوجد شيء، استخدم الافتراضي
    debugPrint('🔧 Using default URL: $_defaultUrl');
    return _defaultUrl;
  }

  /// حفظ الرابط محلياً
  Future<void> _cacheUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedUrlKey, url);
    } catch (e) {
      debugPrint('❌ Error caching URL: $e');
    }
  }

  /// الحصول على الرابط المحفوظ محلياً
  Future<String?> _getCachedUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cachedUrlKey);
    } catch (e) {
      debugPrint('❌ Error getting cached URL: $e');
      return null;
    }
  }

  /// الاستماع للتحديثات الفورية
  void listenToUpdates(Function(String) onUpdate) {
    if (_remoteConfig == null) return;

    _remoteConfig!.onConfigUpdated.listen((event) async {
      await _remoteConfig!.activate();
      final url = _remoteConfig!.getString(_websiteUrlKey);
      await _cacheUrl(url);
      onUpdate(url);
      debugPrint('🔔 Remote Config updated! New URL: $url');
    });
  }
}
