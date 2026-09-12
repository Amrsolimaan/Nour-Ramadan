import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/hadith_collection.dart';

// ════════════════════════════════════════════════════════════════
//  Hadith Repository — Singleton with Caching
// ════════════════════════════════════════════════════════════════
class HadithRepository {
  static final HadithRepository _instance = HadithRepository._internal();
  factory HadithRepository() => _instance;
  HadithRepository._internal();

  // Cache: collectionId -> List<Hadith>
  final Map<String, List<Hadith>> _cache = {};

  /// Get cached collection without loading
  List<Hadith>? getCachedCollection(String collectionId) {
    return _cache[collectionId];
  }

  /// Load hadiths for a specific collection
  Future<List<Hadith>> loadCollection(String collectionId) async {
    debugPrint('📚 HadithRepository.loadCollection called for: $collectionId');

    // Return from cache if available
    if (_cache.containsKey(collectionId)) {
      debugPrint(
        '✅ Cache hit! Returning ${_cache[collectionId]!.length} hadiths',
      );
      return _cache[collectionId]!;
    }

    debugPrint('⏳ Cache miss. Loading from JSON...');

    // Find collection metadata
    final collection = kHadithCollections.firstWhere(
      (c) => c.id == collectionId,
      orElse: () => throw Exception('Collection not found: $collectionId'),
    );

    debugPrint('📄 Loading file: ${collection.fileName}');

    // Load JSON in main isolate (rootBundle only works here)
    final jsonString = await rootBundle.loadString(
      'assets/ahadeth/${collection.fileName}',
    );
    debugPrint('📥 Loaded JSON string (${jsonString.length} chars)');

    // Parse JSON in isolate for better performance
    final hadiths = await compute(_parseHadithJson, {
      'jsonString': jsonString,
      'collectionId': collectionId,
    });

    debugPrint(
      '✅ Parsed ${hadiths.length} hadiths from ${collection.fileName}',
    );

    // Cache the result
    _cache[collectionId] = hadiths;
    return hadiths;
  }

  /// Clear cache for a specific collection
  void clearCache(String collectionId) {
    _cache.remove(collectionId);
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
  }
}

// ════════════════════════════════════════════════════════════════
//  Isolate Function — Parse JSON
// ════════════════════════════════════════════════════════════════
Future<List<Hadith>> _parseHadithJson(Map<String, String> params) async {
  final jsonString = params['jsonString']!;
  final collectionId = params['collectionId']!;

  debugPrint('🔧 [Isolate] Parsing JSON for $collectionId');

  final jsonData = json.decode(jsonString) as Map<String, dynamic>;
  debugPrint('🔍 [Isolate] JSON decoded. Keys: ${jsonData.keys.join(", ")}');

  // Parse based on collection type
  // Bukhari, Muslim, and Tirmidhi use metadata/sections format
  if (collectionId == 'bukhari' ||
      collectionId == 'muslim' ||
      collectionId == 'tirmidhi') {
    debugPrint('📖 [Isolate] Using Bukhari/Muslim/Tirmidhi format');
    return _parseBukhariMuslimFormat(jsonData);
  } 
  // All other collections (nasai, riyad, malik, ibnmajah, abudawud, qudsi40) use chapters format
  else {
    debugPrint('📘 [Isolate] Using Standard chapters format');
    return _parseStandardFormat(jsonData);
  }
}

// ════════════════════════════════════════════════════════════════
//  Parse Bukhari/Muslim Format
// ════════════════════════════════════════════════════════════════
List<Hadith> _parseBukhariMuslimFormat(Map<String, dynamic> jsonData) {
  final hadiths = <Hadith>[];
  final metadata = jsonData['metadata'] as Map<String, dynamic>?;
  final sections = metadata?['sections'] as Map<String, dynamic>? ?? {};
  final hadithsJson = jsonData['hadiths'] as List<dynamic>? ?? [];

  debugPrint(
    '📊 [Isolate] Bukhari/Muslim: ${hadithsJson.length} hadiths in JSON, ${sections.length} sections',
  );

  for (final hadithJson in hadithsJson) {
    final hadithMap = hadithJson as Map<String, dynamic>;
    final text = hadithMap['text'] as String? ?? '';

    // Skip empty hadiths
    if (text.trim().isEmpty) continue;

    // Find chapter name
    String? chapterName;
    final reference = hadithMap['reference'] as Map<String, dynamic>?;
    if (reference != null) {
      final bookNum = reference['book']?.toString() ?? '0';
      chapterName = sections[bookNum] as String?;
    }

    hadiths.add(Hadith.fromBukhariMuslim(hadithMap, chapterName));
  }

  debugPrint('✅ [Isolate] Bukhari/Muslim: Parsed ${hadiths.length} hadiths');
  return hadiths;
}

// ════════════════════════════════════════════════════════════════
//  Parse Standard Format (Nasai, Malik, Ibn Majah, Abu Dawud, etc.)
// ════════════════════════════════════════════════════════════════
List<Hadith> _parseStandardFormat(Map<String, dynamic> jsonData) {
  final hadiths = <Hadith>[];
  final chapters = jsonData['chapters'] as List<dynamic>? ?? [];
  final hadithsJson = jsonData['hadiths'] as List<dynamic>? ?? [];

  debugPrint(
    '📊 [Isolate] Standard: ${hadithsJson.length} hadiths in JSON, ${chapters.length} chapters',
  );

  // Build chapter map (skip chapters with null IDs)
  final chapterMap = <int, String>{};
  for (final chapterJson in chapters) {
    final chapter = chapterJson as Map<String, dynamic>;
    final id = chapter['id']; // May be null
    if (id != null && id is int) {
      final arabicName = chapter['arabic'] as String? ?? '';
      chapterMap[id] = arabicName;
    }
  }

  // Parse hadiths
  for (final hadithJson in hadithsJson) {
    final hadithMap = hadithJson as Map<String, dynamic>;
    final text = hadithMap['arabic'] as String? ?? '';

    // Skip empty hadiths
    if (text.trim().isEmpty) continue;

    // Get chapter name (chapterId قد يكون null)
    final chapterId = hadithMap['chapterId'] as int?;
    final chapterName = chapterId != null ? chapterMap[chapterId] : null;

    hadiths.add(Hadith.fromRiyad(hadithMap, chapterName));
  }

  debugPrint('✅ [Isolate] Standard: Parsed ${hadiths.length} hadiths');
  return hadiths;
}
