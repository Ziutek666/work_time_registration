import 'package:cloud_firestore/cloud_firestore.dart'; // Potrzebne dla AreaUser -> Timestamp
import '../models/area.dart';
import '../repositories/area_repository.dart'; // Importuje globalną instancję

class AreaService {
  final AreaRepository _areaRepository = AreaRepository();

  /// Tworzy nowy obszar.
  Future<String> createArea({
    required String name,
    required String projectId,
    required String ownerId,
    String description = '',
    bool active = false, // Dodano parametr active z wartością domyślną
    List<AreaUser> users = const [], // Dodano parametr users z wartością domyślną
    List<String>? workTypesIds, // <<<--- NOWY OPCJONALNY PARAMETR
  }) async {
    final area = Area(
      name: name,
      projectId: projectId,
      ownerId: ownerId,
      description: description,
      areaId: '', // ID zostanie wygenerowane przez Firestore
      active: active,
      users: users,
      workTypesIds: workTypesIds ?? [], // Przekazanie listy ID typów pracy
    );
    return _areaRepository.createArea(area);
  }

  /// Pobiera obszar na podstawie jego ID.
  Future<Area> getArea(String areaId) async {
    return _areaRepository.getArea(areaId);
  }

  /// Aktualizuje istniejący obszar.
  Future<void> updateArea({
    required String areaId,
    String? name,
    String? description,
    bool? active,
    List<AreaUser>? users, // Dodano możliwość aktualizacji użytkowników
    List<String>? workTypesIds, // <<<--- NOWY OPCJONALNY PARAMETR
  }) async {
    final existingArea = await _areaRepository.getArea(areaId);
    // Używamy copyWith do aktualizacji tylko tych pól, które zostały podane
    final updatedArea = existingArea.copyWith(
      name: name, // Jeśli name jest null, existingArea.name zostanie użyte
      description: description,
      active: active,
      users: users,
      workTypesIds: workTypesIds, // Przekazanie nowej listy ID typów pracy
    );
    return _areaRepository.updateArea(updatedArea);
  }

  /// Usuwa obszar na podstawie jego ID.
  Future<void> deleteArea(String areaId) async {
    // Nie ma potrzeby pobierania obszaru tutaj, repozytorium powinno sobie poradzić z samym ID
    return _areaRepository.deleteArea(areaId);
  }

  /// Pobiera wszystkie obszary należące do danego projektu.
  Future<List<Area>> getAreasByProject(String projectId) async {
    return _areaRepository.getAreasByProject(projectId);
  }
  /// Pobiera wszystkie obszary należące do danego projektu.
  Future<List<Area>> getAreasByIds(List<String> ids) async {
    return _areaRepository.getAreaByIds(ids);
  }

  /// Dodaje użytkownika do obszaru.
  Future<void> addUserToArea(String areaId, String userId, String name, String email) async {
    final newUser = AreaUser(userId: userId, name: name, email: email, entryTime: DateTime.now());
    // Repozytorium powinno obsługiwać logikę dodawania użytkownika do listy w dokumencie
    return _areaRepository.addUserToArea(areaId, newUser);
  }

  /// Usuwa użytkownika z obszaru.
  Future<void> removeUserFromArea(String areaId, String userId) async {
    // Repozytorium powinno obsługiwać logikę usuwania użytkownika z listy w dokumencie
    return _areaRepository.removeUserFromArea(areaId, userId);
  }

  /// Sprawdza, czy nazwa obszaru już istnieje w danym projekcie.
  Future<bool> checkIfAreaNameExists({
    required String projectId,
    required String name,
  }) async {
    try {
      return await _areaRepository.checkIfNameExistsInProject(
        projectId: projectId,
        name: name,
      );
    } catch (e) {
      print('Błąd w AreaService.checkIfAreaNameExists: $e');
      // W zależności od wymagań, można rzucić błąd dalej lub zwrócić wartość domyślną
      // throw; // Rzuć błąd dalej, aby UI mogło go obsłużyć
      return false; // Przykład: w razie błędu zakładamy, że nazwa nie istnieje (może być ryzykowne)
    }
  }
}

/// Globalna instancja serwisu
final areaService = AreaService();
