import 'package:cloud_firestore/cloud_firestore.dart';

// ════════════════════════════════════════════════════════════════
//  AppMessage — نموذج الرسالة من Firebase
// ════════════════════════════════════════════════════════════════

enum MessageType {
  info,
  announcement,
  update,
  help;

  String get label {
    switch (this) {
      case MessageType.info:
        return 'معلومة';
      case MessageType.announcement:
        return 'إعلان';
      case MessageType.update:
        return 'تحديث';
      case MessageType.help:
        return 'مساعدة';
    }
  }

  String get emoji {
    switch (this) {
      case MessageType.info:
        return '';
      case MessageType.announcement:
        return '';
      case MessageType.update:
        return '';
      case MessageType.help:
        return '';
    }
  }
}

class AppMessage {
  const AppMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.type = MessageType.info,
    this.icon,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final MessageType type;
  final String? icon;
  final bool isActive;

  factory AppMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppMessage(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: _parseType(data['type']),
      icon: data['icon'],
      isActive: data['isActive'] ?? true,
    );
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

  String get displayIcon => icon ?? type.emoji;
}
