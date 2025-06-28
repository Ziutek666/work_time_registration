class ProjectAccess {
  final String projectId;
  final Set<String> roles;
  final Set<String> areaIds;

  // ZMIANA: Poprawiony konstruktor, aby unikać niemodyfikowalnych zbiorów.
  ProjectAccess({
    required this.projectId,
    Set<String>? roles,
    Set<String>? areaIds,
  })  : this.roles = roles ?? {}, // Jeśli role są null, utwórz nowy, pusty, MODYFIKOWALNY zbiór
        this.areaIds = areaIds ?? {}; // Jeśli areaIds są null, utwórz nowy, pusty, MODYFIKOWALNY zbiór

  factory ProjectAccess.fromMap(Map<String, dynamic> map) {
    return ProjectAccess(
      projectId: map['projectId'] as String? ?? '',
      roles: Set<String>.from(map['roles'] as List<dynamic>? ?? []),
      areaIds: Set<String>.from(map['areaIds'] as List<dynamic>? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'roles': roles.toList(),
      'areaIds': areaIds.toList(),
    };
  }

  ProjectAccess copyWith({
    String? projectId,
    Set<String>? roles,
    Set<String>? areaIds,
  }) {
    return ProjectAccess(
      projectId: projectId ?? this.projectId,
      roles: roles ?? this.roles,
      areaIds: areaIds ?? this.areaIds,
    );
  }
}