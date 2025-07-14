import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum ScheduleTargetType {
  user,
  workType,
  area,
  qrCode,
}

class ScheduleTemplate {
  final String templateId;
  final String name;
  final String description;
  final String ownerId;
  final String projectId;
  final List<ScheduleBlock> scheduleBlocks;
  final ScheduleTargetType targetType;
  // ZMIANA: Pole przeniesione z bloku do szablonu
  final String areaId;

  const ScheduleTemplate({
    this.templateId = '',
    required this.name,
    this.description = '',
    required this.ownerId,
    required this.projectId,
    required this.scheduleBlocks,
    required this.targetType,
    // ZMIANA: Dodano do konstruktora
    required this.areaId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'projectId': projectId,
      'scheduleBlocks': scheduleBlocks.map((block) => block.toMap()).toList(),
      'targetType': targetType.name,
      // ZMIANA: Dodano do mapy
      'areaId': areaId,
    };
  }

  static ScheduleTargetType _targetTypeFromString(String? name) {
    for (final type in ScheduleTargetType.values) {
      if (type.name == name) {
        return type;
      }
    }
    return ScheduleTargetType.user;
  }

  factory ScheduleTemplate.fromMap(Map<String, dynamic> map, {String? docId}) {
    final blocksData = map['scheduleBlocks'] as List<dynamic>? ?? [];
    final blocks = blocksData.map((blockMap) {
      return ScheduleBlock.fromMap(blockMap as Map<String, dynamic>);
    }).toList();

    return ScheduleTemplate(
      templateId: docId ?? map['templateId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      projectId: map['projectId'] as String? ?? '',
      scheduleBlocks: blocks,
      targetType: _targetTypeFromString(map['targetType'] as String?),
      // ZMIANA: Odczyt z mapy
      areaId: map['areaId'] as String? ?? '',
    );
  }

  factory ScheduleTemplate.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Brak danych dla ScheduleTemplate z dokumentu Firestore: ${doc.id}');
    }
    return ScheduleTemplate.fromMap(data, docId: doc.id);
  }
}


class ScheduleBlock {
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final String colorHex;
  final String recurrenceRule;
  // ZMIANA: Usunięto pole areaId

  const ScheduleBlock({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.colorHex,
    required this.recurrenceRule,
    // ZMIANA: Usunięto z konstruktora
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'colorHex': colorHex,
      'recurrenceRule': recurrenceRule,
      // ZMIANA: Usunięto z mapy
    };
  }

  factory ScheduleBlock.fromMap(Map<String, dynamic> map) {
    return ScheduleBlock(
      name: map['name'] as String? ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      colorHex: map['colorHex'] as String? ?? '#2196F3',
      recurrenceRule: map['recurrenceRule'] as String? ?? '',
      // ZMIANA: Usunięto odczyt z mapy
    );
  }

  Color get color {
    final buffer = StringBuffer();
    if (colorHex.length == 6 || colorHex.length == 7) buffer.write('ff');
    buffer.write(colorHex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}