// lib/exceptions/user_exceptions.dart
// (Dostosuj ścieżkę do swojej struktury projektu)

/// Abstrakcyjna klasa bazowa dla wszystkich wyjątków związanych z operacjami na użytkowniku.
abstract class UserException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  const UserException(this.message, [this.stackTrace]);

  @override
  String toString() => '$runtimeType: $message${stackTrace == null ? '' : '\n$stackTrace'}';
}

/// Wyjątek rzucany, gdy nie znaleziono użytkownika o podanym UID.
class UserNotFoundException extends UserException {
  final String? uid; // Dodano opcjonalne UID dla kontekstu

  const UserNotFoundException({this.uid, String message = 'Nie znaleziono użytkownika.'})
      : super(message);

  @override
  String toString() {
    final uidInfo = uid != null ? ' (UID: $uid)' : '';
    return 'UserNotFoundException: $message$uidInfo';
  }
}

/// Wyjątek rzucany, gdy wystąpi błąd podczas pobierania danych użytkownika.
class UserFetchException extends UserException {
  const UserFetchException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Wyjątek rzucany, gdy nie znaleziono użytkownika o podanym adresie email.
class UserEmailNotFoundException extends UserException {
  final String email;

  UserEmailNotFoundException(this.email, [String message = 'Nie znaleziono użytkownika o podanym emailu.'])
      : super('$message Email: $email'); // Komunikat zawiera email
}

/// Wyjątek rzucany, gdy wystąpi błąd podczas tworzenia nowego użytkownika.
/// (Może być mniej używany, jeśli `saveUser` obsługuje zarówno tworzenie, jak i aktualizację)
class UserCreationException extends UserException {
  const UserCreationException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Wyjątek rzucany, gdy wystąpi błąd podczas zapisywania (tworzenia lub aktualizacji) danych użytkownika.
class UserSaveException extends UserException {
  const UserSaveException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Wyjątek rzucany, gdy wystąpi błąd podczas aktualizacji danych użytkownika.
class UserUpdateException extends UserException {
  const UserUpdateException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Wyjątek rzucany, gdy wystąpi błąd podczas usuwania użytkownika.
class UserDeletionException extends UserException {
  const UserDeletionException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Wyjątek rzucany, gdy wystąpi błąd podczas sprawdzania istnienia użytkownika.
/// (Poprzednio CheckUserExistsException)
class UserExistenceCheckException extends UserException {
  final String uid;

  UserExistenceCheckException(this.uid, [String message = 'Wystąpił błąd podczas sprawdzania istnienia użytkownika.', StackTrace? stackTrace])
      : super('$message UID: $uid', stackTrace); // Komunikat zawiera UID
}