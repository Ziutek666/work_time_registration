import 'package:cloud_firestore/cloud_firestore.dart';

class Project {
  final String projectId;
  final String ownerId;
  final String name;
  final String description;

  Project({
    required this.name,
    required this.ownerId,
    required this.projectId,
    this.description = '',
  });

  // Metoda copyWith do tworzenia kopii obiektu z możliwością zmiany wybranych pól
  Project copyWith({
    String? projectId,
    String? ownerId,
    String? name,
    String? description,
  }) {
    return Project(
      projectId: projectId ?? this.projectId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  factory Project.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return Project(
      name: data?['name'] ?? '',
      projectId: data?['projectId'] ?? '',
      ownerId: data?['ownerId'] ?? '',
      description: data?['description'] ?? 'description',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'projectId': projectId,
      'ownerId': ownerId,
      'description': description,
    };
  }
}