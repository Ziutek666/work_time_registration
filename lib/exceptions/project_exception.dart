// exceptions/project_exception.dart

class ProjectException implements Exception {
  final String message;
  ProjectException([this.message = 'Wystąpił błąd związany z projektem.']);

  @override
  String toString() => 'ProjectException: $message';
}

class ProjectNotFoundException extends ProjectException {
  ProjectNotFoundException([String message = 'Nie znaleziono projektu.']) : super(message);
}

class ProjectCreationException extends ProjectException {
  ProjectCreationException([String message = 'Nie udało się utworzyć projektu.']) : super(message);
}

class ProjectUpdateException extends ProjectException {
  ProjectUpdateException([String message = 'Nie udało się zaktualizować projektu.']) : super(message);
}

class ProjectDeletionException extends ProjectException {
  ProjectDeletionException([String message = 'Nie udało się usunąć projektu.']) : super(message);
}

class InvalidProjectDataException extends ProjectException {
  InvalidProjectDataException([String message = 'Nieprawidłowe dane projektu.']) : super(message);
}

class NoProjectsFoundException extends ProjectException {
  NoProjectsFoundException([String message = 'Nie znaleziono żadnych projektów.']) : super(message);
}

// Dodany wyjątek dla błędów pobierania
class ProjectFetchException extends ProjectException {
  ProjectFetchException([String message = 'Wystąpił błąd podczas pobierania danych projektu.']) : super(message);
}