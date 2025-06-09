import 'package:cloud_firestore/cloud_firestore.dart';
import 'information.dart';

class WorkEntry {
  final String entryId;
  final String userId;
  final String projectId;
  final String areaId;
  final String workTypeId;

  // Snapshot pól z WorkType w momencie tworzenia WorkEntry
  final String workTypeName;
  final String workTypeDescription;
  final int? workTypeDefaultDurationInSeconds;
  final bool workTypeIsBreak;
  final bool workTypeIsPaid;
  final bool workTypeIsSubTask;
  final List<String> workTypeInformationIds;

  // ZMIENIONE POLA CZASU
  /// Czas dokładnego kliknięcia przycisku "Rozpocznij" lub "Zakończ" przez użytkownika.
  final Timestamp eventActionTimestamp;
  /// Czas zapisu całego obiektu WorkEntry do bazy danych (po ewentualnym wypełnieniu informacji).
  final Timestamp? saveTimestamp;

  final bool isStart; // Pozostaje, aby rozróżnić zdarzenie startu i stopu

  String? description;
  final String? parentWorkEntryId;

  final List<Information>? relatedInformations;

  WorkEntry({
    required this.entryId,
    required this.userId,
    required this.projectId,
    required this.areaId,
    required this.workTypeId,
    required this.workTypeName,
    required this.workTypeDescription,
    this.workTypeDefaultDurationInSeconds,
    required this.workTypeIsBreak,
    required this.workTypeIsPaid,
    required this.workTypeIsSubTask,
    required this.workTypeInformationIds,
    required this.eventActionTimestamp, // ZMIENIONO
    this.saveTimestamp,             // DODANO
    required this.isStart,
    this.description,
    this.parentWorkEntryId,
    this.relatedInformations,
  });

  factory WorkEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Brak danych dla WorkEntry z dokumentu Firestore: ${doc.id}');
    }

    List<Information>? informations;
    if (data['relatedInformations'] != null && data['relatedInformations'] is List) {
      informations = (data['relatedInformations'] as List<dynamic>)
          .map((infoMap) => Information.fromMap(infoMap as Map<String, dynamic>))
          .toList();
    }

    List<String> wtInfoIds = [];
    if (data['workTypeInformationIds'] != null && data['workTypeInformationIds'] is List) {
      wtInfoIds = List<String>.from(data['workTypeInformationIds'] as List<dynamic>);
    }

    return WorkEntry(
      entryId: doc.id,
      userId: data['userId'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      areaId: data['areaId'] as String? ?? '',
      workTypeId: data['workTypeId'] as String? ?? '',
      workTypeName: data['workTypeName'] as String? ?? 'N/A',
      workTypeDescription: data['workTypeDescription'] as String? ?? '',
      workTypeDefaultDurationInSeconds: data['workTypeDefaultDurationInSeconds'] as int?,
      workTypeIsBreak: data['workTypeIsBreak'] as bool? ?? false,
      workTypeIsPaid: data['workTypeIsPaid'] as bool? ?? true,
      workTypeIsSubTask: data['workTypeIsSubTask'] as bool? ?? false,
      workTypeInformationIds: wtInfoIds,
      // Zapewnienie kompatybilności wstecznej: jeśli stare pole 'eventTimestamp' istnieje, użyj go
      eventActionTimestamp: data['eventActionTimestamp'] as Timestamp? ?? data['eventTimestamp'] as Timestamp? ?? Timestamp.now(),
      saveTimestamp: data['saveTimestamp'] as Timestamp?,
      isStart: data['isStart'] as bool? ?? true,
      description: data['description'] as String?,
      parentWorkEntryId: data['parentWorkEntryId'] as String?,
      relatedInformations: informations,
    );
  }

  WorkEntry copyWith({
    String? entryId,
    String? userId,
    String? projectId,
    String? areaId,
    String? workTypeId,
    String? workTypeName,
    String? workTypeDescription,
    int? workTypeDefaultDurationInSeconds,
    bool? workTypeIsBreak,
    bool? workTypeIsPaid,
    bool? workTypeIsSubTask,
    List<String>? workTypeInformationIds,
    Timestamp? eventActionTimestamp, // ZMIENIONO
    Timestamp? saveTimestamp,        // DODANO
    bool? isStart,
    String? description,
    String? parentWorkEntryId,
    bool? clearParentWorkEntryId,
    List<Information>? relatedInformations,
    bool? clearRelatedInformations,
  }) {
    return WorkEntry(
      entryId: entryId ?? this.entryId,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      areaId: areaId ?? this.areaId,
      workTypeId: workTypeId ?? this.workTypeId,
      workTypeName: workTypeName ?? this.workTypeName,
      workTypeDescription: workTypeDescription ?? this.workTypeDescription,
      workTypeDefaultDurationInSeconds: workTypeDefaultDurationInSeconds ?? this.workTypeDefaultDurationInSeconds,
      workTypeIsBreak: workTypeIsBreak ?? false,
      workTypeIsPaid: workTypeIsPaid ?? false,
      workTypeIsSubTask: workTypeIsSubTask ?? false,
      workTypeInformationIds: workTypeInformationIds ?? List<String>.from(this.workTypeInformationIds),
      eventActionTimestamp: eventActionTimestamp ?? this.eventActionTimestamp,
      saveTimestamp: saveTimestamp ?? this.saveTimestamp,
      isStart: isStart ?? this.isStart,
      description: description ?? this.description,
      parentWorkEntryId: clearParentWorkEntryId == true ? null : (parentWorkEntryId ?? this.parentWorkEntryId),
      relatedInformations: clearRelatedInformations == true ? null : (relatedInformations ?? (this.relatedInformations != null ? List<Information>.from(this.relatedInformations!.map((info) => info.copyWith())) : null)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'projectId': projectId,
      'areaId': areaId,
      'workTypeId': workTypeId,
      'workTypeName': workTypeName,
      'workTypeDescription': workTypeDescription,
      if (workTypeDefaultDurationInSeconds != null)
        'workTypeDefaultDurationInSeconds': workTypeDefaultDurationInSeconds,
      'workTypeIsBreak': workTypeIsBreak,
      'workTypeIsPaid': workTypeIsPaid,
      'workTypeIsSubTask': workTypeIsSubTask,
      'workTypeInformationIds': workTypeInformationIds,
      'eventActionTimestamp': eventActionTimestamp, // ZMIENIONO
      'saveTimestamp': saveTimestamp,             // DODANO
      'isStart': isStart,
      if (description != null) 'description': description,
      if (parentWorkEntryId != null) 'parentWorkEntryId': parentWorkEntryId,
      if (relatedInformations != null)
        'relatedInformations': relatedInformations!.map((info) => info.toMap()).toList(),
    };
  }
}
