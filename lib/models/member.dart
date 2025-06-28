import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:work_time_registration/models/project-access.dart';

class Member {
  /// ID dokumentu w Firestore (np. kombinacja "userId_ownerId"). Jest to to samo co ID dokumentu.
  final String memberId;

  /// ID użytkownika (pracownika). Pole wymagane.
  final String userId;

  /// ID pracodawcy (właściciela). Pole wymagane.
  final String ownerId;

  /// Lista wszystkich projektów, do których użytkownik ma dostęp w ramach tej firmy (ownerId).
  final List<ProjectAccess> projects;

  /// Data dodania użytkownika do firmy.
  final Timestamp dateAdded;

  /// Opcjonalny, globalny status użytkownika w ramach tej firmy (np. "aktywny", "zawieszony").
  final String? status;

  Member({
    required this.memberId, // Zmieniono z 'id' na 'memberId'
    required this.userId,
    required this.ownerId,
    required this.projects,
    required this.dateAdded,
    this.status,
  });

  /// Tworzy obiekt Member z dokumentu Firestore.
  factory Member.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    Map<String, dynamic> data = doc.data() ?? {};
    var projectsListFromData = data['projects'] as List<dynamic>? ?? [];

    return Member(
      // Zmieniono z 'id' na 'memberId'
      memberId: doc.id,
      userId: data['userId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      projects: projectsListFromData
          .map((projectData) =>
          ProjectAccess.fromMap(projectData as Map<String, dynamic>))
          .toList(),
      dateAdded: data['dateAdded'] as Timestamp? ?? Timestamp.now(),
      status: data['status'] as String?,
    );
  }

  /// Konwertuje obiekt Member na mapę do zapisu w Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'ownerId': ownerId,
      'projects': projects.map((p) => p.toMap()).toList(),
      'dateAdded': dateAdded,
      if (status != null) 'status': status,
    };
  }

  /// Metoda pomocnicza do tworzenia kopii obiektu ze zmienionymi wartościami.
  Member copyWith({
    List<ProjectAccess>? projects,
    Timestamp? dateAdded,
    String? status,
  }) {
    return Member(
      memberId: this.memberId, // Zmieniono z 'id' na 'memberId'
      userId: this.userId,
      ownerId: this.ownerId,
      projects: projects ?? this.projects,
      dateAdded: dateAdded ?? this.dateAdded,
      status: status ?? this.status,
    );
  }
}