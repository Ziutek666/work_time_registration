import '../../../models/user_availability.dart';
import '../exceptions/availability_exceptions.dart';
import '../repositories/availability_repository.dart';

/// Serwis zawierający logikę biznesową związaną z dyspozycyjnością.
class AvailabilityService {
  final AvailabilityRepository _repository;

  /// Wstrzykujemy repozytorium przez konstruktor (zasada Dependency Injection).
  AvailabilityService(this._repository);

  /// Zapisuje listę deklaracji dyspozycyjności.
  ///
  /// Przeprowadza walidację przed przekazaniem danych do repozytorium.
  Future<void> saveAvailabilities(List<UserAvailability> availabilities) async {
    if (availabilities.isEmpty) {
      return;
    }

    for (final availability in availabilities) {
      if (availability.userId.isEmpty || availability.projectId.isEmpty) {
        throw AvailabilityValidationException('UserID oraz ProjectID nie mogą być puste.');
      }
    }

    try {
      await _repository.addAvailabilities(availabilities);
    } catch (e) {
      rethrow;
    }
  }

  /// Pobiera deklaracje dyspozycyjności dla użytkownika jako mapę.
  ///
  /// Kluczem mapy jest ID dokumentu z bazy danych (np. Firestore),
  /// a wartością jest obiekt [UserAvailability]. Jest to kluczowe dla funkcji edycji i usuwania.
  Future<Map<String, UserAvailability>> getAvailabilitiesForUserWithDocId(String userId) async {
    if (userId.isEmpty) {
      throw AvailabilityValidationException('UserID nie może być puste.');
    }

    try {
      return await _repository.fetchAvailabilitiesForUserAsMap(userId);
    } catch (e) {
      rethrow;
    }
  }

  /// **(NOWOŚĆ)** Pobiera wszystkie deklaracje dyspozycyjności dla podanej listy użytkowników.
  ///
  /// Niezbędne dla ekranu administratora do podglądu dyspozycyjności całego zespołu.
  Future<List<UserAvailability>> getAvailabilitiesForUsers(List<String> userIds) async {
    if (userIds.isEmpty) {
      return []; // Zwróć pustą listę, jeśli nie ma ID do wyszukania.
    }

    try {
      return await _repository.fetchAvailabilitiesForUsers(userIds);
    } catch (e) {
      rethrow;
    }
  }
  /// Niezbędna dla ekranu analizy AI, aby pobierać dane w kontekście projektu.
  Future<List<UserAvailability>> getAvailabilitiesForProjectInDateRange(String projectId, DateTime startDate, DateTime endDate) async {
    if (projectId.isEmpty) {
      throw AvailabilityValidationException('ProjectID nie może być puste.');
    }

    try {
      // Wywołujemy nową, odpowiadającą funkcję w repozytorium
      return await _repository.fetchAvailabilitiesForProjectInDateRange(projectId, startDate, endDate);
    } catch (e) {
      rethrow;
    }
  }
  /// Aktualizuje status dostępności dla pojedynczego wpisu.
  Future<void> updateAvailabilityStatus(String docId, bool newStatus) async {
    if (docId.isEmpty) {
      throw AvailabilityValidationException('ID dokumentu (docId) nie może być puste.');
    }

    try {
      await _repository.updateAvailabilityStatus(docId, newStatus);
    } catch (e) {
      rethrow;
    }
  }

  /// Usuwa pojedynczy wpis dyspozycyjności na podstawie jego ID.
  Future<void> deleteAvailability(String docId) async {
    if (docId.isEmpty) {
      throw AvailabilityValidationException('ID dokumentu (docId) nie może być puste.');
    }

    try {
      await _repository.deleteAvailability(docId);
    } catch (e) {
      rethrow;
    }
  }
}

/// Globalna instancja serwisu dla łatwego dostępu w aplikacji.
final availabilityService = AvailabilityService(AvailabilityRepository());

/*
--- UWAGI DO ZMIAN W `AvailabilityRepository` ---
Aby nowa metoda `getAvailabilitiesForUsers` działała, Twoje repozytorium
powinno zostać rozbudowane o następującą metodę, która używa zapytania 'whereIn':


*/