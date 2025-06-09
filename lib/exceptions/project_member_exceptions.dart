// lib/features/project_members/domain/exceptions/project_member_exceptions.dart
// (Dostosuj ścieżkę do swojej struktury projektu)

/// Podstawowa klasa wyjątku dla operacji na członkach projektu.
class ProjectMemberException implements Exception {
  final String message;
  ProjectMemberException(this.message);

  @override
  String toString() => 'ProjectMemberException: $message';
}

/// Wyjątek rzucany, gdy członek projektu nie zostanie znaleziony (np. przez kombinację projectId i userId).
class ProjectMemberNotFoundException extends ProjectMemberException {
  ProjectMemberNotFoundException(String criteria) // Zmieniono kryterium
      : super('Nie znaleziono członkostwa w projekcie pasującego do kryteriów: $criteria.');
}

/// Wyjątek rzucany podczas błędu tworzenia członka projektu.
class ProjectMemberCreationException extends ProjectMemberException {
  ProjectMemberCreationException(String message)
      : super('Błąd podczas dodawania członkostwa w projekcie: $message');
}

/// Wyjątek rzucany podczas błędu aktualizacji danych członka projektu.
class ProjectMemberUpdateException extends ProjectMemberException {
  ProjectMemberUpdateException(String membershipId, String message) // Zmieniono na membershipId
      : super('Błąd podczas aktualizacji członkostwa w projekcie "$membershipId": $message');
}

/// Wyjątek rzucany podczas błędu usuwania członka projektu.
class ProjectMemberDeletionException extends ProjectMemberException {
  ProjectMemberDeletionException(String membershipId, String message) // Zmieniono na membershipId
      : super('Błąd podczas usuwania członkostwa w projekcie "$membershipId": $message');
}

/// Wyjątek rzucany, gdy operacja na członku projektu nie powiedzie się z powodu błędu Firestore.
class ProjectMemberFirestoreException extends ProjectMemberException {
  ProjectMemberFirestoreException(String message, [dynamic originalException])
      : super('Błąd Firestore podczas operacji na członkostwie w projekcie: $message${originalException != null ? "\nOryginalny błąd: $originalException" : ""}');
}