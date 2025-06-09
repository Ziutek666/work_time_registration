// lib/features/work_entries/domain/exceptions/work_entry_exceptions.dart
// (Dostosuj ścieżkę do swojej struktury projektu)

/// Podstawowa klasa wyjątku dla operacji na wpisach czasu pracy.
class WorkEntryException implements Exception {
  final String message;
  WorkEntryException(this.message);

  @override
  String toString() => 'WorkEntryException: $message';
}

/// Wyjątek rzucany, gdy wpis czasu pracy nie zostanie znaleziony.
class WorkEntryNotFoundException extends WorkEntryException {
  WorkEntryNotFoundException(String entryId)
      : super('Nie znaleziono wpisu czasu pracy o ID "$entryId".');
}

/// Wyjątek rzucany podczas błędu tworzenia wpisu czasu pracy.
class WorkEntryCreationException extends WorkEntryException {
  WorkEntryCreationException(String message)
      : super('Błąd podczas tworzenia wpisu czasu pracy: $message');
}

/// Wyjątek rzucany podczas błędu aktualizacji wpisu czasu pracy.
class WorkEntryUpdateException extends WorkEntryException {
  WorkEntryUpdateException(String entryId, String message)
      : super('Błąd podczas aktualizacji wpisu czasu pracy "$entryId": $message');
}

/// Wyjątek rzucany podczas błędu usuwania wpisu czasu pracy.
class WorkEntryDeletionException extends WorkEntryException {
  WorkEntryDeletionException(String entryId, String message)
      : super('Błąd podczas usuwania wpisu czasu pracy "$entryId": $message');
}

/// Wyjątek rzucany, gdy operacja na wpisie czasu pracy nie powiedzie się z powodu błędu Firestore.
class WorkEntryFirestoreException extends WorkEntryException {
  WorkEntryFirestoreException(String message, [dynamic originalException])
      : super('Błąd Firestore podczas operacji na wpisie czasu pracy: $message${originalException != null ? "\nOryginalny błąd: $originalException" : ""}');
}

/// Wyjątek rzucany, gdy użytkownik próbuje rozpocząć nową pracę, mając już aktywny wpis.
/// Ten wyjątek jest używany w WorkEntryService.
class ActiveWorkEntryExistsException extends WorkEntryException {
  ActiveWorkEntryExistsException(String details) // Zmieniono argumenty dla większej elastyczności
      : super('Użytkownik ma już aktywny wpis czasu pracy. $details Zakończ poprzedni wpis przed rozpoczęciem nowego.');
}

/// Wyjątek rzucany, gdy próbuje się zakończyć wpis, który nie jest aktywny lub nie istnieje.
/// Ten wyjątek jest używany w WorkEntryService.
class NoActiveWorkEntryToStopException extends WorkEntryException {
  NoActiveWorkEntryToStopException(String details) // Zmieniono argumenty dla większej elastyczności
      : super('Brak aktywnego wpisu czasu pracy do zakończenia. $details');
}
