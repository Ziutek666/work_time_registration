import 'package:cloud_firestore/cloud_firestore.dart';


import '../exceptions/license_exception.dart';
import '../models/license.dart';

class LicenseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'licenses';

  Future<License?> getLicense(String licenseId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(licenseId).get();
      if (doc.exists && doc.data() != null) {
        return License.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw LicenseFetchException('Wystąpił błąd podczas pobierania licencji o ID $licenseId: $e');
    }
  }

  Future<License?> getLicenseForProject(String projectId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('projectId', isEqualTo: projectId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return License.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw LicenseFetchException('Wystąpił błąd podczas pobierania licencji dla projektu $projectId: $e');
    }
  }

  Future<String?> createLicense(License license) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();
      final newLicenseId = docRef.id;
      final newLicense = license.copyWith(licenseId: newLicenseId);
      await docRef.set(newLicense.toMap());
      return newLicenseId;
    } catch (e) {
      throw LicenseCreationException('Wystąpił błąd podczas tworzenia licencji dla projektu ${license.projectId}: $e');
    }
  }

  Future<void> updateLicense(License license) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(license.licenseId)
          .update(license.toMap());
    } catch (e) {
      throw LicenseUpdateException('Wystąpił błąd podczas aktualizacji licencji o ID ${license.licenseId}: $e');
    }
  }

  Future<void> deleteLicense(String licenseId) async {
    try {
      await _firestore.collection(_collectionName).doc(licenseId).delete();
    } catch (e) {
      throw LicenseDeletionException('Wystąpił błąd podczas usuwania licencji o ID $licenseId: $e');
    }
  }

  Future<void> incrementUsedExecutions(String licenseId) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(licenseId);
      await docRef.update({'usedExecutions': FieldValue.increment(1)});
    } catch (e) {
      throw LicenseUpdateException('Wystąpił błąd podczas zwiększania licznika użyć licencji o ID $licenseId: $e');
    }
  }
}
final licenseRepository = LicenseRepository();