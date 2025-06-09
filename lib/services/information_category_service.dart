// lib/features/information/domain/services/information_category_service.dart
import '../repositories/information_category_repository.dart';
import '../models/information_category.dart';
import '../exceptions/information_category_exceptions.dart';

class InformationCategoryService {
  final InformationCategoryRepository _repository;

  InformationCategoryService(this._repository);

  /// Pobiera listę kategorii na podstawie listy ID.
  Future<List<InformationCategory>> getCategoriesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      return await _repository.getCategoriesByIds(ids);
    } catch (e) {
      print("Service Error fetching categories by IDs: $e");
      rethrow;
    }
  }

  /// Pobiera kategori na podstawie ID.
  Future<InformationCategory?> getCategoryById(String id) async {
    try {
      return await _repository.getCategoryById(id);
    } catch (e) {
      print("Service Error fetching categories by IDs: $e");
      rethrow;
    }
  }
  /// Pobiera wszystkie kategorie dla danego projektu.
  Future<List<InformationCategory>> getAllCategoriesForProject(String projectId) async {
    if (projectId.isEmpty) throw ArgumentError("Project ID cannot be empty.");
    try {
      return await _repository.getAllCategoriesForProject(projectId);
    } catch (e) {
      print("Service Error fetching categories for project $projectId: $e");
      throw InformationCategoryLoadFailureException('Nie udało się załadować kategorii dla projektu.');
    }
  }

  /// Tworzy nową kategorię.
  Future<String> createCategory(InformationCategory category) async {
    if (category.name.trim().isEmpty) {
      throw ArgumentError("Nazwa kategorii nie może być pusta.");
    }
    try {
      return await _repository.createCategory(category);
    } catch (e) {
      print("Service Error creating category: $e");
      throw InformationCategoryCreateFailureException('Nie udało się utworzyć nowej kategorii.');
    }
  }

  /// Aktualizuje istniejącą kategorię.
  Future<void> updateCategory(InformationCategory category) async {
    if (category.categoryId.isEmpty) {
      throw ArgumentError("ID kategorii jest wymagane do aktualizacji.");
    }
    if (category.name.trim().isEmpty) {
      throw ArgumentError("Nazwa kategorii nie może być pusta.");
    }
    try {
      await _repository.updateCategory(category);
    } catch (e) {
      print("Service Error updating category ${category.categoryId}: $e");
      throw InformationCategoryUpdateFailureException('Nie udało się zaktualizować kategorii.');
    }
  }

  /// Usuwa kategorię.
  Future<void> deleteCategory(String categoryId) async {
    if (categoryId.isEmpty) {
      throw ArgumentError("ID kategorii jest wymagane do usunięcia.");
    }
    try {
      // TODO: Dodać logikę sprawdzającą, czy kategoria nie jest używana przez żadną informację
      // przed jej usunięciem. Jeśli jest, rzuć wyjątek lub wyświetl odpowiedni komunikat.
      await _repository.deleteCategory(categoryId);
    } catch (e) {
      print("Service Error deleting category $categoryId: $e");
      throw InformationCategoryDeleteFailureException('Nie udało się usunąć kategorii.');
    }
  }
}

/// Globalna instancja serwisu. W większej aplikacji użyj DI.
final informationCategoryService = InformationCategoryService(informationCategoryRepository);
