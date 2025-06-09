import 'package:cloud_firestore/cloud_firestore.dart';

// Klasa pomocnicza UserAction (pozostaje bez zmian, jeśli jest używana w Information)
// Jeśli nie jest używana bezpośrednio przez WorkType, można ją pominąć w tym pliku,
// zakładając, że jest zdefiniowana tam, gdzie jest potrzebna (np. w modelu Information).

class WorkType {
  final String workTypeId; // ID dokumentu Firestore
  final String name;
  final String description;
  final Duration? defaultDuration;
  final bool isBreak;
  final bool isPaid;
  final String projectId;
  final String ownerId;
  final bool isSubTask; // Wskazuje, czy TEN WorkType jest podzadaniem
  final String? userId;
  final List<String> informationIds;
  final List<String> subTaskIds; // NOWE POLE: Lista ID powiązanych podzadań

  const WorkType({
    this.workTypeId = '',
    required this.name,
    required this.description,
    this.defaultDuration,
    required this.isBreak,
    required this.isPaid,
    required this.projectId,
    required this.ownerId,
    this.isSubTask = false, // To pole określa, czy dany WorkType sam w sobie jest podzadaniem
    this.userId,
    List<String>? informationIds,
    List<String>? subTaskIds, // Dodano do konstruktora
  })  : informationIds = informationIds ?? const [],
        subTaskIds = subTaskIds ?? const []; // Inicjalizacja nowego pola

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
    List<String>? subTaskIds, // Dodano do copyWith
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
      informationIds: informationIds ?? List<String>.from(this.informationIds), // Kopiowanie listy
      subTaskIds: subTaskIds ?? List<String>.from(this.subTaskIds), // Kopiowanie nowej listy
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workTypeId': workTypeId, // Zazwyczaj nie zapisuje się ID dokumentu w jego danych, ale może być potrzebne
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
      'subTaskIds': subTaskIds, // Dodano do mapy
    };
  }

  factory WorkType.fromMap(Map<String, dynamic> map) {
    final durationInMinutes = map['defaultDurationInMinutes'] as int?;
    return WorkType(
      workTypeId: map['workTypeId'] as String? ?? '', // Odczyt workTypeId jeśli jest w mapie (np. przy kopiowaniu)
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
      subTaskIds: List<String>.from(map['subTaskIds'] as List<dynamic>? ?? const []), // Odczyt nowego pola
    );
  }

  factory WorkType.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Brak danych dla WorkType z dokumentu Firestore: ${doc.id}');
    }
    // Tworzenie mapy z ID dokumentu i resztą danych
    final mapData = {
      'workTypeId': doc.id, // Ustawienie ID z dokumentu
      ...data,
    };
    return WorkType.fromMap(mapData);
  }
}