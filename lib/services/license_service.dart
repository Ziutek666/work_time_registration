import 'package:cloud_firestore/cloud_firestore.dart';

import '../exceptions/license_exception.dart';
import '../models/license.dart';
import '../repositories/license_repository.dart';

class LicenseService {
  final LicenseRepository _licenseRepository = LicenseRepository();

  Future<License?> getLicense(String licenseId) async {
    try {
      return await _licenseRepository.getLicense(licenseId);
    } on LicenseFetchException {
      rethrow;
    } catch (e) {
      throw LicenseFetchException('Wystąpił nieznany błąd podczas pobierania licencji: $e');
    }
  }

  Future<License?> getLicenseForProject(String projectId) async {
    try {
      return await _licenseRepository.getLicenseForProject(projectId);
    } on LicenseFetchException {
      rethrow;
    } catch (e) {
      throw LicenseFetchException('Wystąpił nieznany błąd podczas pobierania licencji dla projektu: $e');
    }
  }

  Future<String?> createLicense({
    required String projectId,
    required String ownerId,
    int actions = 8,
    int maxExecutions = 1000,
    int usedExecutions = 0,
    int areas = 4,
    int templates = 4,
    int qrCodes = 4,
    int workTypes = 4, // Dodano nowy parametr workTypes z wartością domyślną
    required Timestamp validityTime,
    bool testMode = true,
    String description = '',
    // Opcjonalne pola Stripe, jeśli mają być ustawiane przy tworzeniu
    String? stripeSubscriptionId,
    String? stripeSubscriptionStatus,
    String? stripeCustomerId,
  }) async {
    try {
      final license = License(
        licenseId: '', // ID zostanie wygenerowane w repozytorium lub przez Firestore
        projectId: projectId,
        ownerId: ownerId,
        actions: actions,
        maxExecutions: maxExecutions,
        usedExecutions: usedExecutions,
        areas: areas,
        templates: templates,
        qrCodes: qrCodes,
        workTypes: workTypes, // Przekazanie wartości workTypes
        validityTime: validityTime,
        testMode: testMode,
        description: description,
        creationTime: Timestamp.now(),
        stripeSubscriptionId: stripeSubscriptionId,
        stripeSubscriptionStatus: stripeSubscriptionStatus,
        stripeCustomerId: stripeCustomerId,
      );
      return await _licenseRepository.createLicense(license);
    } catch (e) {
      throw LicenseCreationException('Wystąpił błąd podczas tworzenia licencji dla projektu $projectId: $e');
    }
  }

  Future<void> updateLicense(License license) async {
    try {
      // Upewnij się, że przekazywany obiekt `license` jest zgodny z pełnym modelem,
      // w tym zawiera pole `workTypes`. Repozytorium powinno sobie z tym poradzić.
      await _licenseRepository.updateLicense(license);
    } on LicenseUpdateException {
      rethrow;
    } catch (e) {
      throw LicenseUpdateException('Wystąpił nieznany błąd podczas aktualizacji licencji o ID ${license.licenseId}: $e');
    }
  }

  Future<void> deleteLicense(String licenseId) async {
    try {
      await _licenseRepository.deleteLicense(licenseId);
    } on LicenseDeletionException {
      rethrow;
    } catch (e) {
      throw LicenseDeletionException('Wystąpił nieznany błąd podczas usuwania licencji o ID $licenseId: $e');
    }
  }

  Future<void> incrementUsedExecutions(String licenseId) async {
    try {
      await _licenseRepository.incrementUsedExecutions(licenseId);
    } on LicenseUpdateException {
      rethrow;
    } catch (e) {
      throw LicenseUpdateException('Wystąpił nieznany błąd podczas zwiększania licznika użyć licencji o ID $licenseId: $e');
    }
  }
}

// Instancja serwisu, jeśli jest używana globalnie.
final licenseService = LicenseService();