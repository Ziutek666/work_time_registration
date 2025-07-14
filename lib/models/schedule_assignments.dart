import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:work_time_registration/models/schedule_template.dart';

class ScheduleAssignment {
  final String assignmentId;
  final String scheduleTemplateId;
  final int blockIndex;
  final String targetId;
  final ScheduleTargetType targetType;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final String areaId;

  const ScheduleAssignment({
    this.assignmentId = '',
    required this.scheduleTemplateId,
    required this.blockIndex,
    required this.targetId,
    required this.targetType,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    // DODANO: Wymagamy areaId w konstruktorze
    required this.areaId,
  });

  bool get isEmpty => assignmentId.isEmpty;

  factory ScheduleAssignment.empty() {
    return ScheduleAssignment(
      scheduleTemplateId: '',
      targetId: '',
      targetType: ScheduleTargetType.user,
      startDate: DateTime(0),
      endDate: DateTime(0),
      blockIndex: -1,
      isActive: false,
      areaId: '', // DODANO
    );
  }

  ScheduleAssignment copyWith({
    String? assignmentId,
    String? scheduleTemplateId,
    int? blockIndex,
    String? targetId,
    ScheduleTargetType? targetType,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? areaId, // DODANO
  }) {
    return ScheduleAssignment(
      assignmentId: assignmentId ?? this.assignmentId,
      scheduleTemplateId: scheduleTemplateId ?? this.scheduleTemplateId,
      blockIndex: blockIndex ?? this.blockIndex,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      areaId: areaId ?? this.areaId, // DODANO
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduleTemplateId': scheduleTemplateId,
      'blockIndex': blockIndex,
      'targetId': targetId,
      'targetType': targetType.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'areaId': areaId, // DODANO
    };
  }

  factory ScheduleAssignment.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ScheduleAssignment(
      assignmentId: docId ?? map['assignmentId'] as String? ?? '',
      scheduleTemplateId: map['scheduleTemplateId'] as String? ?? '',
      blockIndex: map['blockIndex'] as int? ?? 0,
      targetId: map['targetId'] as String? ?? '',
      targetType: ScheduleTargetType.values.firstWhere(
            (e) => e.name == (map['targetType'] as String?),
        orElse: () => ScheduleTargetType.user,
      ),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isActive: map['isActive'] as bool? ?? true,
      // DODANO: Odczyt z mapy
      areaId: map['areaId'] as String? ?? '',
    );
  }

  factory ScheduleAssignment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Brak danych dla ScheduleAssignment z dokumentu Firestore: ${doc.id}');
    }
    return ScheduleAssignment.fromMap(data, docId: doc.id);
  }
}