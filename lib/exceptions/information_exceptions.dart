// lib/features/information/exceptions/information_exceptions.dart
// (Bez zmian w stosunku do poprzednio zdefiniowanej wersji)
abstract class InformationException implements Exception {
  final String message;
  final StackTrace? stackTrace;
  InformationException(this.message, [this.stackTrace]);
  @override
  String toString() => '$runtimeType: $message${stackTrace == null ? '' : '\n$stackTrace'}';
}
class InformationNotFoundException extends InformationException { // Dodajemy, jeśli nie było
  InformationNotFoundException([super.message = 'Information not found.', super.stackTrace]);
}
class InformationLoadFailureException extends InformationException {
  InformationLoadFailureException([super.message = 'Failed to load information data.', super.stackTrace]);
}
class InformationCreateFailureException extends InformationException {
  InformationCreateFailureException([super.message = 'Failed to create information.', super.stackTrace]);
}
class InformationUpdateFailureException extends InformationException {
  InformationUpdateFailureException([super.message = 'Failed to update information.', super.stackTrace]);
}
class InformationDeleteFailureException extends InformationException {
  InformationDeleteFailureException([super.message = 'Failed to delete information.', super.stackTrace]);
}