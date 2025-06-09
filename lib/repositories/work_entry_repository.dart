import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/work_entry_exceptions.dart';
import '../models/work_entry.dart';

class WorkEntryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'workEntries';

  CollectionReference<Map<String, dynamic>> get _workEntriesCollection {
    return _firestore.collection(_collectionPath);
  }

  Future<WorkEntry?> getLastEventForWorkType(String userId, String projectId, String workTypeId) async {
    print('WorkEntryRepository: Pobieranie ostatniego zdarzenia dla userId: $userId, projectId: $projectId, workTypeId: $workTypeId');
    try {
      final querySnapshot = await _workEntriesCollection
          .where('userId', isEqualTo: userId)
          .where('projectId', isEqualTo: projectId)
          .where('workTypeId', isEqualTo: workTypeId)
          .orderBy('eventActionTimestamp', descending: true) // ZMIANA
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return WorkEntry.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e, s) {
      print("Error in getLastEventForWorkType (repo): $e\n$s");
      return null;
    }
  }

  Future<WorkEntry?> getLatestEventForUserInProject(String userId, String projectId) async {
    print('WorkEntryRepository: Pobieranie ostatniego zdarzenia dla userId: $userId w projectId: $projectId');
    try {
      final querySnapshot = await _workEntriesCollection
          .where('userId', isEqualTo: userId)
          .where('projectId', isEqualTo: projectId)
          .orderBy('eventActionTimestamp', descending: true) // ZMIANA
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return WorkEntry.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e, s) {
      print("Error in getLatestEventForUserInProject (repo): $e\n$s");
      return null;
    }
  }

  Future<WorkEntry?> getLatestEventForUser(String userId) async {
    print('WorkEntryRepository: Pobieranie ostatniego zdarzenia dla userId: $userId');
    try {
      final querySnapshot = await _workEntriesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('eventActionTimestamp', descending: true) // ZMIANA
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return WorkEntry.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e, s) {
      print("Error in getLatestEventForUser (repo): $e\n$s");
      return null;
    }
  }

  Future<WorkEntry?> getLatestMainEventForUserInProject(String userId, String projectId) async {
    print('WorkEntryRepository: Pobieranie ostatniego GŁÓWNEGO zdarzenia dla userId: $userId w projectId: $projectId');
    try {
      final querySnapshot = await _workEntriesCollection
          .where('userId', isEqualTo: userId)
          .where('projectId', isEqualTo: projectId)
          .where('workTypeIsSubTask', isEqualTo: false)
          .where('workTypeIsBreak', isEqualTo: false)
          .orderBy('eventActionTimestamp', descending: true) // ZMIANA
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return WorkEntry.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e, s) {
      print("Error in getLatestMainEventForUserInProject (repo): $e\n$s");
      return null;
    }
  }

  Future<WorkEntry?> getWorkEntryById(String entryId) async {
    print('WorkEntryRepository: Pobieranie wpisu o ID: $entryId');
    try {
      final doc = await _workEntriesCollection.doc(entryId).get();
      if (doc.exists) {
        return WorkEntry.fromFirestore(doc);
      }
      return null;
    } catch (e, s) {
      print("Error in getWorkEntryById (repo) for ID $entryId: $e\n$s");
      return null;
    }
  }

  Future<String> createWorkEntry(WorkEntry entry) async {
    print('WorkEntryRepository: Tworzenie nowego wpisu: ${entry.workTypeName}, isStart: ${entry.isStart}');
    try {
      final docRef = await _workEntriesCollection.add(entry.toMap());
      print('WorkEntryRepository: Utworzono wpis o ID: ${docRef.id}');
      return docRef.id;
    } catch (e, s) {
      print("Error in createWorkEntry (repo): $e\n$s");
      throw Exception("Nie udało się utworzyć wpisu pracy: ${e.toString()}");
    }
  }

  Future<List<WorkEntry>> getWorkEntriesForUserBetweenDates(String userId, DateTime startDate, DateTime endDate) async {
    print('WorkEntryRepository: Pobieranie wpisów dla userId: $userId między $startDate a $endDate');
    try {
      final querySnapshot = await _workEntriesCollection
          .where('userId', isEqualTo: userId)
          .where('eventActionTimestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate)) // ZMIANA
          .where('eventActionTimestamp', isLessThan: Timestamp.fromDate(endDate)) // ZMIANA
          .orderBy('eventActionTimestamp', descending: true) // ZMIANA
          .get();

      final entries = querySnapshot.docs.map((doc) => WorkEntry.fromFirestore(doc)).toList();
      print('WorkEntryRepository: Znaleziono ${entries.length} wpisów.');
      return entries;
    } catch (e, s) {
      print("Error in getWorkEntriesForUserBetweenDates (repo): $e\n$s");
      throw Exception("Nie udało się pobrać historii pracy: ${e.toString()}");
    }
  }

  /// Pobiera wszystkie wpisy pracy dla listy projektów w określonym zakresie dat.
  Future<List<WorkEntry>> getWorkEntriesForProjectsBetweenDates(List<String> projectIds, DateTime startDate, DateTime endDate) async {
    print('WorkEntryRepository: Pobieranie wpisów dla ${projectIds.length} projektów między $startDate a $endDate');
    if (projectIds.isEmpty) {
      return [];
    }

    try {
      final List<WorkEntry> allEntries = [];
      // Zapytania 'in' w Firestore są ograniczone do 30 wartości.
      // Dzielimy listę ID projektów na mniejsze części, jeśli jest to konieczne.
      for (var i = 0; i < projectIds.length; i += 30) {
        final sublist = projectIds.sublist(i, i + 30 > projectIds.length ? projectIds.length : i + 30);

        final querySnapshot = await _workEntriesCollection
            .where('projectId', whereIn: sublist)
            .where('eventActionTimestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate)) // ZMIANA
            .where('eventActionTimestamp', isLessThan: Timestamp.fromDate(endDate)) // ZMIANA
            .get();

        final entries = querySnapshot.docs.map((doc) => WorkEntry.fromFirestore(doc)).toList();
        allEntries.addAll(entries);
      }

      // Posortuj wszystkie wyniki po stronie klienta, ponieważ były pobierane w częściach
      allEntries.sort((a, b) => b.eventActionTimestamp.compareTo(a.eventActionTimestamp)); // ZMIANA

      print('WorkEntryRepository: Znaleziono łącznie ${allEntries.length} wpisów.');
      return allEntries;
    } catch (e, s) {
      print("Error in getWorkEntriesForProjectsBetweenDates (repo): $e\n$s");
      throw Exception("Nie udało się pobrać historii pracy dla projektów: ${e.toString()}");
    }
  }

}

// Globalna instancja repozytorium. Rozważ użycie DI (Dependency Injection) dla lepszej testowalności i zarządzania zależnościami.
final workEntryRepository = WorkEntryRepository();
