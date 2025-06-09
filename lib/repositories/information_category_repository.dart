// lib/features/information/data/repositories/information_category_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/information_category.dart';

class InformationCategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionPath = 'informationCategories';

  CollectionReference<Map<String, dynamic>> get _categoriesCollection {
    return _firestore.collection(_collectionPath);
  }

  /// Tworzy nową kategorię w Firestore.
  Future<String> createCategory(InformationCategory category) async {
    final docRef = _categoriesCollection.doc();
    final categoryWithId = category.copyWith(categoryId: docRef.id);
    await docRef.set(categoryWithId.toMap());
    return docRef.id;
  }

  /// Aktualizuje istniejącą kategorię.
  Future<void> updateCategory(InformationCategory category) async {
    if (category.categoryId.isEmpty) {
      throw ArgumentError('Category ID cannot be empty for an update.');
    }
    await _categoriesCollection.doc(category.categoryId).update(category.toMap());
  }

  /// Usuwa kategorię na podstawie ID.
  Future<void> deleteCategory(String categoryId) async {
    if (categoryId.isEmpty) {
      throw ArgumentError('Category ID cannot be empty for deletion.');
    }
    await _categoriesCollection.doc(categoryId).delete();
  }

  /// Pobiera pojedynczą kategorię po ID.
  Future<InformationCategory?> getCategoryById(String categoryId) async {
    final docSnapshot = await _categoriesCollection.doc(categoryId).get();
    if (docSnapshot.exists) {
      return InformationCategory.fromFirestore(docSnapshot);
    }
    return null;
  }

  /// Pobiera listę kategorii na podstawie listy ID.
  Future<List<InformationCategory>> getCategoriesByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    // Ograniczenie Firestore do 30 elementów w zapytaniu 'in'
    if (ids.length > 30) {
      // Dzielenie zapytania na mniejsze części
      List<InformationCategory> results = [];
      for (var i = 0; i < ids.length; i += 30) {
        var sublist = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
        final querySnapshot = await _categoriesCollection.where(FieldPath.documentId, whereIn: sublist).get();
        results.addAll(querySnapshot.docs.map((doc) => InformationCategory.fromFirestore(doc)));
      }
      return results;
    } else {
      final querySnapshot = await _categoriesCollection.where(FieldPath.documentId, whereIn: ids).get();
      return querySnapshot.docs.map((doc) => InformationCategory.fromFirestore(doc)).toList();
    }
  }

  /// Pobiera wszystkie kategorie dla danego projektu.
  /// Zakładając, że model InformationCategory będzie miał pole projectId.
  /// Jeśli kategorie są globalne, ta metoda powinna pobierać wszystkie.
  Future<List<InformationCategory>> getAllCategoriesForProject(String projectId) async {
    final querySnapshot = await _categoriesCollection
    // .where('projectId', isEqualTo: projectId) // Odkomentuj, jeśli kategorie są per projekt
        .orderBy('name')
        .get();
    return querySnapshot.docs.map((doc) => InformationCategory.fromFirestore(doc)).toList();
  }
}

/// Globalna instancja repozytorium.
final informationCategoryRepository = InformationCategoryRepository();
