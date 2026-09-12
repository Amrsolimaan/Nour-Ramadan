import 'package:cloud_firestore/cloud_firestore.dart';

/// دعاء — يطابق Firestore collection: duas
class DuaModel {
  const DuaModel({
    required this.id,
    required this.text,
    required this.translation,
    required this.virtue,
    required this.source,
    required this.categoryId,
    required this.order,
    required this.readCount,
    required this.isPublished,
    required this.tags,
  });

  final String id;
  final String text;         // نص الدعاء بالعربية
  final String translation;  // الترجمة
  final String virtue;       // فضل الدعاء
  final String source;       // المصدر (مثل: صحيح البخاري)
  final String categoryId;   // معرّف التصنيف
  final int order;           // ترتيب العرض
  final int readCount;       // عدد مرات القراءة
  final bool isPublished;    // منشور أم لا
  final List<String> tags;   // وسوم (Array)

  factory DuaModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DuaModel(
      id: doc.id,
      text: data['text'] as String? ?? '',
      translation: data['translation'] as String? ?? '',
      virtue: data['virtue'] as String? ?? '',
      source: data['source'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      readCount: (data['readCount'] as num?)?.toInt() ?? 0,
      isPublished: data['isPublished'] as bool? ?? true,
      tags: List<String>.from(data['tags'] as List? ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'text': text,
    'translation': translation,
    'virtue': virtue,
    'source': source,
    'categoryId': categoryId,
    'order': order,
    'readCount': readCount,
    'isPublished': isPublished,
    'tags': tags,
  };

  DuaModel copyWith({int? readCount}) {
    return DuaModel(
      id: id,
      text: text,
      translation: translation,
      virtue: virtue,
      source: source,
      categoryId: categoryId,
      order: order,
      readCount: readCount ?? this.readCount,
      isPublished: isPublished,
      tags: tags,
    );
  }
}
