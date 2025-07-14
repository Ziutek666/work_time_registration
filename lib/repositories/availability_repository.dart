import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_availability.dart';
import '../exceptions/availability_exceptions.dart';

/// Repozytorium do zarządzania danymi o dyspozycyjności w Firestore.
class AvailabilityRepository {
  final FirebaseFirestore _db;
  late final CollectionReference<Map<String, dynamic>> _availabilityCollection;

  /// Konstruktor, który pozwala na wstrzyknięcie instancji Firestore, co ułatwia testowanie.
  AvailabilityRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance {
    // Nazwa kolekcji zgodna z Twoim kodem
    _availabilityCollection = _db.collection('user_availability');
  }

  /// Zapisuje listę deklaracji dyspozycyjności w jednej transakcji (batch).
  ///
  /// Rzuca [AvailabilityRepositoryException] w przypadku błędu komunikacji z bazą danych.
  Future<void> addAvailabilities(List<UserAvailability> availabilities) async {
    try {
      final batch = _db.batch();
      for (final availability in availabilities) {
        final docRef = _availabilityCollection.doc();
        // Używamy metody .toMap() z Twojego modelu
        batch.set(docRef, availability.toMap());
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AvailabilityRepositoryException('Błąd podczas zapisu do Firestore: ${e.message}');
    } catch (e) {
      throw AvailabilityRepositoryException('Nieoczekiwany błąd zapisu: $e');
    }
  }

  /// **(ZACHOWANE)** Pobiera wszystkie deklaracje dyspozycyjności dla danego użytkownika jako listę.
  ///
  /// Może być nadal używane w innych częściach aplikacji.
  Future<List<UserAvailability>> fetchAvailabilitiesForUser(String userId) async {
    try {
      final querySnapshot = await _availabilityCollection
          .where('userId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return [];
      }

      // Używamy .fromMap() z Twojego modelu
      return querySnapshot.docs
          .map((doc) => UserAvailability.fromMap(doc.data(), docId: doc.id))
          .toList();
    } on FirebaseException catch (e) {
      throw AvailabilityRepositoryException('Błąd podczas pobierania dyspozycyjności: ${e.message}');
    } catch (e) {
      throw AvailabilityRepositoryException('Nieoczekiwany błąd odczytu: $e');
    }
  }

  /// **(NOWOŚĆ)** Pobiera deklaracje dyspozycyjności dla użytkownika jako mapę [ID dokumentu -> Obiekt].
  ///
  /// Niezbędne do łatwej identyfikacji dokumentów przy edycji i usuwaniu.
  Future<Map<String, UserAvailability>> fetchAvailabilitiesForUserAsMap(String userId) async {
    try {
      final querySnapshot = await _availabilityCollection
          .where('userId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {};
      }

      return {
        for (var doc in querySnapshot.docs)
          doc.id: UserAvailability.fromMap(doc.data(), docId: doc.id)
      };
    } on FirebaseException catch (e) {
      throw AvailabilityRepositoryException('Błąd podczas pobierania mapy dyspozycyjności: ${e.message}');
    } catch (e) {
      throw AvailabilityRepositoryException('Nieoczekiwany błąd odczytu mapy: $e');
    }
  }
  Future<void> updateAvailabilityStatus(String docId, bool newStatus) async {
    try {
      await _availabilityCollection.doc(docId).update({'isAvailable': newStatus});
    } on FirebaseException catch (e) {
      throw AvailabilityRepositoryException('Błąd podczas aktualizacji statusu: ${e.message}');
    } catch (e) {
      throw AvailabilityRepositoryException('Nieoczekiwany błąd aktualizacji: $e');
    }
  }
// Pobiera dyspozycyjności dla listy ID użytkowników.
  Future<List<UserAvailability>> fetchAvailabilitiesForUsers(List<String> userIds) async {
    // Firestore pozwala na maksymalnie 30 wartości w zapytaniu 'whereIn'.
    // Jeśli spodziewasz się więcej, należy podzielić `userIds` na mniejsze części.
    if (userIds.isEmpty) return [];

    final querySnapshot = await _availabilityCollection
        .where('userId', whereIn: userIds)
        .get();

    return querySnapshot.docs
        .map((doc) => UserAvailability.fromMap(doc.data(), docId: doc.id))
        .toList();
  }
  /// Pobiera deklaracje dostępności, filtrując po ID projektu i zakresie dat.
  Future<List<UserAvailability>> fetchAvailabilitiesForProjectInDateRange(String projectId, DateTime startDate, DateTime endDate) async {
    try {
      final querySnapshot = await _availabilityCollection
          .where('projectId', isEqualTo: projectId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      return querySnapshot.docs
          .map((doc) => UserAvailability.fromMap(doc.data(), docId: doc.id))
          .toList();

    } catch (e) {
      // Rzuć dalej błąd, aby serwis mógł go obsłużyć
      print("Błąd podczas pobierania dostępności dla projektu: $e");
      rethrow;
    }
  }
  Future<void> deleteAvailability(String docId) async {
    try {
      await _availabilityCollection.doc(docId).delete();
    } on FirebaseException catch (e) {
      throw AvailabilityRepositoryException('Błąd podczas usuwania wpisu: ${e.message}');
    } catch (e) {
      throw AvailabilityRepositoryException('Nieoczekiwany błąd usuwania: $e');
    }
  }
}