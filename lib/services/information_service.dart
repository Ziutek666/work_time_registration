import 'package:cloud_firestore/cloud_firestore.dart'; // Potrzebne dla Timestamp
import 'package:work_time_registration/services/information_category_service.dart';
import '../models/information.dart';
import '../models/information_category.dart';
import '../repositories/information_repository.dart'; // Importuje globalną instancję
import '../exceptions/information_exceptions.dart';

/// Klasa pomocnicza do przechowywania spójnego wyniku zapytania
/// zawierającego zarówno listę informacji, jak i mapę powiązanych z nimi kategorii.
class InformationQueryResult {
  final List<Information> informations;
  final Map<String, InformationCategory> categories;

  InformationQueryResult({required this.informations, required this.categories});
}

class InformationService {

  /// NOWA ZALECANA METODA: Pobiera informacje wraz z ich kategoriami.
  /// Służy jako zabezpieczenie, zapewniając, że UI otrzymuje kompletny zestaw danych.
  Future<InformationQueryResult> fetchInformationsWithCategoriesForProject(String projectId) async {
    if (projectId.isEmpty) throw ArgumentError('Project ID cannot be empty.');

    try {
      // Krok 1: Pobierz wszystkie informacje dla projektu
      final informations = await fetchAllInformationByProjectId(projectId);

      // Zabezpieczenie 1: Jeśli nie ma żadnych informacji, zwróć natychmiast pusty wynik.
      if (informations.isEmpty) {
        return InformationQueryResult(informations: [], categories: {});
      }

      // Krok 2: Zbierz unikalne ID kategorii z pobranych informacji
      final categoryIds = informations.map((info) => info.categoryId).where((id) => id.isNotEmpty).toSet().toList();

      // Zabezpieczenie 2: Jeśli informacje nie mają powiązanych kategorii, zwróć je z pustą mapą kategorii.
      if (categoryIds.isEmpty) {
        return InformationQueryResult(informations: informations, categories: {});
      }

      // Krok 3: Pobierz odpowiednie kategorie
      final categories = await informationCategoryService.getCategoriesByIds(categoryIds);
      final categoriesMap = { for (var cat in categories) cat.categoryId: cat };

      return InformationQueryResult(informations: informations, categories: categoriesMap);

    } catch (e) {
      print('Service Error fetching informations with categories for project $projectId: $e');
      rethrow; // Rzuć dalej wyjątek, aby UI mogło go obsłużyć
    }
  }

  /// Pobiera pojedynczą informację po jej ID.
  Future<Information?> getInformationById(String informationId) async {
    if (informationId.isEmpty) throw ArgumentError('Information ID cannot be empty.');
    try {
      return await informationRepository.getInformationById(informationId);
    } catch (e) {
      print('Service Error fetching by ID $informationId: $e');
      rethrow;
    }
  }

  /// Pobiera listę informacji na podstawie listy ich ID.
  Future<List<Information>> getInformationByIds(List<String> ids) async {
    if (ids.any((id) => id.isEmpty)) throw ArgumentError('Information IDs cannot be empty.');
    if (ids.isEmpty) return [];
    try {
      return await informationRepository.getInformationsByIds(ids);
    } catch (e) {
      print('Service Error fetching by IDs: $e');
      rethrow;
    }
  }

  /// Pobiera listę informacji z flagą showOnStart=true.
  Future<List<Information>> getInformationByIdsShowOnStart(List<String> ids) async {
    if (ids.any((id) => id.isEmpty)) throw ArgumentError('Information IDs cannot be empty.');
    if (ids.isEmpty) return [];
    try {
      return await informationRepository.getInformationsByIdsShowOnStart(ids);
    } catch (e) {
      print('Service Error fetching by IDs (showOnStart): $e');
      rethrow;
    }
  }

  /// Pobiera listę informacji z flagą showOnStop=true.
  Future<List<Information>> getInformationByIdsShowOnStop(List<String> ids) async {
    if (ids.any((id) => id.isEmpty)) throw ArgumentError('Information IDs cannot be empty.');
    if (ids.isEmpty) return [];
    try {
      return await informationRepository.getInformationsByIdsShowOnStop(ids);
    } catch (e) {
      print('Service Error fetching by IDs (showOnStop): $e');
      rethrow;
    }
  }

  /// Pobiera wszystkie informacje, domyślnie sortowane po dacie utworzenia.
  Future<List<Information>> fetchAllInformation({
    String? orderBy,
    bool descending = true,
  }) async {
    try {
      String effectiveOrderBy = orderBy ?? 'createdAt';
      return await informationRepository.getAllInformations(
        orderByField: effectiveOrderBy,
        descending: descending,
      );
    } catch (e) {
      print('Service Error fetching all informations: $e');
      rethrow;
    }
  }

  /// Pobiera wszystkie informacje dla danego projektu, domyślnie sortowane po dacie utworzenia.
  Future<List<Information>> fetchAllInformationByProjectId(
      String projectId, {
        String? orderBy,
        bool descending = true,
      }) async {
    if (projectId.isEmpty) throw ArgumentError('Project ID cannot be empty.');
    try {
      String effectiveOrderBy = orderBy ?? 'createdAt';
      return await informationRepository.getAllInformationsByProjectId(
        projectId,
        orderByField: effectiveOrderBy,
        descending: descending,
      );
    } catch (e) {
      print('Service Error fetching informations for project $projectId: $e');
      rethrow;
    }
  }

  /// Pobiera informacje wymagające decyzji użytkownika.
  Future<List<Information>> fetchInformationRequiringAcknowledgement() async {
    try {
      List<Information> allInfo = await informationRepository.getAllInformations();
      final requiring = allInfo.where((info) => info.requiresDecision).toList();
      requiring.sort((a,b) => b.createdAt.compareTo(a.createdAt));
      return requiring;
    } catch (e) {
      print('Service Error fetching informations requiring acknowledgement: $e');
      rethrow;
    }
  }

  /// Tworzy nową informację na podstawie obiektu Information.
  Future<String> createInformation(Information information) async {
    if (information.title.trim().isEmpty || information.content.trim().isEmpty) {
      throw ArgumentError('Tytuł i treść informacji nie mogą być puste.');
    }
    if (information.projectId.isEmpty || information.categoryId.isEmpty) {
      throw ArgumentError('ID projektu i kategorii nie mogą być puste.');
    }
    try {
      return await informationRepository.createInformation(information);
    } catch (e) {
      print('Service Error creating new information: $e');
      rethrow;
    }
  }

  /// Metoda pomocnicza do tworzenia informacji z podstawowych danych.
  Future<String> submitNewInformation({
    required String title,
    required String content,
    required String projectId,
    required String categoryId,
    bool requiresDecision = false,
    bool textResponseRequiredOnDecision = false,
    bool showOnStart = false,
    bool showOnStop = false,
  }) async {
    final newInformation = Information(
      informationId: '',
      projectId: projectId,
      title: title.trim(),
      content: content.trim(),
      categoryId: categoryId,
      requiresDecision: requiresDecision,
      textResponseRequiredOnDecision: textResponseRequiredOnDecision,
      createdAt: Timestamp.now(),
      showOnStart: showOnStart,
      showOnStop: showOnStop,
    );
    return await createInformation(newInformation);
  }

  /// Aktualizuje istniejącą informację.
  Future<void> updateInformation(Information information) async {
    if (information.informationId.isEmpty) {
      throw ArgumentError('Information ID must be provided for update.');
    }
    if (information.title.trim().isEmpty || information.content.trim().isEmpty || information.categoryId.isEmpty) {
      throw ArgumentError('Title, content, and category ID cannot be empty for update.');
    }
    try {
      await informationRepository.updateInformation(information);
    } catch (e) {
      print('Service Error editing information ${information.informationId}: $e');
      rethrow;
    }
  }

  /// Usuwa informację.
  Future<void> removeInformation(String informationId) async {
    if (informationId.isEmpty) throw ArgumentError('Information ID cannot be empty for deletion.');
    try {
      await informationRepository.deleteInformation(informationId);
    } catch (e) {
      print('Service Error removing information $informationId: $e');
      rethrow;
    }
  }

  /// Oznacza informację jako przeczytaną przez administratora.
  Future<void> markInformationAsAdminRead(String informationId) async {
    if (informationId.isEmpty) throw ArgumentError('Information ID cannot be empty.');
    try {
      await informationRepository.markAsAdminRead(informationId);
    } catch (e) {
      print('Service Error marking information $informationId as admin read: $e');
      rethrow;
    }
  }

  /// Oznacza informację jako nieprzeczytaną przez administratora.
  Future<void> markInformationAsAdminUnread(String informationId) async {
    if (informationId.isEmpty) throw ArgumentError('Information ID cannot be empty.');
    try {
      await informationRepository.markAsAdminUnread(informationId);
    } catch (e) {
      print('Service Error marking information $informationId as admin unread: $e');
      rethrow;
    }
  }
}

// Globalna instancja serwisu
final informationService = InformationService();
