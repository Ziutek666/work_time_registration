import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/code_qr_exception.dart';
import '../models/code-qr.dart';
import '../repositories/code_qr_repository.dart';

class CodeQrService {
  final CodeQrRepository _repository;

  // Wzorzec Singleton, aby zapewnić jedną instancję serwisu w całej aplikacji
  static final CodeQrService _instance = CodeQrService._internal(CodeQrRepository());
  factory CodeQrService() => _instance;
  CodeQrService._internal(this._repository);


  /// Tworzy nowy kod QR, uwzględniając wszystkie pola z modelu.
  Future<CodeQr> createCodeQr({
    // Wymagane pola
    required String name,
    required String projectId,
    required String areaId,
    required String ownerId,
    required String licenseId,
    // Opcjonalne pola z wartościami domyślnymi
    String description = '',
    String productId = '',
    List<String> actionsId = const [],
    List<String> workTypeIds = const [], // <-- DODANE POLE
    Map<String, dynamic>? qrData,
    GeoPoint? location,
    bool? checkLocation,
    int? maxDistanceInMeters,
  }) async {
    // Prosta walidacja
    if (name.trim().isEmpty) {
      throw CodeQrValidationException('Nazwa kodu QR nie może być pusta.');
    }
    if (projectId.trim().isEmpty) {
      throw CodeQrValidationException('ID projektu nie może być puste.');
    }

    // Generowanie unikalnego ID dla nowego dokumentu
    final newDocRef = FirebaseFirestore.instance.collection('qrCodes').doc();

    // Tworzenie obiektu CodeQr z wszystkimi przekazanymi danymi
    final newCode = CodeQr(
      codeQrId: newDocRef.id,
      name: name,
      projectId: projectId,
      areaId: areaId,
      ownerId: ownerId,
      licenseId: licenseId,
      description: description,
      productId: productId,
      actionsId: actionsId,
      workTypeIds: workTypeIds, // <-- UŻYCIE NOWEGO POLA
      qrData: qrData,
      location: location,
      checkLocation: checkLocation,
      maxDistanceInMeters: maxDistanceInMeters,
    );

    // Wywołanie repozytorium w celu zapisu w bazie danych
    await _repository.addCodeQr(newCode);
    return newCode;
  }

  /// Aktualizuje dane istniejącego kodu QR.
  /// Ta metoda nie wymaga zmian, ponieważ przyjmuje cały obiekt CodeQr.
  Future<void> updateCodeQr(CodeQr codeQr) async {
    if (codeQr.codeQrId.isEmpty) {
      throw CodeQrValidationException('ID kodu QR do aktualizacji nie może być puste.');
    }
    await _repository.updateCodeQr(codeQr);
  }

  /// Usuwa kod QR.
  Future<void> deleteCodeQr(String codeQrId) async {
    if (codeQrId.isEmpty) {
      throw CodeQrValidationException('ID kodu QR do usunięcia nie może być puste.');
    }
    await _repository.deleteCodeQr(codeQrId);
  }

  /// Pobiera kod QR po ID. Rzuca wyjątek, jeśli nie zostanie znaleziony.
  Future<CodeQr> getCodeQrById(String codeQrId) async {
    final code = await _repository.getCodeQrById(codeQrId);
    if (code == null) {
      throw CodeQrNotFoundException();
    }
    return code;
  }

  /// Pobiera strumień kodów QR dla projektu.
  Stream<List<CodeQr>> getCodesByProject(String projectId) {
    return _repository.getCodesByProject(projectId);
  }

  /// Pobiera strumień kodów QR dla właściciela.
  Stream<List<CodeQr>> getCodesByOwner(String ownerId) {
    return _repository.getCodesByOwner(ownerId);
  }
}

// Globalna instancja serwisu dla łatwego dostępu w aplikacji
final codeQrService = CodeQrService();