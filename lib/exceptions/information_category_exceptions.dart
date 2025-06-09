// lib/features/information/data/exceptions/information_category_exceptions.dart

/// Podstawowa klasa wyjątku dla operacji na kategoriach informacji.
class InformationCategoryException implements Exception {
  final String message;
  InformationCategoryException(this.message);

  @override
  String toString() => 'InformationCategoryException: $message';
}

/// Wyjątek rzucany, gdy nie uda się załadować kategorii.
class InformationCategoryLoadFailureException extends InformationCategoryException {
  InformationCategoryLoadFailureException(String message) : super(message);
}

/// Wyjątek rzucany, gdy nie uda się utworzyć nowej kategorii.
class InformationCategoryCreateFailureException extends InformationCategoryException {
  InformationCategoryCreateFailureException(String message) : super(message);
}

/// Wyjątek rzucany, gdy nie uda się zaktualizować istniejącej kategorii.
class InformationCategoryUpdateFailureException extends InformationCategoryException {
  InformationCategoryUpdateFailureException(String message) : super(message);
}

/// Wyjątek rzucany, gdy nie uda się usunąć kategorii.
class InformationCategoryDeleteFailureException extends InformationCategoryException {
  InformationCategoryDeleteFailureException(String message) : super(message);
}

/// Wyjątek rzucany, gdy kategoria o podanym ID nie zostanie znaleziona.
class InformationCategoryNotFoundException extends InformationCategoryException {
  InformationCategoryNotFoundException(String message) : super(message);
}
