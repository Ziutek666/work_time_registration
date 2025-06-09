import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/area.dart';
import '../exceptions/area_exceptions.dart';

class AreaRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'areas';

  /// Tworzy nowy obszar w Firestore.
  Future<String> createArea(Area area) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final newAreaId = docRef.id;
      final newArea = area.copyWith(areaId: newAreaId);
      await docRef.set(newArea.toMap());
      return newAreaId;
    } catch (e) {
      throw AreaCreationException('Nie można utworzyć obszaru w bazie danych.', details: e);
    }
  }
  /// Pobiera obszar z Firestore na podstawie jego ID.
  Future<Area> getArea(String areaId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(areaId).get();
      if (!doc.exists) {
        throw AreaNotFoundException(areaId: areaId);
      }
      return Area.fromFirestore(doc);
    } catch (e) {
      if (e is AreaNotFoundException) {
        rethrow;
      }
      throw AreaException('Wystąpił błąd podczas pobierania obszaru.', details: e);
    }
  }

  /// Aktualizuje istniejący obszar w Firestore.
  Future<void> updateArea(Area area) async {
    try {
      await _firestore.collection(_collection).doc(area.areaId).update(area.toMap());
    } catch (e) {
      throw AreaUpdateException('Nie można zaktualizować obszaru w bazie danych.', details: e);
    }
  }

  /// Usuwa obszar z Firestore na podstawie jego ID.
  Future<void> deleteArea(String areaId) async {
    try {
      await _firestore.collection(_collection).doc(areaId).delete();
    } catch (e) {
      throw AreaDeletionException('Nie można usunąć obszaru z bazy danych.', details: e);
    }
  }

  /// Pobiera wszystkie obszary należące do danego projektu.
  Future<List<Area>> getAreasByProject(String projectId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('projectId', isEqualTo: projectId)
          .get();
      return querySnapshot.docs.map((doc) => Area.fromFirestore(doc)).toList();
    } catch (e) {
      throw AreaException('Wystąpił błąd podczas pobierania obszarów projektu.', details: e);
    }
  }

  /// Pobiera listę obszarów na podstawie listy ich ID.
  Future<List<Area>> getAreaByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    final validIds = ids.where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty) {
      return [];
    }

    if (validIds.length > 30) {
      print("Ostrzeżenie: Lista ID (${validIds.length}) przekracza limit 30 dla zapytania 'in'. Rozważ podział zapytania lub pobieranie pojedynczo.");
      List<Area> results = [];
      for (String id in validIds) {
        final info = await getArea(id);
        if (info != null) results.add(info);
      }
      return results;
    }

    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where(FieldPath.documentId, whereIn: validIds)
          .get();

      return querySnapshot.docs
          .map((doc) => Area.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e, s) {
      throw AreaException('Wystąpił błąd podczas pobierania obszarów projektu.', details: e);
    }
  }

  /// Dodaje użytkownika do obszaru.
  Future<void> addUserToArea(String areaId, AreaUser user) async {
    try {
      final area = await getArea(areaId);
      final updatedUsers = [...area.users, user];
      await _firestore.collection(_collection).doc(areaId).update({'users': updatedUsers.map((u) => u.toMap()).toList()});
    } catch (e) {
      if (e is AreaNotFoundException) {
        rethrow;
      }
      throw AreaUserOperationException('Nie można dodać użytkownika do obszaru.', details: e);
    }
  }

  /// Usuwa użytkownika z obszaru.
  Future<void> removeUserFromArea(String areaId, String userId) async {
    try {
      final area = await getArea(areaId);
      final updatedUsers = area.users.where((u) => u.userId != userId).toList();
      await _firestore.collection(_collection).doc(areaId).update({'users': updatedUsers.map((u) => u.toMap()).toList()});
    } catch (e) {
      if (e is AreaNotFoundException) {
        rethrow;
      }
      throw AreaUserOperationException('Nie można usunąć użytkownika z obszaru.', details: e);
    }
  }

  Future<bool> checkIfNameExistsInProject({
    required String projectId,
    required String name,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('areas') // Zakładając, że kolekcja nazywa się 'areas'
          .where('projectId', isEqualTo: projectId)
          .where('name', isEqualTo: name)
          .limit(1) // Wystarczy nam wiedzieć, czy istnieje przynajmniej jeden taki dokument
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Błąd w AreaRepository.checkIfNameExistsInProject: $e');
      // Rozważ, jak obsłużyć błąd - rzucić dalej, czy zwrócić wartość domyślną
      // Dla bezpieczeństwa, aby nie blokować funkcjonalności, można zwrócić false,
      // ale warto to zalogować lub obsłużyć bardziej szczegółowo.
      throw Exception('Błąd podczas sprawdzania unikalności nazwy strefy: $e');
      // Lub return false; i obsłużyć to w serwisie
    }
  }
}