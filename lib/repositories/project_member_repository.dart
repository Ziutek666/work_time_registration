import 'package:cloud_firestore/cloud_firestore.dart';

import '../exceptions/project_member_exceptions.dart';
import '../models/project_member.dart';

class ProjectMemberRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'projectMembers';

  CollectionReference<Map<String, dynamic>> get _projectMembersCollection {
    return _firestore.collection(_collectionPath);
  }

  Future<String> addMember(ProjectMember member) async {
    try {
      final docRef = await _projectMembersCollection.add(member.toMapForCreation());
      return docRef.id;
    } on FirebaseException catch (e) {
      throw ProjectMemberFirestoreException('Nie udało się dodać członkostwa.', e);
    } catch (e) {
      throw ProjectMemberCreationException('Nieznany błąd podczas dodawania członkostwa: ${e.toString()}');
    }
  }

  Future<ProjectMember?> getMemberByProjectAndUser(String projectId, String userId) async {
    if (projectId.isEmpty || userId.isEmpty) throw ArgumentError('ID projektu i użytkownika nie mogą być puste.');
    try {
      final querySnapshot = await _projectMembersCollection
          .where('projectId', isEqualTo: projectId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return ProjectMember.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } on FirebaseException catch (e) {
      throw ProjectMemberFirestoreException('Nie udało się pobrać członkostwa dla projektu i użytkownika.', e);
    } catch (e) {
      throw ProjectMemberException('Nieznany błąd podczas pobierania członkostwa dla projektu i użytkownika: ${e.toString()}');
    }
  }

  Future<List<ProjectMember>> getMembersByProjectId(String projectId) async {
    if (projectId.isEmpty) throw ArgumentError('ID projektu nie może być puste.');
    try {
      final querySnapshot = await _projectMembersCollection
          .where('projectId', isEqualTo: projectId)
          .get();
      return querySnapshot.docs.map((doc) => ProjectMember.fromFirestore(doc)).toList();
    } on FirebaseException catch (e) {
      throw ProjectMemberFirestoreException('Nie udało się pobrać listy członkostw dla projektu.', e);
    } catch (e) {
      throw ProjectMemberException('Nieznany błąd podczas pobierania listy członkostw dla projektu: ${e.toString()}');
    }
  }

  /// Pobiera wszystkich członków dla podanej listy ID projektów.
  Future<List<ProjectMember>> getMembersForProjects(List<String> projectIds) async {
    if (projectIds.isEmpty) {
      return [];
    }

    final List<ProjectMember> allMembers = [];
    // Firestore 'in' query supports up to 30 elements. Chunk the list if it's larger.
    for (var i = 0; i < projectIds.length; i += 30) {
      final sublist = projectIds.sublist(i, i + 30 > projectIds.length ? projectIds.length : i + 30);
      final querySnapshot = await _projectMembersCollection
          .where('projectId', whereIn: sublist)
          .get();
      allMembers.addAll(querySnapshot.docs.map((doc) => ProjectMember.fromFirestore(doc)));
    }
    return allMembers;
  }

  Future<List<ProjectMember>> getMembershipsByUserId(String userId) async {
    if (userId.isEmpty) throw ArgumentError('ID użytkownika nie może być puste.');
    try {
      final querySnapshot = await _projectMembersCollection
          .where('userId', isEqualTo: userId)
          .get();
      return querySnapshot.docs.map((doc) => ProjectMember.fromFirestore(doc)).toList();
    } on FirebaseException catch (e) {
      throw ProjectMemberFirestoreException('Nie udało się pobrać listy członkostw dla użytkownika.', e);
    } catch (e) {
      throw ProjectMemberException('Nieznany błąd podczas pobierania listy członkostw dla użytkownika: ${e.toString()}');
    }
  }

  Future<void> updateMember(String membershipId, Map<String, dynamic> data) async {
    if (membershipId.isEmpty) throw ArgumentError('ID członkostwa nie może być puste.');
    try {
      await _projectMembersCollection.doc(membershipId).update(data);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        throw ProjectMemberNotFoundException('ID członkostwa: $membershipId');
      }
      throw ProjectMemberFirestoreException('Nie udało się zaktualizować członkostwa.', e);
    } catch (e) {
      throw ProjectMemberUpdateException(membershipId, 'Nieznany błąd: ${e.toString()}');
    }
  }

  Future<void> deleteMember(String membershipId) async {
    if (membershipId.isEmpty) throw ArgumentError('ID członkostwa nie może być puste.');
    try {
      await _projectMembersCollection.doc(membershipId).delete();
    } on FirebaseException catch (e) {
      throw ProjectMemberFirestoreException('Nie udało się usunąć członkostwa.', e);
    } catch (e) {
      throw ProjectMemberDeletionException(membershipId, 'Nieznany błąd: ${e.toString()}');
    }
  }
}

/// Globalna instancja repozytorium (lub użyj DI)
final projectMemberRepository = ProjectMemberRepository();