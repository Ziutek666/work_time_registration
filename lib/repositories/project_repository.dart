import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/project_exception.dart';
import '../models/project.dart';

class ProjectRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'projects';

  Future<Project> getProject(String projectId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(projectId).get();
      if (doc.exists && doc.data() != null) {
        return Project.fromFirestore(doc);
      } else {
        throw ProjectNotFoundException('Projekt o ID $projectId nie istnieje.');
      }
    } catch (e) {
      if (e is ProjectNotFoundException) {
        rethrow;
      }
      throw ProjectFetchException('Wystąpił błąd podczas pobierania projektu: $e');
    }
  }

  Future<List<Project>> getProjectsByOwner(String ownerId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('ownerId', isEqualTo: ownerId)
          .get();
      if (snapshot.docs.isEmpty) {
        throw NoProjectsFoundException('Nie znaleziono projektów dla użytkownika o ID $ownerId.');
      }
      return snapshot.docs.map((doc) => Project.fromFirestore(doc)).toList();
    } catch (e) {
      if (e is NoProjectsFoundException) {
        rethrow;
      }
      throw ProjectFetchException('Wystąpił błąd podczas pobierania projektów użytkownika: $e');
    }
  }

  Future<String> createProject(Project project) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();
      final newProjectId = docRef.id;
      final newProject = Project(
        projectId: newProjectId,
        ownerId: project.ownerId,
        name: project.name,
        description: project.description,
      );
      await docRef.set(newProject.toMap());
      return newProjectId;
    } catch (e) {
      throw ProjectCreationException('Nie udało się utworzyć projektu: $e');
    }
  }

  Future<void> updateProject(Project project) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(project.projectId)
          .update(project.toMap());
    } catch (e) {
      throw ProjectUpdateException('Nie udało się zaktualizować projektu o ID ${project.projectId}: $e');
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      await _firestore.collection(_collectionName).doc(projectId).delete();
    } catch (e) {
      throw ProjectDeletionException('Nie udało się usunąć projektu o ID $projectId: $e');
    }
  }

  // *** NOWA FUNKCJA ***
  /// Pobiera listę prjektów na podstawie listy ich ID (UID).
  Future<List<Project>> getProjectsByIds(List<String> projectIds) async {
    // Usuń duplikaty i puste stringi
    final validProjectIds = projectIds.where((projectId) => projectId.isNotEmpty).toSet().toList();

    if (validProjectIds.isEmpty) {
      return []; // Zwróć pustą listę, jeśli brak poprawnych ID
    }

    List<Project> projects = [];
    List<Future<QuerySnapshot<Map<String, dynamic>>>> fetchFutures = [];
    const int batchSize = 30; // Limit Firestore dla 'whereIn'

    // Dzielimy listę UID na części i tworzymy Future dla każdego zapytania
    for (int i = 0; i < validProjectIds.length; i += batchSize) {
      // Wycięcie podlisty UID dla bieżącej partii
      List<String> sublist = validProjectIds.sublist(i,
          (i + batchSize > validProjectIds.length) ? validProjectIds.length : i + batchSize);

      // Dodanie Future zapytania do listy
      fetchFutures.add(
          _firestore
              .collection(_collectionName)
              .where(FieldPath.documentId, whereIn: sublist) // Zapytanie po ID dokumentu
              .get()
      );
    }

    try {
      // Wykonanie wszystkich zapytań równolegle
      final List<QuerySnapshot<Map<String, dynamic>>> snapshots = await Future.wait(fetchFutures);

      // Przetwarzanie wyników z każdej partii
      for (final snapshot in snapshots) {
        for (final doc in snapshot.docs) {
          if (doc.exists && doc.data() != null) {
            final projectData = doc.data()!;
            // Dodanie zmapowanego użytkownika do listy wyników
            projects.add(Project(
              projectId: projectData['projectId'],
              name: projectData['name'] as String,
              ownerId: '',
            ));
          }
        }
      }
      return projects;
    } on FirebaseException catch (e, stackTrace) {
      final errorMsg = 'Błąd Firebase podczas pobierania użytkowników przez listę ID: ${e.message}';
      print('$errorMsg\n$stackTrace');
      throw ProjectFetchException(errorMsg);
    } catch (e, stackTrace) {
      final errorMsg = 'Nieoczekiwany błąd podczas pobierania użytkowników przez listę ID: $e';
      print('$errorMsg\n$stackTrace');
      throw ProjectFetchException(errorMsg);
    }
  }
// *** KONIEC NOWEJ FUNKCJI ***
}