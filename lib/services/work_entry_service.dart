import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/work_entry_exceptions.dart';
import '../models/information.dart';
import '../models/work_entry.dart'; // Assuming this is the updated WorkEntry model
import '../models/work_type.dart'; // Assuming this is the updated WorkType model (without isInitiatingAction)
import '../repositories/work_entry_repository.dart';
import 'information_service.dart';

class WorkEntryService {
  final WorkEntryRepository _repository;
  final InformationService _informationService;

  WorkEntryService(this._repository, this._informationService);

  /// Rejestruje zdarzenie pracy (rozpoczęcie lub zakończenie).
  /// Tworzy nowy wpis `WorkEntry` w bazie danych.
  Future<WorkEntry> recordWorkEvent({
    required String userId,
    required String projectId,
    required String areaId,
    required WorkType workTypeSnapshot,
    required bool isStartingEvent,
    String? description,
    List<Information>? relatedInformations,
    Timestamp? customEventTimestamp, // Czas kliknięcia przycisku
    String? parentWorkEntryId,
  }) async {
    if (userId.isEmpty || projectId.isEmpty || areaId.isEmpty || workTypeSnapshot.workTypeId.isEmpty) {
      throw ArgumentError('UserID, ProjectID, AreaID oraz WorkTypeID (w snapshot) nie mogą być puste.');
    }

    if (isStartingEvent) {
      final lastEventForThisWorkType = await _repository.getLastEventForWorkType(userId, projectId, workTypeSnapshot.workTypeId);
      if (lastEventForThisWorkType != null && lastEventForThisWorkType.isStart) {
        throw ActiveWorkEntryExistsException(
            "Użytkownik $userId już ma aktywną pracę typu '${workTypeSnapshot.name}' w projekcie $projectId.");
      }
    } else {
      final lastEventForThisWorkType = await _repository.getLastEventForWorkType(userId, projectId, workTypeSnapshot.workTypeId);
      if (lastEventForThisWorkType == null || !lastEventForThisWorkType.isStart) {
        throw NoActiveWorkEntryToStopException(
            "Brak aktywnej pracy typu '${workTypeSnapshot.name}' do zatrzymania dla użytkownika $userId w projekcie $projectId.");
      }
    }

    // Czas kliknięcia przez użytkownika
    final resolvedActionTimestamp = customEventTimestamp ?? Timestamp.now();
    // Czas zapisu do bazy danych
    final resolvedSaveTimestamp = Timestamp.now();

    final newEventEntry = WorkEntry(
      entryId: '',
      userId: userId,
      projectId: projectId,
      areaId: areaId,
      workTypeId: workTypeSnapshot.workTypeId,
      workTypeName: workTypeSnapshot.name,
      workTypeDescription: workTypeSnapshot.description,
      workTypeDefaultDurationInSeconds: workTypeSnapshot.defaultDuration?.inSeconds,
      workTypeIsBreak: workTypeSnapshot.isBreak,
      workTypeIsPaid: workTypeSnapshot.isPaid,
      workTypeIsSubTask: workTypeSnapshot.isSubTask,
      workTypeInformationIds: workTypeSnapshot.informationIds,
      // ZMIENIONE POLA CZASU
      eventActionTimestamp: resolvedActionTimestamp,
      saveTimestamp: resolvedSaveTimestamp,
      isStart: isStartingEvent,
      description: description,
      parentWorkEntryId: parentWorkEntryId,
      relatedInformations: relatedInformations,
    );

    try {
      final entryId = await _repository.createWorkEntry(newEventEntry);
      return newEventEntry.copyWith(entryId: entryId);
    } catch (e) {
      print('WorkEntryService Error recording work event: $e');
      rethrow;
    }
  }

  Future<WorkEntry?> getLastEventForWorkType(String userId, String projectId, String workTypeId) async {
    if (userId.isEmpty || projectId.isEmpty || workTypeId.isEmpty) {
      print('WorkEntryService.getLastEventForWorkType: Błędne argumenty (puste ID).');
      return null;
    }
    try {
      return await _repository.getLastEventForWorkType(userId, projectId, workTypeId);
    } catch (e) {
      print('WorkEntryService Error fetching last event for work type $workTypeId: $e');
      return null;
    }
  }

  Future<WorkEntry?> getLatestActiveEventForUserInProject(String userId, String projectId) async {
    if (userId.isEmpty || projectId.isEmpty) {
      print('WorkEntryService.getLatestActiveEventForUserInProject: Błędne argumenty (puste ID).');
      return null;
    }
    try {
      WorkEntry? latestEvent = await _repository.getLatestEventForUserInProject(userId, projectId);
      if (latestEvent != null && latestEvent.isStart) {
        return latestEvent;
      }
      return null;
    } catch (e) {
      print('WorkEntryService Error fetching latest active event for user $userId in project $projectId: $e');
      return null;
    }
  }

  Future<WorkEntry?> getLatestEventForUser(String userId) async {
    if (userId.isEmpty) {
      print('WorkEntryService.getLatestEventForUser: Pusty userId.');
      return null;
    }
    try {
      return await _repository.getLatestEventForUser(userId);
    } catch (e) {
      print('WorkEntryService Error fetching latest event for user $userId: $e');
      return null;
    }
  }

  Future<WorkEntry?> getLatestMainActiveEventForUserInProject(String userId,String projectId) async {
    if (userId.isEmpty || projectId.isEmpty) {
      print('WorkEntryService.getLatestMainActiveEventForUserInProject: Puste ID.');
      return null;
    }
    try {
      WorkEntry? latestMainEvent = await _repository.getLatestMainEventForUserInProject(userId,projectId);
      if (latestMainEvent != null && latestMainEvent.isStart) {
        return latestMainEvent;
      }
      return null;
    } catch (e) {
      print('WorkEntryService Error fetching latest main active event for user $userId in project $projectId: $e');
      return null;
    }
  }

  Future<List<WorkEntry>> getWorkEntriesForUserBetweenDates(String userId, DateTime startDate, DateTime endDate) async {
    if (userId.isEmpty) {
      print('WorkEntryService.getWorkEntriesForUserBetweenDates: Pusty userId.');
      return [];
    }
    try {
      return await _repository.getWorkEntriesForUserBetweenDates(userId, startDate, endDate);
    } catch (e) {
      print('WorkEntryService Error fetching work entries between dates for user $userId: $e');
      return [];
    }
  }

  Future<List<WorkEntry>> getWorkEntriesForProjectsBetweenDates(List<String> projectIds, DateTime startDate, DateTime endDate) async {
    if (projectIds.isEmpty) {
      return [];
    }
    try {
      return await _repository.getWorkEntriesForProjectsBetweenDates(projectIds, startDate, endDate);
    } catch (e) {
      print('WorkEntryService Error fetching work entries for projects: $e');
      return [];
    }
  }
}
final WorkEntryService workEntryService = WorkEntryService(workEntryRepository, informationService);
