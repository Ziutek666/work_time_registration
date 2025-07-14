import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // Dodaj ten import, jeśli go brakuje

/// Model przechowujący informację o dyspozycyjności użytkownika.
class UserAvailability {
  final String availabilityId; // ID dokumentu w Firestore
  final String userId;
  final String projectId;
  final DateTime date; // Konkretny dzień (bez czasu), którego dotyczy dyspozycyjność
  final String scheduleTemplateId;
  final int blockIndex;
  final bool isAvailable; // true = MOGĘ pracować, false = NIE MOGĘ pracować
  final List<String> areaIds; // Lista stref; pusta lista oznacza "wszystkie dostępne"

  UserAvailability({
    this.availabilityId = '',
    required this.userId,
    required this.projectId,
    required this.date,
    required this.scheduleTemplateId,
    required this.blockIndex,
    required this.isAvailable,
    required this.areaIds,
  });

  /// Konwertuje obiekt UserAvailability na mapę do zapisu w Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'projectId': projectId,
      'date': Timestamp.fromDate(date),
      'scheduleTemplateId': scheduleTemplateId,
      'blockIndex': blockIndex,
      'isAvailable': isAvailable,
      'areaIds': areaIds,
    };
  }

  /// Tworzy obiekt UserAvailability z mapy pobranej z Firestore.
  factory UserAvailability.fromMap(Map<String, dynamic> map, {String? docId}) {
    // Pobierz listę z mapy, domyślnie ustawiając pustą listę, jeśli pole nie istnieje.
    final areaIdsFromMap = map['areaIds'] as List<dynamic>? ?? [];

    return UserAvailability(
      availabilityId: docId ?? '',
      userId: map['userId'] as String? ?? '',
      projectId: map['projectId'] as String? ?? '',
      date: (map['date'] as Timestamp).toDate(),
      scheduleTemplateId: map['scheduleTemplateId'] as String? ?? '',
      blockIndex: map['blockIndex'] as int? ?? 0,
      isAvailable: map['isAvailable'] as bool? ?? true,
      // ZMIANA: Bezpiecznie konwertuj każdy element na String.
      // To zapobiega błędowi typu, tworząc nową, poprawnie typowaną listę.
      areaIds: List<String>.from(areaIdsFromMap),
    );
  }

  /// Tworzy kopię obiektu, pozwalając na zmianę wybranych pól.
  UserAvailability copyWith({
    String? availabilityId,
    String? userId,
    String? projectId,
    DateTime? date,
    String? scheduleTemplateId,
    int? blockIndex,
    bool? isAvailable,
    List<String>? areaIds,
  }) {
    return UserAvailability(
      availabilityId: availabilityId ?? this.availabilityId,
      userId: userId ?? this.userId,
      projectId: projectId ?? this.projectId,
      date: date ?? this.date,
      scheduleTemplateId: scheduleTemplateId ?? this.scheduleTemplateId,
      blockIndex: blockIndex ?? this.blockIndex,
      isAvailable: isAvailable ?? this.isAvailable,
      areaIds: areaIds ?? this.areaIds,
    );
  }
}