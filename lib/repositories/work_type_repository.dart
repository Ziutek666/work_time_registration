// work_type_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/work_type_exceptions.dart'; // Upewnij się, że ta ścieżka jest poprawna
// i że plik zawiera odpowiednie wyjątki
import '../models/work_type.dart'; // Upewnij się, że ta ścieżka jest poprawna

class WorkTypeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _workTypesCollection;
  late final CollectionReference<Map<String, dynamic>> _lastUserWorkActionCollection;

  WorkTypeRepository() {
    _workTypesCollection = _firestore.collection('workTypes');
    _lastUserWorkActionCollection = _firestore.collection('LastUserWorkAction');
  }

  /// Zapisuje ostatnią akcję użytkownika (jako WorkType)
  /// w kolekcji 'LastUserWorkAction', używając userId jako ID dokumentu.
  Future<void> saveLastUserWorkAction(WorkType lastActionWorkType) async {
    if (lastActionWorkType.userId == null || lastActionWorkType.userId!.isEmpty) {
      throw ArgumentError('WorkType.userId nie może być puste podczas zapisywania ostatniej akcji użytkownika.');
    }
    final String documentId = lastActionWorkType.userId!;
    try {
      await _lastUserWorkActionCollection.doc(documentId).set(lastActionWorkType.toMap());
    } catch (e) {
      // Rozważ użycie bardziej specyficznego wyjątku, np. SaveLastUserWorkActionException
      // zdefiniowanego w work_type_exceptions.dart
      throw WorkTypeException('Wystąpił błąd podczas zapisywania ostatniej akcji użytkownika dla userId $documentId: $e');
    }
  }

  /// Usuwa dokument ostatniej akcji użytkownika z kolekcji 'LastUserWorkAction'
  /// na podstawie userId.
  Future<void> clearUserAction(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId nie może być puste podczas usuwania ostatniej akcji użytkownika.');
    }
    try {
      await _lastUserWorkActionCollection.doc(userId).delete();
    } catch (e) {
      // Rozważ użycie bardziej specyficznego wyjątku, np. ClearUserActionException
      // zdefiniowanego w work_type_exceptions.dart
      throw WorkTypeException('Wystąpił błąd podczas usuwania ostatniej akcji użytkownika dla userId $userId: $e');
    }
  }

  /// NOWA METODA: Pobiera ostatnią zapisaną akcję (WorkType) dla danego użytkownika.
  /// Zwraca null, jeśli brak zapisu dla użytkownika lub jeśli dokument jest pusty.
  Future<WorkType?> getLastUserWorkAction(String userId) async {
    if (userId.isEmpty) {
      // Można rzucić ArgumentError lub zwrócić null, jeśli pusty userId jest nieprawidłowy
      print("WorkTypeRepository: getLastUserWorkAction wywołane z pustym userId.");
      return null;
    }
    try {
      final docSnapshot = await _lastUserWorkActionCollection.doc(userId).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        // Upewnij się, że rzutowanie jest bezpieczne, DocumentSnapshot<Map<String, dynamic>> jest oczekiwane
        return WorkType.fromFirestore(docSnapshot as DocumentSnapshot<Map<String, dynamic>>);
      }
      return null; // Dokument nie istnieje lub nie ma danych
    } catch (e) {
      print('Błąd podczas pobierania ostatniej akcji użytkownika dla userId $userId: $e');
      // Można użyć istniejącego GetWorkTypeException lub stworzyć nowy, np. GetLastUserWorkActionException
      throw GetWorkTypeException('Wystąpił błąd podczas pobierania ostatniej akcji użytkownika dla userId $userId: $e');
    }
  }

  Future<List<WorkType>> fetchWorkTypesByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    List<WorkType> workTypes = [];
    try {
      for (String id in ids) {
        if (id.isEmpty) continue;
        final docSnapshot = await _workTypesCollection.doc(id).get();
        if (docSnapshot.exists && docSnapshot.data() != null) {
          final workType = WorkType.fromFirestore(docSnapshot as DocumentSnapshot<Map<String, dynamic>>);
          workTypes.add(workType);
        } else {
          print('WorkType o ID: $id nie został znaleziony w kolekcji.');
        }
      }
      return workTypes;
    } catch (e) {
      print('Błąd w WorkTypeRepository.fetchWorkTypesByIds: $e');
      throw GetAllWorkTypesException('Wystąpił błąd podczas pobierania typów pracy na podstawie listy ID dla projektu $e');
    }
  }

  Future<WorkType> getWorkType(String workTypeId) async {
    try {
      final docSnapshot = await _workTypesCollection.doc(workTypeId).get();
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        throw WorkTypeNotFoundException('Nie znaleziono typu pracy o ID: $workTypeId');
      }
      return WorkType.fromFirestore(docSnapshot as DocumentSnapshot<Map<String, dynamic>>);
    } on WorkTypeNotFoundException {
      rethrow;
    } catch (e) {
      throw GetWorkTypeException('Wystąpił błąd podczas pobierania typu pracy o ID: $workTypeId: $e');
    }
  }

  Future<List<WorkType>> getAllWorkTypesForProject(String projectId) async {
    try {
      final querySnapshot = await _workTypesCollection.where('projectId', isEqualTo: projectId).get();
      return querySnapshot.docs
          .map((doc) => WorkType.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      throw GetAllWorkTypesException('Wystąpił błąd podczas pobierania typów pracy dla projektu o ID: $projectId: $e');
    }
  }
  Future<List<WorkType>> getSubOrBreakWorkTypesForProject(String projectId) async {
    List<WorkType> results = [];
    Set<String> processedIds = {}; // Aby uniknąć duplikatów, jeśli to możliwe

    // Zapytanie o przerwy
    final breakQuerySnapshot = await _workTypesCollection
        .where('projectId', isEqualTo: projectId)
        .where('isBreak', isEqualTo: true)
        .get();

    for (var doc in breakQuerySnapshot.docs) {
      if (!processedIds.contains(doc.id)) {
        results.add(WorkType.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>));
        processedIds.add(doc.id);
      }
    }

    // Zapytanie o podzadania
    final subTaskQuerySnapshot = await _workTypesCollection
        .where('projectId', isEqualTo: projectId)
        .where('isSubTask', isEqualTo: true)
        .get();

    for (var doc in subTaskQuerySnapshot.docs) {
      if (!processedIds.contains(doc.id)) { // Sprawdź ponownie, na wypadek gdyby coś mogło być oboma
        results.add(WorkType.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>));
        processedIds.add(doc.id);
      }
    }

    // Opcjonalnie sortuj połączone wyniki, np. po nazwie
    results.sort((a, b) => a.name.compareTo(b.name));

    return results;
  }
  Future<List<WorkType>> getMainWorkTypesForProject(String projectId) async {
    try {
      final querySnapshot = await _workTypesCollection
          .where('projectId', isEqualTo: projectId)
          .where('isBreak', isEqualTo: false)
          .where('isSubTask', isEqualTo: false)
          .get();
      return querySnapshot.docs
          .map((doc) => WorkType.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      throw GetAllWorkTypesException('Wystąpił błąd podczas pobierania typów pracy dla projektu o ID: $projectId: $e');
    }
  }
  Future<WorkType> createWorkType(WorkType workType) async {
    try {
      WorkType workTypeWithFinalId;
      DocumentReference<Map<String, dynamic>> docRef;
      if (workType.workTypeId.isEmpty) {
        docRef = _workTypesCollection.doc();
        workTypeWithFinalId = workType.copyWith(workTypeId: docRef.id);
      } else {
        docRef = _workTypesCollection.doc(workType.workTypeId);
        workTypeWithFinalId = workType;
      }
      await docRef.set(workTypeWithFinalId.toMap());
      return workTypeWithFinalId;
    } catch (e) {
      throw WorkTypeCreationException('Wystąpił błąd podczas tworzenia typu pracy (planowane ID: ${workType.workTypeId.isEmpty ? "auto" : workType.workTypeId}): $e');
    }
  }

  Future<void> updateWorkType(WorkType workType) async {
    if (workType.workTypeId.isEmpty) {
      throw WorkTypeUpdateException('workTypeId nie może być pusty podczas aktualizacji.');
    }
    try {
      await _workTypesCollection.doc(workType.workTypeId).update(workType.toMap());
    } catch (e) {
      throw WorkTypeUpdateException('Wystąpił błąd podczas aktualizacji typu pracy o ID: ${workType.workTypeId}: $e');
    }
  }

  Future<void> deleteWorkType(String workTypeId) async {
    if (workTypeId.isEmpty) {
      throw WorkTypeDeletionException('workTypeId nie może być pusty podczas usuwania.');
    }
    try {
      await _workTypesCollection.doc(workTypeId).delete();
    } catch (e) {
      throw WorkTypeDeletionException('Wystąpił błąd podczas usuwania typu pracy o ID: $workTypeId: $e');
    }
  }
}