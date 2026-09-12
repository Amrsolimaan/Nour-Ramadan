import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ════════════════════════════════════════════════════════════════
//  App Logger — نظام Logging شامل
//  لتتبع جميع العمليات والأخطاء في التطبيق
// ════════════════════════════════════════════════════════════════

enum LogLevel {
  debug,   // معلومات تفصيلية للتطوير
  info,    // معلومات عامة
  warning, // تحذيرات
  error,   // أخطاء
  critical // أخطاء حرجة
}

enum LogCategory {
  azan,           // عمليات الأذان
  notification,   // الإشعارات
  location,       // الموقع
  permission,     // الأذونات
  prayer,         // أوقات الصلاة
  background,     // عمليات الخلفية
  boot,           // إعادة التشغيل
  battery,        // البطارية
  storage,        // التخزين
  ui,             // واجهة المستخدم
  system,         // النظام
  network,        // الشبكة
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final Map<String, dynamic>? data;
  final String? error;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.data,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'category': category.name,
    'message': message,
    if (data != null) 'data': data,
    if (error != null) 'error': error,
    if (stackTrace != null) 'stackTrace': stackTrace,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    timestamp: DateTime.parse(json['timestamp']),
    level: LogLevel.values.firstWhere((e) => e.name == json['level']),
    category: LogCategory.values.firstWhere((e) => e.name == json['category']),
    message: json['message'],
    data: json['data'],
    error: json['error'],
    stackTrace: json['stackTrace'],
  );

  String get emoji {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.critical:
        return '🔥';
    }
  }

  String get categoryEmoji {
    switch (category) {
      case LogCategory.azan:
        return '🕌';
      case LogCategory.notification:
        return '🔔';
      case LogCategory.location:
        return '📍';
      case LogCategory.permission:
        return '🔐';
      case LogCategory.prayer:
        return '🕋';
      case LogCategory.background:
        return '🌙';
      case LogCategory.boot:
        return '🔄';
      case LogCategory.battery:
        return '🔋';
      case LogCategory.storage:
        return '💾';
      case LogCategory.ui:
        return '🎨';
      case LogCategory.system:
        return '⚙️';
      case LogCategory.network:
        return '🌐';
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('$emoji $categoryEmoji [${level.name.toUpperCase()}] ');
    buffer.write('[${category.name}] ');
    buffer.write(message);
    if (data != null) {
      buffer.write(' | Data: $data');
    }
    if (error != null) {
      buffer.write(' | Error: $error');
    }
    return buffer.toString();
  }
}

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  static const String _prefsKey = 'app_logs';
  static const int _maxLogs = 500; // الحد الأقصى للسجلات المحفوظة
  static const int _maxLogAge = 7; // عدد الأيام للاحتفاظ بالسجلات

  final List<LogEntry> _logs = [];
  bool _initialized = false;

  // ════════════════════════════════════════════════════════════
  //  التهيئة
  // ════════════════════════════════════════════════════════════
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await _loadLogs();
      await _cleanOldLogs();
      _initialized = true;
      info(LogCategory.system, 'AppLogger initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize AppLogger: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  Logging Methods
  // ════════════════════════════════════════════════════════════
  
  void debug(LogCategory category, String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.debug, category, message, data: data);
  }

  void info(LogCategory category, String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.info, category, message, data: data);
  }

  void warning(LogCategory category, String message, {Map<String, dynamic>? data}) {
    _log(LogLevel.warning, category, message, data: data);
  }

  void error(
    LogCategory category,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      category,
      message,
      data: data,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );
  }

  void critical(
    LogCategory category,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.critical,
      category,
      message,
      data: data,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  Internal Logging
  // ════════════════════════════════════════════════════════════
  void _log(
    LogLevel level,
    LogCategory category,
    String message, {
    Map<String, dynamic>? data,
    String? error,
    String? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.add(entry);
    
    // طباعة في Console
    debugPrint(entry.toString());
    
    // حفظ في SharedPreferences (async)
    _saveLogs();
    
    // تنظيف السجلات القديمة إذا تجاوزت الحد
    if (_logs.length > _maxLogs) {
      _logs.removeRange(0, _logs.length - _maxLogs);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  Storage
  // ════════════════════════════════════════════════════════════
  Future<void> _saveLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = _logs.map((log) => log.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(logsJson));
    } catch (e) {
      debugPrint('❌ Failed to save logs: $e');
    }
  }

  Future<void> _loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsString = prefs.getString(_prefsKey);
      
      if (logsString != null) {
        final logsJson = jsonDecode(logsString) as List;
        _logs.clear();
        _logs.addAll(
          logsJson.map((json) => LogEntry.fromJson(json)).toList(),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to load logs: $e');
    }
  }

  Future<void> _cleanOldLogs() async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: _maxLogAge));
      _logs.removeWhere((log) => log.timestamp.isBefore(cutoffDate));
      await _saveLogs();
    } catch (e) {
      debugPrint('❌ Failed to clean old logs: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  //  Query Methods
  // ════════════════════════════════════════════════════════════
  List<LogEntry> getLogs({
    LogLevel? level,
    LogCategory? category,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _logs.where((log) {
      if (level != null && log.level != level) return false;
      if (category != null && log.category != category) return false;
      if (startDate != null && log.timestamp.isBefore(startDate)) return false;
      if (endDate != null && log.timestamp.isAfter(endDate)) return false;
      return true;
    }).toList();
  }

  List<LogEntry> getRecentLogs({int count = 50}) {
    final startIndex = _logs.length > count ? _logs.length - count : 0;
    return _logs.sublist(startIndex);
  }

  List<LogEntry> getErrorLogs() {
    return _logs.where((log) => 
      log.level == LogLevel.error || log.level == LogLevel.critical
    ).toList();
  }

  List<LogEntry> getCategoryLogs(LogCategory category) {
    return _logs.where((log) => log.category == category).toList();
  }

  // ════════════════════════════════════════════════════════════
  //  Statistics
  // ════════════════════════════════════════════════════════════
  Map<LogLevel, int> getLogCountByLevel() {
    final counts = <LogLevel, int>{};
    for (final level in LogLevel.values) {
      counts[level] = _logs.where((log) => log.level == level).length;
    }
    return counts;
  }

  Map<LogCategory, int> getLogCountByCategory() {
    final counts = <LogCategory, int>{};
    for (final category in LogCategory.values) {
      counts[category] = _logs.where((log) => log.category == category).length;
    }
    return counts;
  }

  int get totalLogs => _logs.length;
  int get errorCount => _logs.where((log) => 
    log.level == LogLevel.error || log.level == LogLevel.critical
  ).length;

  // ════════════════════════════════════════════════════════════
  //  Export
  // ════════════════════════════════════════════════════════════
  String exportLogsAsText() {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════════════════');
    buffer.writeln('App Logs Export');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Total Logs: ${_logs.length}');
    buffer.writeln('═══════════════════════════════════════════════════\n');

    for (final log in _logs) {
      buffer.writeln('─────────────────────────────────────────────────');
      buffer.writeln('Time: ${log.timestamp}');
      buffer.writeln('Level: ${log.level.name.toUpperCase()}');
      buffer.writeln('Category: ${log.category.name}');
      buffer.writeln('Message: ${log.message}');
      if (log.data != null) {
        buffer.writeln('Data: ${log.data}');
      }
      if (log.error != null) {
        buffer.writeln('Error: ${log.error}');
      }
      if (log.stackTrace != null) {
        buffer.writeln('Stack Trace:\n${log.stackTrace}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  String exportLogsAsJson() {
    final logsJson = _logs.map((log) => log.toJson()).toList();
    return jsonEncode({
      'exportDate': DateTime.now().toIso8601String(),
      'totalLogs': _logs.length,
      'logs': logsJson,
    });
  }

  // ════════════════════════════════════════════════════════════
  //  Clear
  // ════════════════════════════════════════════════════════════
  Future<void> clearLogs() async {
    _logs.clear();
    await _saveLogs();
    info(LogCategory.system, 'All logs cleared');
  }

  Future<void> clearOldLogs({int days = 7}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final removedCount = _logs.length;
    _logs.removeWhere((log) => log.timestamp.isBefore(cutoffDate));
    final remainingCount = _logs.length;
    await _saveLogs();
    info(
      LogCategory.system,
      'Cleared ${removedCount - remainingCount} old logs (older than $days days)',
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Global Logger Instance
// ════════════════════════════════════════════════════════════════
final logger = AppLogger();
