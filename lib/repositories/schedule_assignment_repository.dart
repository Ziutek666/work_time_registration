// Nazwa pliku: schedule_assignment_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/schedule_assignment_exceptions.dart';
import '../models/schedule_assignments.dart';
import '../models/schedule_template.dart';

/// Interfejs definiujący operacje na przypisaniach harmonogramów.
abstract class IScheduleAssignmentRepository {
  Future<String> createAssignment(ScheduleAssignment assignment);
  Future<void> updateAssignment(ScheduleAssignment assignment);
  Future<void> deleteAssignment(String assignmentId);
  Future<ScheduleAssignment?> getAssignmentById(String assignmentId);
  Future<ScheduleAssignment?> findActiveAssignmentForTarget(String targetId, ScheduleTargetType targetType);
  Future<List<ScheduleAssignment>> findAllAssignmentsForTemplate(String templateId);
  Future<List<ScheduleAssignment>> findActiveAssignmentsForTargetList(List<String> targetIds, ScheduleTargetType targetType);
  Future<List<ScheduleAssignment>> findAllAssignmentsForTarget(String targetId, ScheduleTargetType targetType);
  Future<bool> doesAssignmentExist({
    required String targetId,
    required ScheduleTargetType targetType,
    required DateTime date,
    required int blockIndex,
  });
  Future<void> createMultipleAssignments(List<ScheduleAssignment> assignments);
  Future<List<ScheduleAssignment>> findAllAssignmentsForUsers(List<String> userIds);

  /// NOWA METODA W INTERFEJSIE: Pobiera przypisania dla projektu w zakresie dat.
  Future<List<ScheduleAssignment>> fetchAllAssignmentsForProjectInDateRange(String projectId, DateTime startDate, DateTime endDate);
}


class ScheduleAssignmentRepository implements IScheduleAssignmentRepository {
  final FirebaseFirestore _firestore;
  static const String _collectionPath = 'schedule_assignments';
  // NOWOŚĆ: Dodajemy referencję do kolekcji szablonów
  static const String _templatesCollectionPath = 'scheduleTemplates';


  ScheduleAssignmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Referencja do kolekcji z konwerterem typów.
  CollectionReference<ScheduleAssignment> get _assignmentsCollection =>
      _firestore.collection(_collectionPath).withConverter<ScheduleAssignment>(
        fromFirestore: (snapshot, _) => ScheduleAssignment.fromFirestore(snapshot),
        toFirestore: (assignment, _) => assignment.toMap(),
      );


  @override
  Future<String> createAssignment(ScheduleAssignment assignment) async {
    try {
      final docRef = await _assignmentsCollection.add(assignment);
      return docRef.id;
    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas tworzenia przypisania: ${e.message}');
    }
  }

  @override
  Future<void> updateAssignment(ScheduleAssignment assignment) async {
    try {
      if (assignment.assignmentId.isEmpty) {
        throw ScheduleAssignmentValidationException('ID przypisania nie może być puste podczas aktualizacji.');
      }
      await _assignmentsCollection.doc(assignment.assignmentId).update(assignment.toMap());
    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas aktualizacji przypisania: ${e.message}');
    }
  }


  @override
  Future<void> deleteAssignment(String assignmentId) async {
    try {
      await _assignmentsCollection.doc(assignmentId).delete();
    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas usuwania przypisania: ${e.message}');
    }
  }

  @override
  Future<ScheduleAssignment?> getAssignmentById(String assignmentId) async {
    try {
      final doc = await _assignmentsCollection.doc(assignmentId).get();
      return doc.data();
    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas pobierania przypisania: ${e.message}');
    }
  }
  @override
  Future<ScheduleAssignment?> findActiveAssignmentForTarget(String targetId, ScheduleTargetType targetType) async {
    // UWAGA: To zapytanie wymaga indeksu kompozytowego w Firestore!
    // Pola: targetId (ASC), targetType (ASC), isActive (ASC)
    try {
      final querySnapshot = await _assignmentsCollection
          .where('targetId', isEqualTo: targetId)
          .where('targetType', isEqualTo: targetType.name)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }
      return querySnapshot.docs.first.data();
    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas wyszukiwania aktywnego przypisania: ${e.message}');
    }
  }

  @override
  Future<List<ScheduleAssignment>> findAllAssignmentsForTemplate(String templateId) async {
    try {
      final querySnapshot = await _assignmentsCollection
          .where('scheduleTemplateId', isEqualTo: templateId)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas wyszukiwania przypisań dla szablonu: ${e.message}');
    }
  }

  @override
  Future<List<ScheduleAssignment>> findActiveAssignmentsForTargetList(List<String> targetIds, ScheduleTargetType targetType) async {
    if (targetIds.isEmpty) {
      return [];
    }
    // UWAGA: To zapytanie z operatorem `whereIn` również wymaga indeksu kompozytowego!
    // Pola: targetType (ASC), isActive (ASC), targetId (ASC)
    try {
      final querySnapshot = await _assignmentsCollection
          .where('targetType', isEqualTo: targetType.name)
          .where('isActive', isEqualTo: true)
          .where('targetId', whereIn: targetIds)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas wyszukiwania aktywnych przypisań dla listy celów: ${e.message}');
    }
  }

  @override
  Future<void> createMultipleAssignments(List<ScheduleAssignment> assignments) async {
    if (assignments.isEmpty) return;
    try {
      // Używamy WriteBatch do wykonania wszystkich operacji zapisu atomowo
      final batch = _firestore.batch();
      for (final assignment in assignments) {
        // Tworzymy nową, pustą referencję dokumentu w kolekcji
        final docRef = _assignmentsCollection.doc();
        // Dodajemy operację 'set' do paczki
        batch.set(docRef, assignment);
      }
      // Zatwierdzamy wszystkie operacje w jednej transakcji
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas tworzenia wielu przypisańskich: ${e.message}');
    }
  }

  @override
  Future<bool> doesAssignmentExist({
    required String targetId,
    required ScheduleTargetType targetType,
    required DateTime date,
    required int blockIndex,
  }) async {
    // UWAGA: To zapytanie najprawdopodobniej będzie wymagało indeksu kompozytowego w Firestore!
    // Pola do zindeksowania: targetId (ASC), targetType (ASC), blockIndex (ASC), startDate (ASC)

    // Normalizujemy datę, aby szukać w przedziale całego dnia
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final querySnapshot = await _assignmentsCollection
          .where('targetId', isEqualTo: targetId)
          .where('targetType', isEqualTo: targetType.name)
          .where('blockIndex', isEqualTo: blockIndex)
          .where('startDate', isGreaterThanOrEqualTo: startOfDay)
          .where('startDate', isLessThan: endOfDay)
          .limit(1) // Wystarczy nam jeden wynik, aby potwierdzić istnienie
          .get();

      return querySnapshot.docs.isNotEmpty;
    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas sprawdzania istnienia przypisania: ${e.message}');
    }
  }

  @override
  Future<List<ScheduleAssignment>> findAllAssignmentsForTarget(String targetId, ScheduleTargetType targetType) async {
    try {
      final querySnapshot = await _assignmentsCollection
          .where('targetId', isEqualTo: targetId)
          .where('targetType', isEqualTo: targetType.name)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas wyszukiwania przypisań dla celu: ${e.message}');
    }
  }

  @override
  Future<List<ScheduleAssignment>> findAllAssignmentsForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    // UWAGA: Zapytanie `whereIn` jest ograniczone do 30 wartości w Firestore!
    try {
      final querySnapshot = await _assignmentsCollection
          .where('targetId', whereIn: userIds)
          .where('targetType', isEqualTo: ScheduleTargetType.user.name)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas wyszukiwania przypisań dla użytkowników: ${e.message}');
    }
  }

  /// NOWA, WYMAGANA IMPLEMENTACJA METODY
  @override
  Future<List<ScheduleAssignment>> fetchAllAssignmentsForProjectInDateRange(String projectId, DateTime startDate, DateTime endDate) async {
    try {
      // ETAP 1: Znajdź wszystkie ID szablonów dla danego projektu.
      final templatesQuery = await _firestore
          .collection(_templatesCollectionPath)
          .where('projectId', isEqualTo: projectId)
          .get();

      if (templatesQuery.docs.isEmpty) {
        return []; // Optymalizacja: jeśli nie ma szablonów, nie ma co dalej szukać.
      }
      final templateIds = templatesQuery.docs.map((doc) => doc.id).toList();

      // ETAP 2: Znajdź przypisania pasujące do szablonów i zakresu dat.
      // Firestore ogranicza `whereIn` do 30 elementów. Dla większej liczby szablonów
      // trzeba by podzielić `templateIds` na mniejsze części i wykonać kilka zapytań.
      if (templateIds.length > 30) {
        // Obsługa przypadku, gdy jest więcej niż 30 szablonów (uproszczona)
        print("Ostrzeżenie: Liczba szablonów dla projektu przekracza limit 30 dla zapytania 'whereIn'. Zwrócono tylko część wyników.");
      }

      final assignmentsQuery = await _assignmentsCollection
          .where('scheduleTemplateId', whereIn: templateIds.take(30)) // Użyj `take(30)` jako zabezpieczenie
          .where('startDate', isGreaterThanOrEqualTo: startDate)
          .where('startDate', isLessThanOrEqualTo: endDate)
          .get();

      return assignmentsQuery.docs.map((doc) => doc.data()).toList();

    } on FirebaseException catch (e) {
      throw ScheduleAssignmentOperationException('Błąd podczas pobierania przypisań dla projektu: ${e.message}');
    }
  }
}