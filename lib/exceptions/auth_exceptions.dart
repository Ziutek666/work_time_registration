// exceptions/auth_exception.dart

class AuthException implements Exception {
  final String message;
  AuthException([this.message = 'Wystąpił błąd autentykacji.']);

  @override
  String toString() => 'AuthException: $message';
}

class SignUpFailedException extends AuthException {
  SignUpFailedException([String message = 'Rejestracja nie powiodła się.']) : super(message);
}

class LogInFailedException extends AuthException {
  LogInFailedException([String message = 'Logowanie nie powiodło się.']) : super(message);
}

class InvalidEmailException extends AuthException {
  InvalidEmailException([String message = 'Nieprawidłowy format adresu email.']) : super(message);
}

class WeakPasswordException extends AuthException {
  WeakPasswordException([String message = 'Hasło jest zbyt słabe.']) : super(message);
}

class UserNotFoundException extends AuthException {
  UserNotFoundException([String message = 'Nie znaleziono użytkownika o podanym adresie email.']) : super(message);
}

class WrongPasswordException extends AuthException {
  WrongPasswordException([String message = 'Podane hasło jest nieprawidłowe.']) : super(message);
}

class EmailAlreadyInUseException extends AuthException {
  EmailAlreadyInUseException([String message = 'Podany adres email jest już używany.']) : super(message);
}

class UserDisabledException extends AuthException {
  UserDisabledException([String message = 'Konto użytkownika jest zablokowane.']) : super(message);
}

// Możesz dodać więcej własnych wyjątków w zależności od potrzeb