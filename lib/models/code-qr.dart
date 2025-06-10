import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model reprezentujący kod QR w aplikacji.
class CodeQr {
  /// Unikalny identyfikator kodu QR.
  String codeQrId;

  /// Nazwa kodu QR (opcjonalna).
  String name;

  /// Identyfikator projektu, do którego należy kod QR.
  String projectId;

  /// Identyfikator obszaru, do którego należy kod QR.
  String areaId; // <-- NOWE POLE

  /// Identyfikator właściciela kodu QR.
  String ownerId;

  /// Opis kodu QR (opcjonalny).
  String description;

  /// Identyfikator powiązanego produktu (opcjonalny).
  String productId;

  /// Lista identyfikatorów akcji powiązanych z kodem QR.
  List<String> actionsId;

  /// Lista identyfikatorów typów pracy powiązanych z kodem QR.
  List<String> workTypeIds;

  /// Opcjonalne dane powiązane z kodem QR w formacie mapy.
  Map<String, dynamic> qrData;

  /// Opcjonalny identyfikator licencji powiązanej z kodem QR.
  String licenseId;

  /// Opcjonalna lokalizacja powiązana z kodem QR.
  GeoPoint? location;

  /// Opcjonalna maksymalna odległość w metrach od lokalizacji (jeśli zdefiniowano lokalizację).
  int? maxDistanceInMeters;

  /// Flaga wskazująca, czy sprawdzać lokalizację.
  bool? checkLocation;

  /// Konstruktor dla klasy CodeQr.
  CodeQr({
    this.codeQrId = '',
    required this.name,
    required this.projectId,
    required this.areaId, // <-- DODANE DO KONSTRUKTORA
    required this.ownerId,
    required this.licenseId,
    this.description = '',
    this.productId = '',
    this.actionsId = const [],
    this.workTypeIds = const [],
    Map<String, dynamic>? qrData,
    this.location,
    this.maxDistanceInMeters,
    this.checkLocation,
  }) : qrData = qrData ?? {};

  /// Tworzenie obiektu CodeQr na podstawie dokumentu Firestore.
  factory CodeQr.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return CodeQr(
      codeQrId: data['codeQrId'] ?? '',
      name: data['name'] ?? '',
      projectId: data['projectId'] ?? '',
      areaId: data['areaId'] ?? '', // <-- DODANE ODCZYTYWANIE
      ownerId: data['ownerId'] ?? '',
      description: data['description'] ?? '',
      productId: data['productId'] ?? '',
      actionsId: List<String>.from(data['actionsId'] ?? []),
      workTypeIds: List<String>.from(data['workTypeIds'] ?? []),
      qrData: data['qrData'] as Map<String, dynamic>?,
      licenseId: data['licenseId'] ?? '',
      location: data['location'] as GeoPoint?,
      checkLocation: data['checkLocation'] as bool?,
      maxDistanceInMeters: data['maxDistanceInMeters'] as int?,
    );
  }

  /// Konwersja obiektu CodeQr do mapy (przydatne przy zapisie do Firestore).
  Map<String, dynamic> toMap() {
    return {
      'codeQrId': codeQrId,
      'name': name,
      'projectId': projectId,
      'areaId': areaId, // <-- DODANE DO MAPY
      'ownerId': ownerId,
      'description': description,
      'productId': productId,
      'actionsId': actionsId,
      'workTypeIds': workTypeIds,
      'qrData': qrData,
      'licenseId': licenseId,
      'location': location,
      'checkLocation': checkLocation,
      'maxDistanceInMeters': maxDistanceInMeters,
    };
  }

  /// Metoda generująca zakodowany w JSON ciąg znaków zawierający identyfikator QR i opcjonalne dane QR.
  String getQrCode() {
    Map<String, dynamic> qr = {
      'i': codeQrId, // 'i' jako skrót od 'id' dla oszczędności miejsca
      'd': qrData,   // 'd' jako skrót od 'data'
    };
    return jsonEncode(qr);
  }
}