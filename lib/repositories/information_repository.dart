import 'package:cloud_firestore/cloud_firestore.dart';

import '../exceptions/information_exceptions.dart';
import '../models/information.dart'; // Upewnij się, że importujesz zaktualizowany model

class InformationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionPath = 'informations';

  CollectionReference<Map<String, dynamic>> get _informationsCollection {
    return _firestore.collection(_collectionPath);
  }

  Future<Information?> getInformationById(String informationId) async {
    if (informationId.isEmpty) {
      throw ArgumentError('Information ID cannot be empty.');
    }
    try {
      final docSnapshot = await _informationsCollection.doc(informationId).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return Information.fromFirestore(docSnapshot); // Nie ma potrzeby rzutowania, jeśli typ jest już poprawny
      }
      return null;
    } on FirebaseException catch (e, s) {
      throw InformationLoadFailureException('Błąd podczas pobierania informacji o ID $informationId: ${e.message}', s);
    } catch (e, s) {
      throw InformationLoadFailureException('Nieoczekiwany błąd podczas pobierania informacji o ID $informationId: $e', s);
    }
  }

  Future<List<Information>> getInformationsByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    final validIds = ids.where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty) {
      return [];
    }

    // Firestore 'in' query supports up to 30 elements in the array.
    // For more than 30, we need to split into multiple queries or fetch individually.
    // The current fallback fetches individually.
    if (validIds.length > 30) {
      print("Ostrzeżenie: Lista ID (${validIds.length}) dla getInformationsByIds przekracza limit 30. Pobieranie pojedynczo.");
      List<Information> results = [];
      for (String id in validIds) {
        final info = await getInformationById(id);
        if (info != null) results.add(info);
      }
      return results;
    }

    try {
      final querySnapshot = await _informationsCollection
          .where(FieldPath.documentId, whereIn: validIds)
          .get();

      return querySnapshot.docs
          .map((doc) => Information.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e, s) {
      throw InformationLoadFailureException('Błąd podczas pobierania informacji (lista ID): ${e.message}', s);
    } catch (e, s) {
      throw InformationLoadFailureException('Nieoczekiwany błąd podczas pobierania informacji (lista ID): $e', s);
    }
  }

  /// Pobiera listę informacji na podstawie listy ich ID, filtrując te, które mają showOnStart == true.
  Future<List<Information>> getInformationsByIdsShowOnStart(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    final validIds = ids.where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty) {
      return [];
    }

    // Firestore 'in' query supports up to 30 elements combined with other filters.
    if (validIds.length > 30) {
      print("Ostrzeżenie: Lista ID (${validIds.length}) dla getInformationsByIdsShowOnStart przekracza limit 30. Pobieranie pojedynczo i filtrowanie po stronie klienta.");
      List<Information> results = [];
      for (String id in validIds) {
        print("Pobieranie informacji o ID: $id");
        final info = await getInformationById(id);
        // Zakładamy, że model Information ma pole showOnStart
        if (info != null && info.showOnStart == true) {
          results.add(info);
        }
      }
      return results;
    }

    try {
      final querySnapshot = await _informationsCollection
          .where(FieldPath.documentId, whereIn: validIds)
          .where('showOnStart', isEqualTo: true) // Dodatkowe filtrowanie
          .get();

      return querySnapshot.docs
          .map((doc) => Information.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e, s) {
      throw InformationLoadFailureException('Błąd podczas pobierania informacji (showOnStart): ${e.message}', s);
    } catch (e, s) {
      throw InformationLoadFailureException('Nieoczekiwany błąd podczas pobierania informacji (showOnStart): $e', s);
    }
  }

  /// Pobiera listę informacji na podstawie listy ich ID, filtrując te, które mają showOnStop == true.
  Future<List<Information>> getInformationsByIdsShowOnStop(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    final validIds = ids.where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty) {
      return [];
    }

    if (validIds.length > 30) {
      print("Ostrzeżenie: Lista ID (${validIds.length}) dla getInformationsByIdsShowOnStop przekracza limit 30. Pobieranie pojedynczo i filtrowanie po stronie klienta.");
      List<Information> results = [];
      for (String id in validIds) {
        final info = await getInformationById(id);
        // Zakładamy, że model Information ma pole showOnStop
        if (info != null && info.showOnStop == true) {
          results.add(info);
        }
      }
      return results;
    }

    try {
      final querySnapshot = await _informationsCollection
          .where(FieldPath.documentId, whereIn: validIds)
          .where('showOnStop', isEqualTo: true) // Dodatkowe filtrowanie
          .get();

      return querySnapshot.docs
          .map((doc) => Information.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e, s) {
      throw InformationLoadFailureException('Błąd podczas pobierania informacji (showOnStop): ${e.message}', s);
    } catch (e, s) {
      throw InformationLoadFailureException('Nieoczekiwany błąd podczas pobierania informacji (showOnStop): $e', s);
    }
  }


  Future<List<Information>> getAllInformationsByProjectId(String projectId, {String? orderByField, bool descending = false}) async {
    if (projectId.isEmpty) {
      throw ArgumentError('Project ID cannot be empty.');
    }
    try {
      Query query = _informationsCollection.where('projectId', isEqualTo: projectId);
      if (orderByField != null) {
        query = query.orderBy(orderByField, descending: descending);
      } else {
        query = query.orderBy('createdAt', descending: true); // Domyślne sortowanie
      }
      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => Information.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } on FirebaseException catch (e, s) {
      throw InformationLoadFailureException('Błąd podczas pobierania informacji dla projektu $projectId: ${e.message}', s);
    } catch (e, s) {
      throw InformationLoadFailureException('Nieoczekiwany błąd podczas pobierania informacji dla projektu $projectId: $e', s);
    }
  }

  Future<List<Information>> getAllInformations({String? orderByField, bool descending = false}) async {
    try {
      Query query = _informationsCollection;
      if (orderByField != null) {
        query = query.orderBy(orderByField, descending: descending);
      } else {
        query = query.orderBy('createdAt', descending: true); // Domyślne sortowanie
      }
      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => Information.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } on FirebaseException catch (e, s) {
      throw InformationLoadFailureException('Błąd podczas pobierania wszystkich informacji: ${e.message}', s);
    } catch (e, s) {
      throw InformationLoadFailureException('Nieoczekiwany błąd podczas pobierania wszystkich informacji: $e', s);
    }
  }

  Future<String> createInformation(Information information) async {
    try {
      // Usunięto sprawdzanie information.informationId, ID będzie generowane przez Firestore lub ustawiane ręcznie przed wywołaniem
      final DocumentReference docRef = information.informationId.isEmpty
          ? _informationsCollection.doc() // Pozwól Firestore wygenerować ID
          : _informationsCollection.doc(information.informationId); // Użyj dostarczonego ID

      // Jeśli ID było puste, zaktualizuj obiekt information o wygenerowane ID
      final Information informationToSave = information.informationId.isEmpty
          ? information.copyWith(informationId: docRef.id, createdAt: Timestamp.now()) // Dodaj createdAt
          : information.copyWith(createdAt: information.createdAt ?? Timestamp.now()); // Upewnij się, że createdAt jest ustawione

      await docRef.set(informationToSave.toMap());
      return docRef.id;
    } on FirebaseException catch (e, s) {
      throw InformationCreateFailureException('Błąd podczas tworzenia informacji: ${e.message}', s);
    } catch (e, s) {
      throw InformationCreateFailureException('Nieoczekiwany błąd podczas tworzenia informacji: $e', s);
    }
  }

  Future<void> updateInformation(Information information) async {
    if (information.informationId.isEmpty) {
      throw ArgumentError('Information ID cannot be empty for update.');
    }
    try {
      // Upewnij się, że przekazujesz zaktualizowany obiekt z poprawnym `updatedAt`
      final informationToUpdate = information.copyWith();
      await _informationsCollection
          .doc(information.informationId)
          .update(informationToUpdate.toMap());
    } on FirebaseException catch (e, s) {
      throw InformationUpdateFailureException('Błąd podczas aktualizacji informacji o ID ${information.informationId}: ${e.message}', s);
    } catch (e, s) {
      throw InformationUpdateFailureException('Nieoczekiwany błąd podczas aktualizacji informacji o ID ${information.informationId}: $e', s);
    }
  }

  Future<void> deleteInformation(String informationId) async {
    if (informationId.isEmpty) {
      throw ArgumentError('Information ID cannot be empty for deletion.');
    }
    try {
      await _informationsCollection.doc(informationId).delete();
    } on FirebaseException catch (e, s) {
      throw InformationDeleteFailureException('Błąd podczas usuwania informacji o ID $informationId: ${e.message}', s);
    } catch (e, s) {
      throw InformationDeleteFailureException('Nieoczekiwany błąd podczas usuwania informacji o ID $informationId: $e', s);
    }
  }

  Future<void> markAsAdminRead(String informationId) async {
    if (informationId.isEmpty) {
      throw ArgumentError('Information ID cannot be empty.');
    }
    try {
      await _informationsCollection
          .doc(informationId)
          .update({'adminRead': true});
    } on FirebaseException catch (e, s) {
      throw InformationUpdateFailureException('Błąd podczas oznaczania informacji $informationId jako przeczytanej przez admina: ${e.message}', s);
    } catch (e, s) {
      throw InformationUpdateFailureException('Nieoczekiwany błąd podczas oznaczania informacji $informationId jako przeczytanej przez admina: $e', s);
    }
  }

  Future<void> markAsAdminUnread(String informationId) async {
    if (informationId.isEmpty) {
      throw ArgumentError('Information ID cannot be empty.');
    }
    try {
      await _informationsCollection
          .doc(informationId)
          .update({'adminRead': false});
    } on FirebaseException catch (e, s) {
      throw InformationUpdateFailureException('Błąd podczas oznaczania informacji $informationId jako nieprzeczytanej przez admina: ${e.message}', s);
    } catch (e, s) {
      throw InformationUpdateFailureException('Nieoczekiwany błąd podczas oznaczania informacji $informationId jako nieprzeczytanej przez admina: $e', s);
    }
  }
}

final informationRepository = InformationRepository();