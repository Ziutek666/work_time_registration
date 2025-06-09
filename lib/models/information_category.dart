import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InformationCategory {
  final String categoryId;
  final String projectId;
  final String name;
  final int iconCodePoint;
  final String iconFontFamily;
  final Color color;

  const InformationCategory({
    required this.categoryId,
    required this.projectId,
    required this.name,
    required this.iconCodePoint,
    required this.iconFontFamily,
    required this.color,
  });

  IconData get iconData => IconData(iconCodePoint, fontFamily: iconFontFamily);

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'colorValue': color.value,
    };
  }

  factory InformationCategory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return InformationCategory(
      categoryId: doc.id,
      projectId: data['projectId'] as String? ?? '',
      name: data['name'] ?? 'Bez nazwy',
      iconCodePoint: data['iconCodePoint'] ?? Icons.help_outline.codePoint,
      iconFontFamily: data['iconFontFamily'] ?? 'MaterialIcons',
      color: Color(data['colorValue'] ?? Colors.grey.value),
    );
  }

  InformationCategory copyWith({
    String? categoryId,
    String? projectId,
    String? name,
    int? iconCodePoint,
    String? iconFontFamily,
    Color? color,
  }) {
    return InformationCategory(
      categoryId: categoryId ?? this.categoryId,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      color: color ?? this.color,
    );
  }

  // --- NOWA LOGIKA PORÓWNYWANIA OBIEKTÓW ---

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InformationCategory &&
        other.categoryId == categoryId;
  }

  @override
  int get hashCode => categoryId.hashCode;

}