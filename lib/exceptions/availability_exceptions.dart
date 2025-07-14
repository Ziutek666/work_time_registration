/// Podstawowa klasa dla wyjątków związanych z modułem dyspozycyjności.
class AvailabilityException implements Exception {
  final String message;
  AvailabilityException(this.message);

  @override
  String toString() => 'AvailabilityException: $message';
}

/// Wyjątek rzucany w przypadku błędów walidacji danych wejściowych.
class AvailabilityValidationException extends AvailabilityException {
  AvailabilityValidationException(String message) : super('Błąd walidacji: $message');
}

/// Wyjątek rzucany w przypadku błędów podczas operacji w repozytorium (np. błąd Firestore).
class AvailabilityRepositoryException extends AvailabilityException {
  AvailabilityRepositoryException(String message) : super('Błąd repozytorium: $message');
}