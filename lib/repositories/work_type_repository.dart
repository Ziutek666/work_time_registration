import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/work_type_exceptions.dart';
import '../models/work_type.dart';

class WorkTypeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _workTypesCollection;
  late final CollectionReference<Map<String, dynamic>> _lastUserWorkActionCollection;

  WorkTypeRepository() {
    _workTypesCollection = _firestore.collection('workTypes');
    _lastUserWorkActionCollection = _firestore.collection('LastUserWorkAction');
  }

  /// Zapisuje ostatnią akcję użytkownika (jako WorkType).
  Future<void> saveLastUserWorkAction(WorkType lastActionWorkType) async {
    if (lastActionWorkType.userId == null || lastActionWorkType.userId!.isEmpty) {
      throw ArgumentError('WorkType.userId nie może być puste.');
    }
    final String documentId = lastActionWorkType.userId!;
    try {
      await _lastUserWorkActionCollection.doc(documentId).set(lastActionWorkType.toMap());
    } catch (e) {
      throw WorkTypeException('Błąd zapisu ostatniej akcji użytkownika dla userId $documentId: $e');
    }
  }

  /// Usuwa dokument ostatniej akcji użytkownika.
  Future<void> clearUserAction(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId nie może być puste.');
    }
    try {
      await _lastUserWorkActionCollection.doc(userId).delete();
    } catch (e) {
      throw WorkTypeException('Błąd usuwania ostatniej akcji użytkownika dla userId $userId: $e');
    }
  }

  /// Pobiera ostatnią zapisaną akcję (WorkType) dla danego użytkownika.
  Future<WorkType?> getLastUserWorkAction(String userId) async {
    if (userId.isEmpty) {
      return null;
    }
    try {
      final docSnapshot = await _lastUserWorkActionCollection.doc(userId).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return WorkType.fromFirestore(docSnapshot as DocumentSnapshot<Map<String, dynamic>>);
      }
      return null;
    } catch (e) {
      print('Błąd podczas pobierania ostatniej akcji użytkownika dla userId $userId: $e');
      throw GetWorkTypeException('Wystąpił błąd podczas pobierania ostatniej akcji użytkownika.');
    }
  }

  /// Pobiera listę typów pracy na podstawie listy ich ID.
  Future<List<WorkType>> fetchWorkTypesByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    try {
      // Użycie zapytania 'whereIn' jest znacznie wydajniejsze niż pętla
      final querySnapshot = await _workTypesCollection.where(FieldPath.documentId, whereIn: ids).get();
      return querySnapshot.docs.map((doc) => WorkType.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList();
    } catch (e) {
      throw GetAllWorkTypesException('Błąd podczas pobierania typów pracy na podstawie listy ID: $e');
    }
  }

  /// Pobiera pojedynczy typ pracy po jego ID.
  Future<WorkType> getWorkType(String workTypeId) async {
    try {
      final docSnapshot = await _workTypesCollection.doc(workTypeId).get();
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        throw WorkTypeNotFoundException('Nie znaleziono typu pracy o ID: $workTypeId');
      }
      return WorkType.fromFirestore(docSnapshot as DocumentSnapshot<Map<String, dynamic>>);
    } catch (e) {
      throw GetWorkTypeException('Błąd podczas pobierania typu pracy o ID: $workTypeId: $e');
    }
  }

  /// Pobiera wszystkie typy pracy dla danego projektu.
  Future<List<WorkType>> getAllWorkTypesForProject(String projectId) async {
    try {
      final querySnapshot = await _workTypesCollection.where('projectId', isEqualTo: projectId).get();
      return querySnapshot.docs.map((doc) => WorkType.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList();
    } catch (e) {
      throw GetAllWorkTypesException('Błąd podczas pobierania typów pracy dla projektu o ID: $projectId: $e');
    }
  }

  /// Pobiera wszystkie przerwy i podzadania dla danego projektu.
  Future<List<WorkType>> getSubOrBreakWorkTypesForProject(String projectId) async {
    try {
      final querySnapshot = await _workTypesCollection
          .where('projectId', isEqualTo: projectId)
          .where('isMain', isEqualTo: false) // Użycie zaprzeczenia flagi isMain upraszcza logikę
          .get();
      return querySnapshot.docs.map((doc) => WorkType.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList();
    } catch (e) {
      throw GetAllWorkTypesException('Błąd podczas pobierania przerw i podzadań dla projektu o ID: $projectId: $e');
    }
  }

  /// Pobiera tylko główne typy pracy (nie przerwy, nie podzadania, nie punkty kontrolne).
  Future<List<WorkType>> getMainWorkTypesForProject(String projectId) async {
    try {
      final querySnapshot = await _workTypesCollection
          .where('projectId', isEqualTo: projectId)
          .where('isMain', isEqualTo: true)
          .get();
      return querySnapshot.docs
          .map((doc) => WorkType.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      throw GetAllWorkTypesException('Błąd podczas pobierania głównych typów pracy dla projektu o ID: $projectId: $e');
    }
  }

  /// Tworzy nowy dokument typu pracy.
  Future<WorkType> createWorkType(WorkType workType) async {
    try {
      final docRef = _workTypesCollection.doc();
      final workTypeWithId = workType.copyWith(workTypeId: docRef.id);
      await docRef.set(workTypeWithId.toMap());
      return workTypeWithId;
    } catch (e) {
      throw WorkTypeCreationException('Błąd podczas tworzenia typu pracy: $e');
    }
  }

  /// Aktualizuje istniejący dokument typu pracy.
  Future<void> updateWorkType(WorkType workType) async {
    if (workType.workTypeId.isEmpty) throw WorkTypeUpdateException('workTypeId nie może być pusty.');
    try {
      await _workTypesCollection.doc(workType.workTypeId).update(workType.toMap());
    } catch (e) {
      throw WorkTypeUpdateException('Błąd podczas aktualizacji typu pracy o ID: ${workType.workTypeId}: $e');
    }
  }

  /// Usuwa dokument typu pracy.
  Future<void> deleteWorkType(String workTypeId) async {
    if (workTypeId.isEmpty) throw WorkTypeDeletionException('workTypeId nie może być pusty.');
    try {
      await _workTypesCollection.doc(workTypeId).delete();
    } catch (e) {
      throw WorkTypeDeletionException('Błąd podczas usuwania typu pracy o ID: $workTypeId: $e');
    }
  }
}