import 'package:cloud_firestore/cloud_firestore.dart'; // Dla Timestamp
import '../exceptions/project_member_exceptions.dart';
import '../models/project_member.dart';
import '../repositories/project_member_repository.dart';


class ProjectMemberService {
  final ProjectMemberRepository _repository = projectMemberRepository;

  Future<ProjectMember> addProjectMember({
    required String projectId,
    required String userId,
    required List<String> roles,
    List<String>? areaIds,
    Timestamp? dateAdded,
  }) async {
    if (projectId.isEmpty || userId.isEmpty || roles.isEmpty) {
      throw ArgumentError('ID projektu, ID użytkownika oraz role nie mogą być puste.');
    }
    ProjectMember? existingMember = await getProjectMemberByProjectAndUser(projectId, userId);
    if (existingMember != null) {
      throw ProjectMemberCreationException('Użytkownik "$userId" jest już członkiem projektu "$projectId". Rozważ aktualizację.');
    }
    final newMemberData = ProjectMember(
      id: '',
      projectId: projectId,
      userId: userId,
      roles: roles,
      areaIds: areaIds ?? [],
      dateAdded: dateAdded ?? Timestamp.now(),
    );
    try {
      final membershipId = await _repository.addMember(newMemberData);
      return newMemberData.copyWith(id: membershipId);
    } catch (e) {
      print('ProjectMemberService Error adding member: $e');
      rethrow;
    }
  }

  Future<ProjectMember?> getProjectMemberByProjectAndUser(String projectId, String userId) async {
    try {
      return await _repository.getMemberByProjectAndUser(projectId, userId);
    } catch (e) {
      print('ProjectMemberService Error fetching member by project and user: $e');
      rethrow;
    }
  }

  Future<List<ProjectMember>> getMembersByProjectId(String projectId) async {
    try {
      return await _repository.getMembersByProjectId(projectId);
    } catch (e) {
      print('ProjectMemberService Error fetching members for project: $e');
      rethrow;
    }
  }

  /// NOWA METODA: Pobiera wszystkich członków dla listy projektów.
  /// Jest to potrzebne dla ekranu historii administratora.
  Future<List<ProjectMember>> getMembersForAllProjects(List<String> projectIds) async {
    if (projectIds.isEmpty) {
      return [];
    }
    try {
      // Zakładamy, że repozytorium ma metodę 'getMembersForProjects'
      // która obsługuje zapytanie 'whereIn' na liście ID projektów.
      return await _repository.getMembersForProjects(projectIds);
    } catch (e) {
      print('ProjectMemberService Error fetching members for all projects: $e');
      rethrow;
    }
  }

  Future<List<ProjectMember>> getProjectsForUser(String userId) async {
    try {
      return await _repository.getMembershipsByUserId(userId);
    } catch (e) {
      print('ProjectMemberService Error fetching projects for user: $e');
      rethrow;
    }
  }

  Future<void> updateProjectMemberDetails({
    required String projectId,
    required String userId,
    List<String>? newRoles,
    List<String>? newAreaIds,
  }) async {
    if (newRoles == null && newAreaIds == null) {
      throw ArgumentError('Musisz podać nowe role lub nowe ID obszarów do aktualizacji.');
    }
    if (newRoles != null && newRoles.isEmpty) {
      throw ArgumentError('Nowa lista ról nie może być pusta, jeśli jest aktualizowana.');
    }

    try {
      ProjectMember? member = await _repository.getMemberByProjectAndUser(projectId, userId);
      if (member == null) {
        throw ProjectMemberNotFoundException('projectId: $projectId, userId: $userId');
      }

      Map<String, dynamic> dataToUpdate = {};
      if (newRoles != null) {
        dataToUpdate['roles'] = newRoles;
      }
      if (newAreaIds != null) {
        dataToUpdate['areaIds'] = newAreaIds;
      }

      if (dataToUpdate.isNotEmpty) {
        await _repository.updateMember(member.id, dataToUpdate);
      } else {
        print('ProjectMemberService: Brak zmian do zaktualizowania dla członka $userId w projekcie $projectId.');
      }
    } catch (e) {
      print('ProjectMemberService Error updating project member details: $e');
      rethrow;
    }
  }

  Future<void> removeProjectMember(String projectId, String userId) async {
    try {
      ProjectMember? member = await _repository.getMemberByProjectAndUser(projectId, userId);
      if (member == null) {
        print('ProjectMemberService: Próba usunięcia nieistniejącego członkostwa ($userId) z projektu ($projectId).');
        return;
      }
      await _repository.deleteMember(member.id);
    } catch (e) {
      print('ProjectMemberService Error removing member: $e');
      rethrow;
    }
  }
}

/// Globalna instancja serwisu (lub użyj DI)
final projectMemberService = ProjectMemberService();