import 'package:cloud_firestore/cloud_firestore.dart';

/// تصنيف الأدعية — يطابق Firestore collection: dua_categories
class DuaCategoryModel {
  const DuaCategoryModel({
    required this.id,
    required this.nameAr,
    required this.icon,
    required this.color,
    required this.order,
    required this.isActive,
  });

  final String id;
  final String nameAr;  // الاسم بالعربية
  final String icon;    // اسم الأيقونة أو emoji
  final String color;   // لون hex مثل: #C8922A
  final int order;      // ترتيب العرض
  final bool isActive;  // يظهر في التطبيق؟

  factory DuaCategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DuaCategoryModel(
      id: doc.id,
      nameAr: data['nameAr'] as String? ?? '',
      icon: data['icon'] as String? ?? '🤲',
      color: data['color'] as String? ?? '#C8922A',
      order: (data['order'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'nameAr': nameAr,
    'icon': icon,
    'color': color,
    'order': order,
    'isActive': isActive,
  };
}
