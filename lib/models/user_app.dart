import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:work_time_registration/models/wtr_settings.dart';

class UserApp extends Equatable {
  final String? uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final WtrSettings? wtrSettings;
  final String? displayName_lowercase;
  final String? email_lowercase;

  // ZMIANA: Konstruktor jest teraz stały (const), co pozwala na optymalizacje
  const UserApp({
    this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.createdAt,
    this.updatedAt,
    this.wtrSettings,
    this.displayName_lowercase,
    this.email_lowercase,
  });

  // DODANO: Getter sprawdzający, czy instancja jest pusta
  bool get isEmpty => uid == null || uid!.isEmpty;

  // DODANO: Stała, pusta instancja UserApp do użytku w całej aplikacji
  static const UserApp empty = UserApp(
    uid: '',
    email: '',
    displayName: 'Nieznany',
  );

  @override
  List<Object?> get props => [uid];

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
    if (dateTimeValue is int) {
      return DateTime.fromMillisecondsSinceEpoch(dateTimeValue);
    }
    return null;
  }

  factory UserApp.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Brak danych dla UserApp z dokumentu Firestore: ${doc.id}');
    }
    return UserApp(
      uid: doc.id,
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

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'wtrSettings': wtrSettings?.toJson(),
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
    return 'UserApp{uid: $uid, email: $email, displayName: $displayName}';
  }
}