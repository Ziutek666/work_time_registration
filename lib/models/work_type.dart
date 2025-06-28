import 'package:cloud_firestore/cloud_firestore.dart';

class WorkType {
  final String workTypeId;
  final String name;
  final String description;
  final Duration? defaultDuration;
  final bool isBreak;
  final bool isPaid;
  final String projectId;
  final String ownerId;
  final bool isSubTask;
  final String? userId;
  final List<String> informationIds;
  final List<String> subTaskIds;
  final bool isRequired;
  final bool isCheckPoint;
  final bool isMain;
  final bool requiresQrScan; // NOWOŚĆ: Pole określające wymóg skanowania QR

  const WorkType({
    this.workTypeId = '',
    required this.name,
    required this.description,
    this.defaultDuration,
    required this.isBreak,
    required this.isPaid,
    required this.projectId,
    required this.ownerId,
    this.isSubTask = false,
    this.userId,
    List<String>? informationIds,
    List<String>? subTaskIds,
    this.isRequired = false,
    this.isCheckPoint = false,
    this.isMain = false,
    this.requiresQrScan = false, // NOWOŚĆ: Domyślna wartość false
  })  : informationIds = informationIds ?? const [],
        subTaskIds = subTaskIds ?? const [];

  WorkType copyWith({
    String? workTypeId,
    String? name,
    String? description,
    Duration? defaultDuration,
    bool? setNullDefaultDuration,
    bool? isBreak,
    bool? isPaid,
    String? projectId,
    String? ownerId,
    bool? isSubTask,
    String? userId,
    bool? clearUserId,
    List<String>? informationIds,
    List<String>? subTaskIds,
    bool? isRequired,
    bool? isCheckPoint,
    bool? isMain,
    bool? requiresQrScan, // NOWOŚĆ
  }) {
    return WorkType(
      workTypeId: workTypeId ?? this.workTypeId,
      name: name ?? this.name,
      description: description ?? this.description,
      defaultDuration: (setNullDefaultDuration == true) ? null : (defaultDuration ?? this.defaultDuration),
      isBreak: isBreak ?? this.isBreak,
      isPaid: isPaid ?? this.isPaid,
      projectId: projectId ?? this.projectId,
      ownerId: ownerId ?? this.ownerId,
      isSubTask: isSubTask ?? this.isSubTask,
      userId: clearUserId == true ? null : (userId ?? this.userId),
      informationIds: informationIds ?? List<String>.from(this.informationIds),
      subTaskIds: subTaskIds ?? List<String>.from(this.subTaskIds),
      isRequired: isRequired ?? this.isRequired,
      isCheckPoint: isCheckPoint ?? this.isCheckPoint,
      isMain: isMain ?? this.isMain,
      requiresQrScan: requiresQrScan ?? this.requiresQrScan, // NOWOŚĆ
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'defaultDurationInMinutes': defaultDuration?.inMinutes,
      'isBreak': isBreak,
      'isPaid': isPaid,
      'projectId': projectId,
      'ownerId': ownerId,
      'isSubTask': isSubTask,
      if (userId != null) 'userId': userId,
      'informationIds': informationIds,
      'subTaskIds': subTaskIds,
      'isRequired': isRequired,
      'isCheckPoint': isCheckPoint,
      'isMain': isMain,
      'requiresQrScan': requiresQrScan, // NOWOŚĆ
    };
  }

  factory WorkType.fromMap(Map<String, dynamic> map, {String? docId}) {
    final durationInMinutes = map['defaultDurationInMinutes'] as int?;
    return WorkType(
      workTypeId: docId ?? map['workTypeId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      defaultDuration: durationInMinutes != null ? Duration(minutes: durationInMinutes) : null,
      isBreak: map['isBreak'] as bool? ?? false,
      isPaid: map['isPaid'] as bool? ?? true,
      projectId: map['projectId'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      isSubTask: map['isSubTask'] as bool? ?? false,
      userId: map['userId'] as String?,
      informationIds: List<String>.from(map['informationIds'] as List<dynamic>? ?? const []),
      subTaskIds: List<String>.from(map['subTaskIds'] as List<dynamic>? ?? const []),
      isRequired: map['isRequired'] as bool? ?? false,
      isCheckPoint: map['isCheckPoint'] as bool? ?? false,
      isMain: map['isMain'] as bool? ?? false,
      requiresQrScan: map['requiresQrScan'] as bool? ?? false, // NOWOŚĆ
    );
  }

  factory WorkType.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Brak danych dla WorkType z dokumentu Firestore: ${doc.id}');
    }
    return WorkType.fromMap(data, docId: doc.id);
  }
}