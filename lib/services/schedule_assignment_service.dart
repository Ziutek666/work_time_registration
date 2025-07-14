import 'package:intl/intl.dart';
import 'package:work_time_registration/services/user_service.dart';

import '../exceptions/schedule_assignment_exceptions.dart';
import '../models/schedule_assignments.dart';
import '../models/schedule_template.dart';
import '../repositories/schedule_assignment_repository.dart';

class ScheduleAssignmentService {
  final IScheduleAssignmentRepository _repository;
  ScheduleAssignmentService(this._repository);

  // --- NOWOŚĆ: Centralna metoda walidacji ---
  /// Sprawdza, czy lista proponowanych przypisań nie koliduje z już istniejącymi dla danego użytkownika.
  Future<void> validateOverlappingAssignments(
      List<ScheduleAssignment> proposedAssignments, String userId) async {
    if (proposedAssignments.isEmpty) {
      return;
    }

    // 1. Pobierz wszystkie istniejące przypisania dla danego użytkownika
    final allExistingAssignments = await _repository.findAllAssignmentsForUsers([userId]);

    // 2. Połącz istniejące i proponowane przypisania w jedną listę
    final allConsideredAssignments = [...allExistingAssignments, ...proposedAssignments];

    // Nie ma czego sprawdzać, jeśli jest mniej niż 2 przypisania
    if (allConsideredAssignments.length < 2) {
      return;
    }

    // 3. Sortuj wszystkie przypisania chronologicznie
    allConsideredAssignments.sort((a, b) => a.startDate.compareTo(b.startDate));

    // 4. Sprawdź, czy którekolwiek dwa kolejne przypisania na siebie nachodzą
    for (int i = 0; i < allConsideredAssignments.length - 1; i++) {
      final current = allConsideredAssignments[i];
      final next = allConsideredAssignments[i + 1];

      // Sprawdź, czy endDate na pewno nie jest nullem przed porównaniem
      if (current.endDate != null && current.endDate!.isAfter(next.startDate)) {
        final user = await userService.getUserData(userId);
        final dateStr = DateFormat('dd.MM.yyyy').format(current.startDate);
        throw Exception(
            'Konflikt harmonogramu dla ${user?.displayName ?? userId}! '
                'Pracownik jest już przypisany w dniu $dateStr w godzinach, które nachodzą na siebie.');
      }
    }
  }

  /// Tworzy nowe, pojedyncze przypisanie po walidacji.
  Future<String> createAssignmentWithId(ScheduleAssignment assignment) async {
    if (assignment.scheduleTemplateId.isEmpty || assignment.targetId.isEmpty) {
      throw ScheduleAssignmentValidationException('ID szablonu i obiektu docelowego nie mogą być puste.');
    }
    // Walidacja konfliktu dla tego jednego przypisania
    await validateOverlappingAssignments([assignment], assignment.targetId);

    return await _repository.createAssignment(assignment);
  }

  /// Tworzy wiele przypisań w jednej operacji.
  Future<void> createMultipleAssignments(List<ScheduleAssignment> assignments) async {
    if (assignments.isEmpty) return;
    // Walidacja nie jest tu potrzebna, ponieważ jest wywoływana w UI przed tą metodą
    await _repository.createMultipleAssignments(assignments);
  }

  /// Tworzy nowe, pojedyncze przypisanie, sprawdzając precyzyjnie konflikt.
  Future<String> createAssignment(ScheduleAssignment assignment) async {
    // Podstawowa walidacja
    if (assignment.scheduleTemplateId.isEmpty || assignment.targetId.isEmpty) {
      throw ScheduleAssignmentValidationException('ID szablonu i obiektu docelowego nie mogą być puste.');
    }

    // NOWA LOGIKA KONFLIKTU: Sprawdza, czy DOKŁADNIE takie samo przypisanie już istnieje.
    // Zakładamy, że repozytorium ma metodę do sprawdzania po dacie i indeksie bloku.
    final bool hasConflict = await _repository.doesAssignmentExist(
      targetId: assignment.targetId,
      targetType: assignment.targetType,
      date: assignment.startDate,
      blockIndex: assignment.blockIndex,
    );

    if (hasConflict) {
      final user = await userService.getUserData(assignment.targetId);
      final userName = user?.displayName ?? assignment.targetId;
      final dateStr = DateFormat('dd.MM.yyyy').format(assignment.startDate);
      throw ScheduleAssignmentConflictException(
          'Pracownik "$userName" jest już przypisany do tego bloku w dniu $dateStr.');
    }

    return await _repository.createAssignment(assignment);
  }

  Future<List<ScheduleAssignment>> getAllAssignmentsForUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    return await _repository.findAllAssignmentsForUsers(userIds);
  }

  /// Aktualizuje istniejące przypisanie.
  Future<void> updateAssignment(ScheduleAssignment assignment) async {
    if (assignment.assignmentId.isEmpty) {
      throw ScheduleAssignmentValidationException('ID przypisania jest wymagane do aktualizacji.');
    }
    await _repository.updateAssignment(assignment);
  }

  /// Usuwa przypisanie o podanym ID.
  Future<void> deleteAssignment(String assignmentId) async {
    if (assignmentId.isEmpty) {
      throw ScheduleAssignmentValidationException('ID przypisania jest wymagane do usunięcia.');
    }
    await _repository.deleteAssignment(assignmentId);
  }

  /// Pobiera listę wszystkich przypisań dla konkretnego szablonu harmonogramu.
  Future<List<ScheduleAssignment>> getAssignmentsForTemplate(String templateId) async {
    if (templateId.isEmpty) return [];
    return await _repository.findAllAssignmentsForTemplate(templateId);
  }

  // NOWA METODA
  /// Pobiera wszystkie przypisania dla konkretnego użytkownika.
  Future<List<ScheduleAssignment>> getAssignmentsForUser(String userId) async {
    if (userId.isEmpty) {
      return [];
    }
    // Wykorzystuje istniejącą, bardziej generyczną metodę
    return await _repository.findAllAssignmentsForUsers([userId]);
  }

  /// Sprawdza, czy dany szablon jest gdziekolwiek aktywnie używany.
  Future<bool> isTemplateInUse(String templateId) async {
    final assignments = await _repository.findAllAssignmentsForTemplate(templateId);
    return assignments.any((a) => a.isActive);
  }

  // UWAGA: Poniższe metody są oparte na starym modelu (zakres dat i jedno aktywne przypisanie).
  // Mogą wymagać refaktoryzacji, jeśli będą używane w nowych częściach aplikacji.

  /// Deaktywuje (zakańcza) aktywne przypisanie dla danego obiektu.
  /// UWAGA: Ta logika zakłada tylko jedno aktywne przypisanie na raz.
  Future<void> deactivateAssignmentForTarget(String targetId, ScheduleTargetType targetType) async {
    final assignment = await _repository.findActiveAssignmentForTarget(targetId, targetType);
    if (assignment == null) return;
    final updatedAssignment = assignment.copyWith(isActive: false, endDate: DateTime.now());
    await _repository.updateAssignment(updatedAssignment);
  }
  /// Niezbędna dla ekranu analizy AI, aby pobierać dane w kontekście projektu.
  ///
  Future<List<ScheduleAssignment>> getAllAssignmentsForProjectInDateRange(String projectId, DateTime startDate, DateTime endDate) async {
    if (projectId.isEmpty) {
      // Możesz rzucić własny, dedykowany wyjątek
      throw Exception('ProjectID nie może być puste.');
    }

    try {
      // Wywołujemy nową, odpowiadającą funkcję w repozytorium
      return await _repository.fetchAllAssignmentsForProjectInDateRange(projectId, startDate, endDate);
    } catch (e) {
      rethrow;
    }
  }
  /// Znajduje aktywne przypisanie dla danego obiektu.
  /// UWAGA: Ta logika zakłada tylko jedno aktywne przypisanie na raz.
  Future<ScheduleAssignment?> findActiveAssignment(String targetId, ScheduleTargetType targetType) async {
    return await _repository.findActiveAssignmentForTarget(targetId, targetType);
  }
}

/// Globalna instancja serwisu do użytku w całej aplikacji.
final scheduleAssignmentService = ScheduleAssignmentService(ScheduleAssignmentRepository());