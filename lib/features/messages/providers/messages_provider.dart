import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_message.dart';
import 'dart:async';

// ════════════════════════════════════════════════════════════════
//  MessagesState — حالة الرسائل
// ════════════════════════════════════════════════════════════════

enum MessageLoadingState {
  initial,    // أول مرة
  cached,     // محمّل من الكاش
  syncing,    // يزامن في الخلفية
  error,      // خطأ
  offline,    // بدون نت
}

class MessagesState {
  const MessagesState({
    this.messages = const [],
    this.loadingState = MessageLoadingState.initial,
    this.error,
    this.unreadCount = 0,
    this.selectedFilter,
    this.displayedCount = 30,
    this.hasMore = false,
  });

  final List<AppMessage> messages;
  final MessageLoadingState loadingState;
  final String? error;
  final int unreadCount;
  final MessageType? selectedFilter;
  final int displayedCount; // عدد الرسائل المعروضة حالياً
  final bool hasMore; // هل يوجد المزيد للتحميل

  bool get isLoading => loadingState == MessageLoadingState.initial;
  bool get hasError => error != null;
  bool get isOffline => loadingState == MessageLoadingState.offline;

  // الرسائل المفلترة حسب النوع المختار
  List<AppMessage> get filteredMessages {
    final filtered = selectedFilter == null 
        ? messages 
        : messages.where((m) => m.type == selectedFilter).toList();
    
    // إرجاع فقط العدد المطلوب (pagination)
    return filtered.take(displayedCount).toList();
  }

  MessagesState copyWith({
    List<AppMessage>? messages,
    MessageLoadingState? loadingState,
    String? error,
    int? unreadCount,
    MessageType? selectedFilter,
    bool clearFilter = false,
    int? displayedCount,
    bool? hasMore,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      loadingState: loadingState ?? this.loadingState,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
      selectedFilter: clearFilter ? null : (selectedFilter ?? this.selectedFilter),
      displayedCount: displayedCount ?? this.displayedCount,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  MessagesNotifier
// ════════════════════════════════════════════════════════════════

class MessagesNotifier extends StateNotifier<MessagesState> {
  MessagesNotifier() : super(const MessagesState()) {
    _init();
  }

  static const _boxName = 'deleted_messages';
  static const _cacheBoxName = 'messages_cache';
  static const _readBoxName = 'read_messages';
  Box<String>? _deletedBox;
  Box<Map>? _cacheBox;
  Box<String>? _readBox;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  Timer? _timeoutTimer;

  Future<void> _init() async {
    try {
      // فتح صناديق Hive
      _deletedBox = await Hive.openBox<String>(_boxName);
      _cacheBox = await Hive.openBox<Map>(_cacheBoxName);
      _readBox = await Hive.openBox<String>(_readBoxName);
      
      // تحميل من الكاش أولاً (فوري)
      final hasCachedData = _loadFromCache();
      
      // إذا وجد كاش → عرض فوري
      if (hasCachedData) {
        state = state.copyWith(loadingState: MessageLoadingState.cached);
      }
      
      // ثم الاستماع للتحديثات من Firebase (في الخلفية)
      _setupRealtimeListener();
    } catch (e) {
      state = state.copyWith(
        loadingState: MessageLoadingState.error,
        error: 'فشل تحميل الرسائل',
      );
    }
  }

  // ── تحميل من الكاش المحلي ─────────────────────────────────────
  bool _loadFromCache() {
    try {
      final cachedData = _cacheBox?.values.toList() ?? [];
      if (cachedData.isEmpty) return false;

      final deletedIds = _deletedBox?.values.toSet() ?? {};
      
      final messages = cachedData
          .map((data) {
            try {
              return AppMessage(
                id: data['id'] ?? '',
                title: data['title'] ?? '',
                body: data['body'] ?? '',
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                  data['timestamp'] ?? 0,
                ),
                type: _parseType(data['type']),
                icon: data['icon'],
                isActive: data['isActive'] ?? true,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<AppMessage>()
          .where((msg) => !deletedIds.contains(msg.id))
          .toList();

      if (messages.isEmpty) return false;

      // ترتيب حسب التاريخ
      messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final readIds = _getReadMessageIds();
      final unreadCount = messages.where((m) => !readIds.contains(m.id)).length;

      // ✅ إصلاح: عدم عرض unreadCount إذا كانت جميع الرسائل مقروءة
      state = state.copyWith(
        messages: messages,
        loadingState: MessageLoadingState.cached,
        unreadCount: unreadCount > 0 ? unreadCount : 0,
      );
      
      return true;
    } catch (e) {
      print('خطأ في تحميل الكاش: $e');
      return false;
    }
  }

  // ── الاستماع للتحديثات الفورية من Firebase ─────────────────────
  void _setupRealtimeListener() {
    // إلغاء أي timeout سابق
    _timeoutTimer?.cancel();
    
    // تعيين timeout فقط للتحميل الأولي (30 ثانية)
    if (state.loadingState == MessageLoadingState.initial) {
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (state.loadingState == MessageLoadingState.initial) {
          // إذا لم يتم التحميل بعد 30 ثانية → خطأ
          state = state.copyWith(
            loadingState: MessageLoadingState.offline,
            error: 'تحقق من الاتصال بالإنترنت',
          );
        }
      });
    }

    _messagesSubscription = FirebaseFirestore.instance
        .collection('messages')
        .where('isActive', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _timeoutTimer?.cancel();
            _handleMessagesUpdate(snapshot);
          },
          onError: (error) {
            _timeoutTimer?.cancel();
            print('خطأ في الاستماع للرسائل: $error');
            
            // فقط عرض الخطأ إذا لم يكن هناك رسائل محملة
            // إذا كان هناك رسائل → تجاهل الخطأ واستمر في عرض الكاش
            if (state.messages.isEmpty) {
              state = state.copyWith(
                loadingState: MessageLoadingState.error,
                error: _getErrorMessage(error),
              );
            } else {
              // لا تعرض رسالة خطأ، فقط استمر في عرض الكاش
              print('⚠️ خطأ في المزامنة لكن الكاش متوفر، تجاهل الخطأ');
            }
          },
        );
  }

  // ── معالجة تحديث الرسائل ──────────────────────────────────────
  void _handleMessagesUpdate(QuerySnapshot snapshot) {
    try {
      final deletedIds = _deletedBox?.values.toSet() ?? {};
      
      // تحويل وحفظ في الكاش
      final messages = <AppMessage>[];
      for (final doc in snapshot.docs) {
        final message = AppMessage.fromFirestore(doc);
        if (!deletedIds.contains(message.id)) {
          messages.add(message);
          
          // حفظ في الكاش
          _cacheBox?.put(message.id, {
            'id': message.id,
            'title': message.title,
            'body': message.body,
            'timestamp': message.timestamp.millisecondsSinceEpoch,
            'type': message.type.name,
            'icon': message.icon,
            'isActive': message.isActive,
          });
        }
      }

      // حساب عدد الرسائل غير المقروءة
      final readIds = _getReadMessageIds();
      final unreadCount = messages.where((m) => !readIds.contains(m.id)).length;
      
      // تحديد هل يوجد المزيد
      final hasMore = messages.length > state.displayedCount;

      state = state.copyWith(
        messages: messages,
        loadingState: MessageLoadingState.cached,
        error: null,
        unreadCount: unreadCount,
        hasMore: hasMore,
      );
    } catch (e) {
      print('خطأ في معالجة التحديث: $e');
    }
  }

  // ── تحويل رسالة الخطأ لنص مفهوم ────────────────────────────────
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('permission-denied')) {
      return 'لا توجد صلاحية للوصول';
    } else if (errorStr.contains('failed-precondition')) {
      return 'يرجى إنشاء الفهرس في Firebase';
    } else if (errorStr.contains('unavailable')) {
      return 'تحقق من الاتصال بالإنترنت';
    } else {
      return 'حدث خطأ، يرجى المحاولة لاحقاً';
    }
  }

  static MessageType _parseType(dynamic value) {
    if (value == null) return MessageType.info;
    switch (value.toString().toLowerCase()) {
      case 'announcement':
        return MessageType.announcement;
      case 'update':
        return MessageType.update;
      case 'help':
        return MessageType.help;
      default:
        return MessageType.info;
    }
  }

  // ── حذف رسالة (محلياً فقط) ────────────────────────────────────
  Future<void> deleteMessage(String messageId) async {
    try {
      await _deletedBox?.put(messageId, messageId);
      await _cacheBox?.delete(messageId);
      
      final updatedMessages = state.messages
          .where((m) => m.id != messageId)
          .toList();
      
      final readIds = _getReadMessageIds();
      final unreadCount = updatedMessages.where((m) => !readIds.contains(m.id)).length;

      state = state.copyWith(
        messages: updatedMessages,
        unreadCount: unreadCount,
      );
    } catch (e) {
      print('خطأ في حذف الرسالة: $e');
    }
  }

  // ── تحديد رسالة كمقروءة ───────────────────────────────────────
  Future<void> markAsRead(String messageId) async {
    // ✅ تحديث الحالة فوراً
    final readIds = _getReadMessageIds();
    readIds.add(messageId);
    
    final unreadCount = state.messages.where((m) => !readIds.contains(m.id)).length;
    state = state.copyWith(unreadCount: unreadCount);
    
    // ثم حفظ في Hive
    await _readBox?.put(messageId, messageId);
  }

  // ── تحديد جميع الرسائل كمقروءة ────────────────────────────────
  Future<void> markAllAsRead() async {
    // ✅ إصلاح: تحديث الحالة فوراً قبل حفظ البيانات
    state = state.copyWith(unreadCount: 0);
    
    // ثم حفظ في Hive
    for (final msg in state.messages) {
      await _readBox?.put(msg.id, msg.id);
    }
  }
  
  // ── تحديد الرسائل المعروضة حالياً كمقروءة ──────────────────────
  Future<void> markDisplayedAsRead() async {
    final displayedMessages = state.filteredMessages;
    
    // حفظ في Hive
    for (final msg in displayedMessages) {
      await _readBox?.put(msg.id, msg.id);
    }
    
    // إعادة حساب العدد
    final readIds = _getReadMessageIds();
    final unreadCount = state.messages.where((m) => !readIds.contains(m.id)).length;
    state = state.copyWith(unreadCount: unreadCount);
  }
  
  // ── تحميل المزيد من الرسائل ──────────────────────────────────
  void loadMore() {
    final newCount = state.displayedCount + 30;
    final totalFiltered = state.selectedFilter == null 
        ? state.messages.length 
        : state.messages.where((m) => m.type == state.selectedFilter).length;
    
    state = state.copyWith(
      displayedCount: newCount,
      hasMore: newCount < totalFiltered,
    );
  }

  // ── الحصول على معرفات الرسائل المقروءة ────────────────────────
  Set<String> _getReadMessageIds() {
    try {
      // استخدام الـ box المفتوح مسبقاً
      return _readBox?.values.toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  // ── الحصول على معرفات الرسائل المقروءة (public) ──────────────
  Set<String> getReadMessageIds() => _getReadMessageIds();

  // ── إعادة تحميل الرسائل يدوياً ─────────────────────────────────
  Future<void> refresh() async {
    // عرض حالة التحميل
    state = state.copyWith(
      loadingState: MessageLoadingState.syncing,
      error: null,
    );
    
    // إعادة الاتصال بـ Firebase
    _messagesSubscription?.cancel();
    _setupRealtimeListener();
    
    // انتظار قليلاً لإعطاء feedback بصري ثم إيقاف التحميل
    await Future.delayed(const Duration(milliseconds: 800));
    
    // إيقاف حالة التحميل بعد الانتظار
    if (state.loadingState == MessageLoadingState.syncing) {
      state = state.copyWith(
        loadingState: MessageLoadingState.cached,
      );
    }
  }

  // ── تغيير الفلتر ──────────────────────────────────────────────
  void setFilter(MessageType? type) {
    if (type == null) {
      state = state.copyWith(clearFilter: true, displayedCount: 30);
    } else {
      state = state.copyWith(selectedFilter: type, displayedCount: 30);
    }
    
    // إعادة حساب hasMore
    final totalFiltered = type == null 
        ? state.messages.length 
        : state.messages.where((m) => m.type == type).length;
    
    state = state.copyWith(hasMore: 30 < totalFiltered);
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }
}


// ════════════════════════════════════════════════════════════════
//  Provider
// ════════════════════════════════════════════════════════════════

final messagesProvider =
    StateNotifierProvider<MessagesNotifier, MessagesState>((ref) {
  return MessagesNotifier();
});
