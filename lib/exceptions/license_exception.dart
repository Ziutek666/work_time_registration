class LicenseException implements Exception {
  final String message;
  LicenseException([this.message = 'Wystąpił błąd licencji.']);

  @override
  String toString() => 'LicenseException: $message';
}

class LicenseFetchException extends LicenseException {
  LicenseFetchException([String message = 'Wystąpił błąd podczas pobierania licencji.']) : super(message);
}

class LicenseCreationException extends LicenseException {
  LicenseCreationException([String message = 'Wystąpił błąd podczas tworzenia licencji.']) : super(message);
}

class LicenseUpdateException extends LicenseException {
  LicenseUpdateException([String message = 'Wystąpił błąd podczas aktualizacji licencji.']) : super(message);
}

class LicenseDeletionException extends LicenseException {
  LicenseDeletionException([String message = 'Wystąpił błąd podczas usuwania licencji.']) : super(message);
}

class InvalidLicenseDataException extends LicenseException {
  InvalidLicenseDataException([String message = 'Nieprawidłowe dane licencji.']) : super(message);
}

class LicenseNotFoundException extends LicenseFetchException {
  LicenseNotFoundException([String message = 'Nie znaleziono licencji.']) : super(message);
}