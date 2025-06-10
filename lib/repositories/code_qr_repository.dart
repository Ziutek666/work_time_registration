import 'package:cloud_firestore/cloud_firestore.dart';

import '../exceptions/code_qr_exception.dart';
import '../models/code-qr.dart';

class CodeQrRepository {
  final FirebaseFirestore _firestore;

  // Kolekcja w Firestore, gdzie będą przechowywane kody QR
  late final CollectionReference<CodeQr> _qrCodesCollection;

  CodeQrRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _qrCodesCollection = _firestore.collection('qrCodes').withConverter<CodeQr>(
      fromFirestore: (snapshot, _) => CodeQr.fromFirestore(snapshot),
      toFirestore: (codeQr, _) => codeQr.toMap(),
    );
  }

  /// Dodaje nowy kod QR do Firestore.
  Future<void> addCodeQr(CodeQr codeQr) async {
    try {
      await _qrCodesCollection.doc(codeQr.codeQrId).set(codeQr);
    } on FirebaseException catch (e) {
      throw CodeQrDataException('Nie udało się dodać kodu QR: ${e.message}');
    }
  }

  /// Pobiera pojedynczy kod QR na podstawie jego ID.
  Future<CodeQr?> getCodeQrById(String codeQrId) async {
    try {
      final docSnapshot = await _qrCodesCollection.doc(codeQrId).get();
      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      return null;
    } on FirebaseException catch (e) {
      throw CodeQrDataException('Nie udało się pobrać kodu QR: ${e.message}');
    }
  }

  /// Zwraca strumień kodów QR dla danego projektu.
  Stream<List<CodeQr>> getCodesByProject(String projectId) {
    return _qrCodesCollection
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Zwraca strumień kodów QR dla danego właściciela.
  Stream<List<CodeQr>> getCodesByOwner(String ownerId) {
    return _qrCodesCollection
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Aktualizuje istniejący kod QR w Firestore.
  Future<void> updateCodeQr(CodeQr codeQr) async {
    try {
      await _qrCodesCollection.doc(codeQr.codeQrId).update(codeQr.toMap());
    } on FirebaseException catch (e) {
      throw CodeQrDataException('Nie udało się zaktualizować kodu QR: ${e.message}');
    }
  }

  /// Usuwa kod QR z Firestore.
  Future<void> deleteCodeQr(String codeQrId) async {
    try {
      await _qrCodesCollection.doc(codeQrId).delete();
    } on FirebaseException catch (e) {
      throw CodeQrDataException('Nie udało się usunąć kodu QR: ${e.message}');
    }
  }
}