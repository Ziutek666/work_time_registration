// work_type_exceptions.dart

/// Podstawowa klasa wyjątku dla operacji na WorkType.
class WorkTypeException implements Exception {
  final String message;
  WorkTypeException(this.message);

  @override
  String toString() => 'WorkTypeException: $message';
}

/// Wyjątek rzucany, gdy nie znaleziono WorkType.
class WorkTypeNotFoundException extends WorkTypeException {
  WorkTypeNotFoundException(String message) : super(message);
}

/// Wyjątek rzucany podczas problemów z tworzeniem WorkType.
class WorkTypeCreationException extends WorkTypeException {
  WorkTypeCreationException(String message) : super(message);
}

/// Wyjątek rzucany podczas problemów z aktualizacją WorkType.
class WorkTypeUpdateException extends WorkTypeException {
  WorkTypeUpdateException(String message) : super(message);
}

/// Wyjątek rzucany podczas problemów z usuwaniem WorkType.
class WorkTypeDeletionException extends WorkTypeException {
  WorkTypeDeletionException(String message) : super(message);
}

/// Wyjątek rzucany podczas problemów z pobieraniem listy WorkType.
class GetAllWorkTypesException extends WorkTypeException {
  GetAllWorkTypesException(String message) : super(message);
}

/// Wyjątek rzucany podczas problemów z pobieraniem pojedynczego WorkType.
class GetWorkTypeException extends WorkTypeException {
  GetWorkTypeException(String message) : super(message);
}

class SaveLastUserWorkActionException extends WorkTypeException {
  SaveLastUserWorkActionException(String message) : super(message);
}


class ClearUserActionException extends WorkTypeException {
  ClearUserActionException(String message) : super(message);
}