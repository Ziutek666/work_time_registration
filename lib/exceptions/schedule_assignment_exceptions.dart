// lib/features/schedule_assignments/data/schedule_assignment_exceptions.dart

/// Podstawowa klasa dla wyjątków związanych z przypisaniami harmonogramów.
abstract class ScheduleAssignmentException implements Exception {
  final String message;
  ScheduleAssignmentException(this.message);

  @override
  String toString() => 'ScheduleAssignmentException: $message';
}

/// Rzucany, gdy operacja na przypisaniu napotka ogólny błąd.
class ScheduleAssignmentOperationException extends ScheduleAssignmentException {
  ScheduleAssignmentOperationException(String message) : super('Błąd operacji na przypisaniu: $message');
}

/// Rzucany, gdy dane przypisanie nie zostanie znalezione.
class ScheduleAssignmentNotFoundException extends ScheduleAssignmentException {
  ScheduleAssignmentNotFoundException() : super('Nie znaleziono przypisania harmonogramu.');
}

/// Rzucany, gdy dane wejściowe dla przypisania są nieprawidłowe.
class ScheduleAssignmentValidationException extends ScheduleAssignmentException {
  ScheduleAssignmentValidationException(String message) : super('Błąd walidacji przypisania: $message');
}

/// Rzucany, gdy istnieje już aktywne przypisanie dla danego obiektu.
class ScheduleAssignmentConflictException extends ScheduleAssignmentException {
  ScheduleAssignmentConflictException(String s) : super('Obiekt docelowy ma już aktywne przypisanie w tym okresie.');
}