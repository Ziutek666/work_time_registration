/// Podstawowa klasa wyjątku dla operacji na modelu Members.
class MembersException implements Exception {
  final String message;
  MembersException(this.message);

  @override
  String toString() => 'MembersException: $message';
}

/// Wyjątek rzucany przy problemach z odczytem lub zapisem danych w Firestore.
class MembersDataException extends MembersException {
  MembersDataException(String message) : super('Błąd danych członkostwa: $message');
}

/// Wyjątek rzucany, gdy dokument dla danego `memberId` nie zostanie znaleziony.
class MembersNotFoundException extends MembersException {
  MembersNotFoundException(String memberId) : super('Nie znaleziono dokumentu członkostwa o ID: $memberId');
}

/// Wyjątek rzucany przy nieudanej próbie aktualizacji danych.
class MembersUpdateException extends MembersException {
  MembersUpdateException(String memberId, String reason) : super('Błąd aktualizacji członkostwa o ID: $memberId. Powód: $reason');
}

/// NOWY WYJĄTEK: Rzucany przy próbie dodania członkostwa, które już istnieje.
class MemberAlreadyExistsException extends MembersException {
  MemberAlreadyExistsException(String message) : super(message);
}