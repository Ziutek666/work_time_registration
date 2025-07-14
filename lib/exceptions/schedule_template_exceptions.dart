// lib/features/schedule_templates/data/schedule_template_exceptions.dart

/// Podstawowa klasa dla wyjątków związanych z szablonami harmonogramów.
abstract class ScheduleTemplateException implements Exception {
  final String message;
  ScheduleTemplateException(this.message);

  @override
  String toString() => 'ScheduleTemplateException: $message';
}

/// Rzucany, gdy operacja na szablonie harmonogramu napotka błąd.
class ScheduleTemplateOperationException extends ScheduleTemplateException {
  ScheduleTemplateOperationException(String message) : super('Błąd operacji na szablonie: $message');
}

/// Rzucany, gdy szablon o danym ID nie zostanie znaleziony.
class ScheduleTemplateNotFoundException extends ScheduleTemplateException {
  ScheduleTemplateNotFoundException() : super('Nie znaleziono szablonu harmonogramu.');
}

/// Rzucany, gdy dane wejściowe są nieprawidłowe.
class ScheduleTemplateValidationException extends ScheduleTemplateException {
  ScheduleTemplateValidationException(String message) : super('Błąd walidacji: $message');
}