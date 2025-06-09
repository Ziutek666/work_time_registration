class AreaException implements Exception {
  final String message;
  final dynamic details;

  AreaException(this.message, {this.details});

  @override
  String toString() {
    return 'AreaException: $message${details != null ? ' (Details: $details)' : ''}';
  }
}

class AreaNotFoundException extends AreaException {
  AreaNotFoundException({String? areaId})
      : super('Nie znaleziono obszaru${areaId != null ? ' o ID: $areaId' : ''}.');
}

class AreaCreationException extends AreaException {
  AreaCreationException(String message, {dynamic details}) : super('Błąd podczas tworzenia obszaru: $message', details: details);
}

class AreaUpdateException extends AreaException {
  AreaUpdateException(String message, {dynamic details}) : super('Błąd podczas aktualizacji obszaru: $message', details: details);
}

class AreaDeletionException extends AreaException {
  AreaDeletionException(String message, {dynamic details}) : super('Błąd podczas usuwania obszaru: $message', details: details);
}

class AreaUserOperationException extends AreaException {
  AreaUserOperationException(String message, {dynamic details}) : super('Błąd podczas operacji na użytkownikach obszaru: $message', details: details);
}