import '../exceptions/schedule_template_exceptions.dart';
import '../models/schedule_template.dart';
import '../repositories/schedule_template_repository.dart';

class ScheduleTemplateService {
  final IScheduleTemplateRepository _repository;

  ScheduleTemplateService(this._repository);

  /// Tworzy nowy szablon harmonogramu, przeprowadzając walidację.
  Future<String> createTemplate({
    required String name,
    required String ownerId,
    required String projectId,
    String description = '',
    required List<ScheduleBlock> blocks,
    required ScheduleTargetType targetType,
    required String areaId,
  }) async {
    if (name.trim().isEmpty) {
      throw ScheduleTemplateValidationException('Nazwa szablonu nie może być pusta.');
    }
    if (blocks.isEmpty) {
      throw ScheduleTemplateValidationException('Szablon musi zawierać co najmniej jeden blok czasowy.');
    }

    final newTemplate = ScheduleTemplate(
      name: name,
      ownerId: ownerId,
      projectId: projectId,
      description: description,
      scheduleBlocks: blocks,
      // ZMIANA: Przekazujemy nowy parametr do konstruktora modelu.
      targetType: targetType,
      areaId: areaId
    );

    return await _repository.createScheduleTemplate(newTemplate);
  }

  /// Aktualizuje istniejący szablon.
  Future<void> updateTemplate(ScheduleTemplate template) async {
    if (template.name.trim().isEmpty) {
      throw ScheduleTemplateValidationException('Nazwa szablonu nie może być pusta.');
    }
    // Ta metoda nie wymaga zmian, ponieważ operuje na całym obiekcie,
    // który już zawiera zaktualizowany 'targetType'.
    await _repository.updateScheduleTemplate(template);
  }

  /// Pobiera pojedynczy szablon po jego ID.
  Future<ScheduleTemplate> getTemplate(String templateId) async {
    if (templateId.isEmpty) {
      throw ScheduleTemplateValidationException('ID szablonu jest wymagane.');
    }
    return await _repository.getScheduleTemplateById(templateId);
  }

  /// Pobiera wszystkie szablony dla danego właściciela (np. firmy, admina).
  Future<List<ScheduleTemplate>> getTemplatesForOwner(String ownerId) async {
    if (ownerId.isEmpty) {
      throw ScheduleTemplateValidationException('ID właściciela jest wymagane.');
    }
    return await _repository.getAllTemplatesForOwner(ownerId);
  }
  Future<List<ScheduleTemplate>> getTemplatesForProject(String projectId) async {
    if (projectId.isEmpty) {
      throw ScheduleTemplateValidationException('ID projektu jest wymagane.');
    }
    return await _repository.getTemplatesForProject(projectId);
  }
  /// Usuwa szablon.
  Future<void> deleteTemplate(String templateId) async {
    // Tutaj można dodać logikę sprawdzającą, czy szablon nie jest obecnie
    // przypisany do żadnego pracownika przed usunięciem.
    // Na przykład:
    // final assignments = await _assignmentService.findAssignmentsForTemplate(templateId);
    // if (assignments.isNotEmpty) {
    //   throw ScheduleTemplateOperationException('Nie można usunąć szablonu, ponieważ jest w użyciu.');
    // }

    await _repository.deleteScheduleTemplate(templateId);
  }
}

/// Globalna instancja serwisu
final scheduleTemplateService = ScheduleTemplateService(ScheduleTemplateRepository());