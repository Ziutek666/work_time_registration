import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectMember {
  final String id; // ID dokumentu członkostwa (automatycznie generowane przez Firestore)
  final String projectId;
  final String userId;
  final List<String> roles;
  final Timestamp dateAdded;
  final List<String> areaIds; // <<<--- NOWE POLE: Lista ID obszarów, do których użytkownik ma dostęp
  final String? status; // Opcjonalne pole statusu

  ProjectMember({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.roles,
    required this.dateAdded,
    this.areaIds = const [], // Domyślnie pusta lista
    this.status,
  });

  factory ProjectMember.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data() ?? {};
    return ProjectMember(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      roles: List<String>.from(data['roles'] as List<dynamic>? ?? []),
      dateAdded: data['dateAdded'] as Timestamp? ?? Timestamp.now(),
      areaIds: List<String>.from(data['areaIds'] as List<dynamic>? ?? []), // Odczyt nowego pola
      status: data['status'] as String?,
    );
  }

  Map<String, dynamic> toMapForCreation() {
    return {
      'projectId': projectId,
      'userId': userId,
      'roles': roles,
      'dateAdded': dateAdded,
      'areaIds': areaIds, // Dodanie nowego pola do mapy
      if (status != null) 'status': status,
    };
  }

  Map<String, dynamic> toMapForUpdate() {
    // Ta metoda powinna zawierać tylko pola, które faktycznie mogą być aktualizowane oddzielnie.
    // Jeśli aktualizujesz cały obiekt, toMapForCreation może być wystarczające,
    // ale wtedy musisz uważać, żeby nie nadpisać pól, których nie chcesz zmieniać.
    // Lepiej przekazywać konkretne pola do metody update w repozytorium.
    return {
      'roles': roles,
      'areaIds': areaIds, // Dodanie nowego pola do mapy aktualizacji
      // 'dateModified': Timestamp.now(), // Przykład
    };
  }

  ProjectMember copyWith({
    String? id,
    String? projectId,
    String? userId,
    List<String>? roles,
    Timestamp? dateAdded,
    List<String>? areaIds, // Dodanie nowego pola
    // String? status,
  }) {
    return ProjectMember(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      userId: userId ?? this.userId,
      roles: roles ?? this.roles,
      dateAdded: dateAdded ?? this.dateAdded,
      areaIds: areaIds ?? this.areaIds, // Obsługa nowego pola
      // status: status ?? this.status,
    );
  }
}