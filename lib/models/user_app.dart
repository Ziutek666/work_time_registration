// models/user_app.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Import dla Timestamp
// Import modelu AppSettings
import 'package:work_time_registration/models/wtr_settings.dart'; // Upewnij się, że ta ścieżka jest poprawna

class UserApp {
  final String? uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final DateTime? createdAt; // Przechowywane jako DateTime w modelu
  final DateTime? updatedAt; // Przechowywane jako DateTime w modelu
  final WtrSettings? wtrSettings;
  // Dodatkowe pola, które mogą być w Firestore, a niekoniecznie w UserApp z Firebase Auth
  final String? displayName_lowercase; // Przykład pola do wyszukiwania
  final String? email_lowercase;       // Przykład pola do wyszukiwania

  UserApp({
    this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.createdAt,
    this.updatedAt,
    this.wtrSettings,
    this.displayName_lowercase, // Dodano do konstruktora
    this.email_lowercase,       // Dodano do konstruktora
  });

  /// Pomocnicza metoda do parsowania różnych formatów daty
  static DateTime? _parseDateTime(dynamic dateTimeValue) {
    if (dateTimeValue == null) {
      return null;
    }
    if (dateTimeValue is Timestamp) {
      return dateTimeValue.toDate();
    }
    if (dateTimeValue is String) {
      return DateTime.tryParse(dateTimeValue);
    }
    if (dateTimeValue is int) { // Zakładamy timestamp w milisekundach
      return DateTime.fromMillisecondsSinceEpoch(dateTimeValue);
    }
    // Można dodać logowanie, jeśli typ jest nieoczekiwany
    // print('Nieznany typ daty: ${dateTimeValue.runtimeType}');
    return null;
  }

  /// Fabryczna metoda do tworzenia instancji UserApp z dokumentu Firestore.
  factory UserApp.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      // Możesz rzucić wyjątek, zwrócić null lub domyślny obiekt,
      // w zależności od logiki obsługi błędów.
      throw StateError('Brak danych dla UserApp z dokumentu Firestore: ${doc.id}');
    }
    return UserApp(
      uid: doc.id, // UID to ID dokumentu
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      wtrSettings: data['wtrSettings'] != null
          ? WtrSettings.fromJson(data['wtrSettings'] as Map<String, dynamic>)
          : null,
      displayName_lowercase: data['displayName_lowercase'] as String?,
      email_lowercase: data['email_lowercase'] as String?,
    );
  }


  factory UserApp.fromJson(Map<String, dynamic> json) {
    return UserApp(
      uid: json['uid'] as String?,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoURL: json['photoURL'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
      wtrSettings: json['wtrSettings'] == null
          ? null
          : WtrSettings.fromJson(json['wtrSettings'] as Map<String, dynamic>),
      displayName_lowercase: json['displayName_lowercase'] as String?,
      email_lowercase: json['email_lowercase'] as String?,
    );
  }

  Map<String, dynamic> toMap() { // Zmieniono nazwę z toJson na toMap dla spójności z Firestore
    return <String, dynamic>{
      // uid nie jest zwykle zapisywane w mapie, bo jest ID dokumentu,
      // ale jeśli jest potrzebne z jakiegoś powodu, można je dodać.
      // 'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'wtrSettings': wtrSettings?.toJson(), // Zakładając, że WtrSettings ma toJson
      // Zapisuj pola lowercase, jeśli są zarządzane przez model
      'displayName_lowercase': displayName?.toLowerCase(),
      'email_lowercase': email?.toLowerCase(),
    };
  }

  UserApp copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    DateTime? createdAt,
    DateTime? updatedAt,
    WtrSettings? wtrSettings,
    String? displayName_lowercase,
    String? email_lowercase,
  }) {
    return UserApp(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      wtrSettings: wtrSettings ?? this.wtrSettings,
      displayName_lowercase: displayName_lowercase ?? this.displayName_lowercase,
      email_lowercase: email_lowercase ?? this.email_lowercase,
    );
  }

  @override
  String toString() {
    return 'UserApp{uid: $uid, email: $email, displayName: $displayName, photoURL: $photoURL, createdAt: $createdAt, updatedAt: $updatedAt, wtrSettings: $wtrSettings, displayName_lowercase: $displayName_lowercase, email_lowercase: $email_lowercase}';
  }
}