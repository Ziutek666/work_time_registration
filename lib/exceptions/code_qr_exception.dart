/// Podstawowa klasa dla wszystkich wyjątków związanych z kodami QR.
class CodeQrException implements Exception {
  final String message;
  CodeQrException(this.message);

  @override
  String toString() => 'CodeQrException: $message';
}

/// Wyjątek rzucany, gdy operacja na danych QR w Firestore się nie powiedzie.
class CodeQrDataException extends CodeQrException {
  CodeQrDataException(String message) : super('Błąd operacji na danych: $message');
}

/// Wyjątek rzucany, gdy podany kod QR nie zostanie znaleziony.
class CodeQrNotFoundException extends CodeQrException {
  CodeQrNotFoundException() : super('Nie znaleziono kodu QR o podanym identyfikatorze.');
}

/// Wyjątek rzucany, gdy dane wejściowe do stworzenia kodu QR są nieprawidłowe.
class CodeQrValidationException extends CodeQrException {
  CodeQrValidationException(String message) : super('Błąd walidacji: $message');
}