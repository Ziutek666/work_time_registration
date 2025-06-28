import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member.dart';
import '../models/project.dart';
import '../models/project-access.dart';
import '../repositories/members_repository.dart';
import 'project_service.dart';

class MembersService {
  final MembersRepository _repository = MembersRepository();

  Future<Member?> getMembership({required String userId, required String ownerId}) {
    if (userId.isEmpty || ownerId.isEmpty) {
      throw ArgumentError('UserID i OwnerID nie mogą być puste.');
    }
    return _repository.getMembership(userId: userId, ownerId: ownerId);
  }

  Future<List<Member>> getMembersByOwner(String ownerId) async {
    if (ownerId.isEmpty) {
      throw ArgumentError('OwnerID nie może być puste.');
    }
    return _repository.getMembersByOwner(ownerId);
  }
  Future<void> setMember(Member member) async {
    try {
      // Wywołuje metodę z repozytorium, która nadpisze dokument
      // o ID pasującym do userId i ownerId z obiektu member.
      await _repository.setMembership(member);
    } catch (e) {
      // Przekazanie wyjątku dalej.
      rethrow;
    }
  }
  /// Sprawdza, czy dany pracownik ma dostęp do konkretnego obszaru w projekcie
  /// w ramach określonej firmy (ownerId).
  Future<bool> hasAccessToArea({
    required String userId,
    required String ownerId, // DODANY, niezbędny parametr
    required String projectId,
    required String areaId,
  }) async {
    if (userId.isEmpty || ownerId.isEmpty || projectId.isEmpty || areaId.isEmpty) {
      return false;
    }
    try {
      // 1. Pobierz rekord członkostwa dla użytkownika w tej konkretnej firmie.
      final member = await _repository.getMembership(userId: userId, ownerId: ownerId);
      if (member == null) {
        // Jeśli nie ma rekordu, użytkownik nie jest członkiem tej firmy.
        return false;
      }

      // 2. Znajdź uprawnienia dla danego projektu.
      final projectAccess = member.projects.where((p) => p.projectId == projectId);
      if (projectAccess.isEmpty) {
        // Jeśli nie ma uprawnień do tego projektu, nie ma też dostępu do obszaru.
        return false;
      }

      // 3. Sprawdź, czy lista dostępnych obszarów zawiera szukany obszar.
      return projectAccess.first.areaIds.contains(areaId);

    } catch (e) {
      print("Błąd podczas sprawdzania dostępu do obszaru: $e");
      return false;
    }
  }

  /// Pobiera listę ID obszarów, do których użytkownik ma dostęp w ramach konkretnego projektu i firmy.
  Future<List<String>> getAreaIdsForUserInProject({
    required String userId,
    required String ownerId, // DODANY, niezbędny parametr
    required String projectId,
  }) async {
    print('Pobieram listy obszarów dla użytkownika $userId w firmie $ownerId');
    if (userId.isEmpty || ownerId.isEmpty || projectId.isEmpty) {
      return [];
    }
    print('Pobieram listy obszarów dla użytkownika $userId w firmie $ownerId');
    // 1. Znajdź konkretny rekord członkostwa użytkownika w tej firmie.
    final member = await _repository.getMembership(userId: userId, ownerId: ownerId);
    if (member == null) {
      return []; // Użytkownik nie jest członkiem tej firmy.
    }
    print('Znalazłem użytkownika $userId w firmie $ownerId');
    // 2. Znajdź wpis dotyczący uprawnień do danego projektu.
    final projectAccess = member.projects.where((p) => p.projectId == projectId);
    if (projectAccess.isEmpty) {
      return []; // Użytkownik nie ma dostępu do tego projektu.
    }

    // 3. Zwróć listę ID obszarów z tego wpisu.
    return projectAccess.first.areaIds.toList();
  }
  /// NOWA METODA: Pobiera wszystkie projekty użytkownika ze WSZYSTKICH firm, do których należy.
  Future<List<Project>> getAllProjectsForUserAcrossCompanies(String userId) async {
    try {
      // 1. Pobierz wszystkie profile członkostwa użytkownika
      final allMemberships = await _repository.getMembershipsForUser(userId);
      if (allMemberships.isEmpty) {
        return [];
      }

      // 2. Zbierz wszystkie unikalne ID projektów z wszystkich profili
      final allProjectIds = <String>{}; // Użycie Seta zapobiega duplikatom
      for (final member in allMemberships) {
        for (final projectAccess in member.projects) {
          allProjectIds.add(projectAccess.projectId);
        }
      }

      if (allProjectIds.isEmpty) {
        return [];
      }

      // 3. Pobierz pełne obiekty projektów na podstawie zebranych ID
      // (Zakładając, że projectService ma taką metodę)
      return await projectService.fetchProjectsByIds(allProjectIds.toList());

    } catch (e) {
      print('Błąd podczas pobierania wszystkich projektów dla użytkownika $userId: $e');
      return [];
    }
  }

  Future<void> deleteMembership({required String userId, required String ownerId}) async {
    if (userId.isEmpty || ownerId.isEmpty) {
      throw ArgumentError('UserID i OwnerID nie mogą być puste.');
    }
    await _repository.deleteMembership(userId: userId, ownerId: ownerId);
  }
  Future<void> addMember(Member member) async {
    // Ta metoda wywołuje logikę z repozytorium, które rzuci wyjątek,
    // jeśli pracownik o podanym userId jest już przypisany do ownerId.
    try {
      await _repository.addMembership(member);
    } catch (e) {
      // Przekazanie wyjątku dalej, aby UI mogło go obsłużyć.
      rethrow;
    }
  }

  Future<void> addNewMemberToCompany({required String userId, required String ownerId}) async {
    if (userId.isEmpty || ownerId.isEmpty) {
      throw ArgumentError('UserID i OwnerID nie mogą być puste.');
    }
    final newMember = Member(
      memberId: '', // Zmieniono na 'memberId'. Wartość zostanie nadana przez Firestore.
      userId: userId,
      ownerId: ownerId,
      projects: [],
      dateAdded: Timestamp.now(),
      status: 'aktywny',
    );
    await _repository.addMembership(newMember);
  }

  Future<List<Project>> getProjectsForUser({required String userId, required String ownerId}) async {
    // ... (bez zmian w logice)
    if (userId.isEmpty || ownerId.isEmpty) {
      throw ArgumentError('UserID i OwnerID nie mogą być puste.');
    }
    try {
      final member = await getMembership(userId: userId, ownerId: ownerId);
      if (member == null || member.projects.isEmpty) return [];

      final projectIds = member.projects.map((p) => p.projectId).toList();
      if (projectIds.isEmpty) return [];

      return await projectService.fetchProjectsByIds(projectIds);
    } catch (e) {
      print('Błąd podczas pobierania projektów dla użytkownika $userId w firmie $ownerId: $e');
      return [];
    }
  }

  Future<void> grantProjectAccess({
    required String userId,
    required String ownerId,
    required String projectId,
    required Set<String> roles,
    required Set<String> areaIds,
  }) async {
    if (userId.isEmpty || ownerId.isEmpty || projectId.isEmpty) {
      throw ArgumentError('UserID, OwnerID i ProjectID nie mogą być puste.');
    }

    Member? member = await _repository.getMembership(userId: userId, ownerId: ownerId);
    final newAccess = ProjectAccess(projectId: projectId, roles: roles, areaIds: areaIds);

    if (member == null) {
      final newMember = Member(
        memberId: '${userId}_${ownerId}', // Zmieniono na 'memberId'
        userId: userId,
        ownerId: ownerId,
        projects: [newAccess],
        dateAdded: Timestamp.now(),
        status: 'aktywny',
      );
      await _repository.setMembership(newMember);
    } else {
      final projects = member.projects;
      projects.removeWhere((p) => p.projectId == projectId);
      projects.add(newAccess);
      await _repository.setMembership(member.copyWith(projects: projects));
    }
  }

  Future<void> revokeProjectAccess({required String userId, required String ownerId, required String projectId}) async {
    // ... (bez zmian w logice)
    if (userId.isEmpty || ownerId.isEmpty || projectId.isEmpty) return;

    Member? member = await _repository.getMembership(userId: userId, ownerId: ownerId);
    if (member == null) return;

    final projects = member.projects;
    projects.removeWhere((p) => p.projectId == projectId);

    if (projects.isEmpty) {
      await _repository.deleteMembership(userId: userId, ownerId: ownerId);
    } else {
      await _repository.setMembership(member.copyWith(projects: projects));
    }
  }

  Future<void> updateMemberStatus({required String userId, required String ownerId, required String status}) async {
    // ... (bez zmian w logice)
    if (userId.isEmpty || ownerId.isEmpty) throw ArgumentError('UserID i OwnerID nie mogą być puste.');
    await _repository.updateMembershipData(userId: userId, ownerId: ownerId, data: {'status': status});
  }
}

/// Globalna instancja serwisu dla łatwego dostępu w aplikacji.
final membersService = MembersService();