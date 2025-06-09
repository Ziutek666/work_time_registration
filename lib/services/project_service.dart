import '../exceptions/project_exception.dart';
import '../models/project.dart';
import '../repositories/project_repository.dart';

class ProjectService {
  final ProjectRepository _projectRepository = ProjectRepository();

  Future<Project> getProject(String projectId) async {
    try {
      return await _projectRepository.getProject(projectId);
    } on ProjectNotFoundException {
      rethrow;
    } catch (e) {
      throw ProjectFetchException('Wystąpił błąd podczas pobierania projektu: $e');
    }
  }

  Future<List<Project>> getProjectsByOwner(String ownerId) async {
    try {
      return await _projectRepository.getProjectsByOwner(ownerId);
    } on NoProjectsFoundException {
      rethrow;
    } catch (e) {
      throw ProjectFetchException('Wystąpił błąd podczas pobierania projektów użytkownika: $e');
    }
  }

  Future<String> createProject(String ownerId, String name, {String description = ''}) async {
    try {
      final project = Project(ownerId: ownerId, name: name, projectId: '');
      return await _projectRepository.createProject(project);
    } catch (e) {
      throw ProjectCreationException('Nie udało się utworzyć projektu: $e');
    }
  }

  Future<void> updateProject(String projectId,{String name = '', String description = ''}) async {
    try {
      final existingProject = await _projectRepository.getProject(projectId);
      final updatedProject = existingProject.copyWith(
        name: name,
        description: description,
      );
      await _projectRepository.updateProject(updatedProject);
    } on ProjectNotFoundException {
      rethrow;
    } catch (e) {
      throw ProjectUpdateException('Wystąpił błąd podczas aktualizacji projektu: $e');
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      var project = await getProject(projectId);
      await _projectRepository.deleteProject(project.projectId);
    } catch (e) {
      throw ProjectDeletionException('Wystąpił błąd podczas usuwania projektu: $e');
    }
  }

  Future<List<Project>> fetchProjectsByIds(List<String> projectIds) async {
    final validProjectIds = projectIds.where((projectId) => projectId.isNotEmpty).toSet().toList();

    if (validProjectIds.isEmpty) {
      print('ProjectService: fetchProjectsByIds called with an empty or invalid list of project IDs.');
      return [];
    }

    try {
      final projects = await _projectRepository.getProjectsByIds(validProjectIds);
      // Nie aktualizujemy tutaj _cachedUser, ponieważ dotyczy to potencjalnie wielu użytkowników,
      // a _cachedUser jest tylko dla bieżącego.
      return projects;
    } on ProjectFetchException catch (e, s) {
      print('UserService: UserFetchException while fetching users by IDs: $e\n$s');
      throw ProjectFetchException('Wystąpił błąd podczas pobierania projektów: $e');
      return []; // Zwróć pustą listę w przypadku błędu z repozytorium
    } catch (e, s) {
      print('UserService: Unexpected error while fetching users by IDs: $e\n$s');
      throw ProjectFetchException('Wystąpił błąd podczas pobierania projektów: $e');
      return []; // Zwróć pustą listę w przypadku innego błędu
    }
  }
}

final projectService = ProjectService();