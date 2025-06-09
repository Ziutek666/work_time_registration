import '../models/work_type.dart'; // Zakładamy, że ten model WorkType jest wersją BEZ pola isInitiatingAction/isStart
import '../repositories/work_type_repository.dart';
// import '../repositories/work_type_exceptions.dart';


class WorkTypeService {
  final WorkTypeRepository _repository;

  WorkTypeService(this._repository);

  Future<WorkType> getWorkType(String workTypeId) async {
    if (workTypeId.isEmpty) {
      throw ArgumentError("workTypeId nie może być pusty podczas pobierania typu pracy.");
    }
    return _repository.getWorkType(workTypeId);
  }

  Future<List<WorkType>> getAllWorkTypesForProject(String projectId) async {
    if (projectId.isEmpty) {
      throw ArgumentError("projectId nie może być pusty podczas pobierania typów pracy dla projektu.");
    }
    return _repository.getAllWorkTypesForProject(projectId);
  }
  Future<List<WorkType>> getSubOrBreakWorkTypesForProject(String projectId) async {
    if (projectId.isEmpty) {
      throw ArgumentError("projectId nie może być pusty podczas pobierania typów pracy dla projektu.");
    }
    return _repository.getSubOrBreakWorkTypesForProject(projectId);
  }
  Future<List<WorkType>> getMainWorkTypesForProject(String projectId) async {
    if (projectId.isEmpty) {
      throw ArgumentError("projectId nie może być pusty podczas pobierania typów pracy dla projektu.");
    }
    return _repository.getMainWorkTypesForProject(projectId);
  }

  Future<List<WorkType>> getWorkTypesByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    try {
      return await _repository.fetchWorkTypesByIds(ids);
    } catch (e) {
      print('Błąd w WorkTypeService.fetchWorkTypesByIds: $e');
      rethrow;
    }
  }

  Future<WorkType> createWorkType(WorkType workType) async {
    // Zakładamy, że workType tutaj jest "czystym" WorkType bez logiki isInitiatingAction
    if (workType.name.trim().isEmpty) {
      throw ArgumentError("Nazwa typu pracy nie może być pusta.");
    }
    if (workType.projectId.isEmpty || workType.ownerId.isEmpty) {
      throw ArgumentError("ProjectId oraz OwnerId są wymagane dla WorkType.");
    }
    return _repository.createWorkType(workType);
  }

  Future<void> updateWorkType(WorkType workType) async {
    // Zakładamy, że workType tutaj jest "czystym" WorkType
    if (workType.workTypeId.isEmpty) {
      throw ArgumentError("WorkType musi mieć ustawione workTypeId do aktualizacji.");
    }
    if (workType.name.trim().isEmpty) {
      throw ArgumentError("Nazwa typu pracy nie może być pusta.");
    }
    return _repository.updateWorkType(workType);
  }

  Future<void> deleteWorkType(String workTypeId) async {
    if (workTypeId.isEmpty) {
      throw ArgumentError("workTypeId nie może być pusty do usunięcia.");
    }
    return _repository.deleteWorkType(workTypeId);
  }

  Future<void> saveLastUserWorkAction(WorkType lastActionWorkType) async {
    // lastActionWorkType będzie instancją WorkType z generateAvailableUserActions.
    // Jej nazwa może być poprzedzona prefiksem ("START: ...").
    // Sam model WorkType nie ma pola isInitiatingAction, więc nie będzie ono w toMap().
    if (lastActionWorkType.userId == null || lastActionWorkType.userId!.isEmpty) {
      throw ArgumentError('WorkType.userId nie może być puste podczas zapisywania ostatniej akcji użytkownika.');
    }
    try {
      return await _repository.saveLastUserWorkAction(lastActionWorkType);
    } catch (e) {
      print('Błąd w WorkTypeService.saveLastUserWorkAction: $e');
      rethrow;
    }
  }

  Future<void> clearUserAction(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId nie może być puste podczas usuwania ostatniej akcji użytkownika.');
    }
    try {
      return await _repository.clearUserAction(userId);
    } catch (e) {
      print('Błąd w WorkTypeService.clearUserAction: $e');
      rethrow;
    }
  }

  Future<WorkType?> getLastUserWorkAction(String userId) async {
    // Zwróci WorkType tak, jak jest zapisany, potencjalnie z prefiksem w nazwie.
    // Nie będzie miał pola isInitiatingAction wypełnionego z Firestore,
    // ponieważ model WorkType nie definiuje go do persystencji.
    if (userId.isEmpty) {
      throw ArgumentError("userId nie może być pusty podczas pobierania ostatniej akcji użytkownika.");
    }
    try {
      return await _repository.getLastUserWorkAction(userId);
    } catch (e) {
      print('Błąd w WorkTypeService.getLastUserWorkAction: $e');
      rethrow;
    }
  }

  /// Filtruje i modyfikuje listę WorkType na podstawie ostatniej akcji użytkownika.
  Future<List<WorkType>> generateAvailableUserActions({
    required String userId,
    required String projectId,
    required List<WorkType> fetchedWorkTypes,
    // String? ownerId, // Może być potrzebny do tworzenia fallbacków
  }) async {
    final WorkType? lastUserAction = await this.getLastUserWorkAction(userId);
    List<WorkType> displayableActions = [];
    final DateTime currentTime = DateTime.now();

    bool lastActionWasAStartEvent = false;
    // effectiveLastActionDetails przechowuje właściwości WorkType ostatniej akcji.
    // Jego nazwa może mieć prefiks, ale inne właściwości (isBreak, isSubTask) są z oryginału.
    WorkType? effectiveLastActionDetails = lastUserAction;

    if (lastUserAction != null) {
      lastActionWasAStartEvent = lastUserAction.name.startsWith("START:");
    }

    if (lastActionWasAStartEvent && effectiveLastActionDetails != null) {
      // STAN: Użytkownik jest W TRAKCIE akcji (ostatnia zapisana akcja była typu START)
      // effectiveLastActionDetails odnosi się do WorkType, który został ROZPOCZĘTY.
      // Jego właściwości .isBreak, .isSubTask są właściwościami oryginalnego WorkType.

      if (effectiveLastActionDetails.isBreak) {
        // Użytkownik jest NA PRZERWIE. Może tylko zakończyć tę przerwę.
        // Znajdź oryginalny WorkType, aby uzyskać czystą nazwę dla wyświetlenia.
        WorkType? originalBreakType = fetchedWorkTypes.firstWhere(
                (wt) => wt.workTypeId == effectiveLastActionDetails!.workTypeId,
            orElse: () => effectiveLastActionDetails // Fallback na wypadek gdyby nie znaleziono
        );
        displayableActions.add(originalBreakType.copyWith( // copyWith nie ma już isInitiatingAction
          name: "ZAKOŃCZ: ${originalBreakType.name}", // Użyj nazwy oryginalnego typu pracy
          userId: userId,
        ));
      } else if (effectiveLastActionDetails.isSubTask) {
        // Użytkownik wykonuje POD-ZADANIE. Może tylko zakończyć to pod-zadanie.
        WorkType? originalSubTaskType = fetchedWorkTypes.firstWhere(
                (wt) => wt.workTypeId == effectiveLastActionDetails!.workTypeId,
            orElse: () => effectiveLastActionDetails
        );
        displayableActions.add(originalSubTaskType.copyWith(
          name: "ZAKOŃCZ: ${originalSubTaskType.name}",
          userId: userId,
        ));
      } else {
        // Użytkownik jest w trakcie PRACY GŁÓWNEJ (nie przerwa, nie pod-zadanie).
        // Powinien widzieć opcje rozpoczęcia przerwy, pod-zadania ORAZ zakończenia aktywnej pracy.

        // 1. Opcje rozpoczęcia przerwy lub pod-zadania
        var startBreakOrSubtaskActions = fetchedWorkTypes.where((wt) => wt.isBreak || wt.isSubTask).toList();
        for (var originalWorkType in startBreakOrSubtaskActions) {
          displayableActions.add(originalWorkType.copyWith(
            name: "START: ${originalWorkType.name}",
            userId: userId,
          ));
        }

        // 2. Opcja zakończenia pracy głównej (która jest `effectiveLastActionDetails`)
        WorkType? mainWorkToEnd = fetchedWorkTypes.firstWhere(
                (wt) => wt.workTypeId == effectiveLastActionDetails!.workTypeId,
            orElse: () => effectiveLastActionDetails
        );
        // Dodatkowo sprawdź, czy to faktycznie praca główna (nie przerwa, nie podzadanie)
        if (!mainWorkToEnd.isBreak && !mainWorkToEnd.isSubTask) {
          displayableActions.add(mainWorkToEnd.copyWith(
            name: "ZAKOŃCZ: ${mainWorkToEnd.name}",
            userId: userId,
          ));
        }
      }
    } else {
      // STAN: Użytkownik jest "bezczynny" (brak ostatniej akcji START, lub ostatnia akcja była ZAKOŃCZ).
      // Pokazujemy opcje START dla zadań głównych (nie-przerwa, nie-podzadanie).
      var initialActions = fetchedWorkTypes.where((wt) {
        return !wt.isBreak && !wt.isSubTask;
      }).toList();

      for (var originalWorkType in initialActions) {
        displayableActions.add(originalWorkType.copyWith(
          name: "START: ${originalWorkType.name}",
          userId: userId,
        ));
      }
      if (initialActions.isEmpty && fetchedWorkTypes.isNotEmpty) {
        print("Brak dostępnych akcji początkowych (nie-przerwa, nie-podzadanie) dla projektu $projectId. Dostępne typy: ${fetchedWorkTypes.map((e) => e.name).toList()}");
      }
    }

    // Zamiast mapy usuwającej duplikaty po workTypeId (co było problematyczne),
    // zwracamy bezpośrednio listę. Zakładamy, że logika powyżej generuje
    // poprawne, unikalne (w kontekście wyświetlania) akcje.
    return displayableActions;
  }
}
// Inicjalizacja instancji serwisu
WorkTypeService workTypeService = WorkTypeService(WorkTypeRepository()); // To powinno być w miejscu inicjalizacji zależności
