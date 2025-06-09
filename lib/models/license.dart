import 'package:cloud_firestore/cloud_firestore.dart';

/// Model danych reprezentujący licencję przypisaną do projektu.
/// Przechowuje dane ograniczeń licencji oraz informacje o subskrypcji Stripe.
class License {
  /// Id dokumentu Firestore (identyfikator samej licencji).
  final String licenseId;

  /// Id projektu, do którego przypisana jest licencja.
  final String projectId;

  /// Id użytkownika (właściciela) licencji.
  final String ownerId;

  /// Maksymalna liczba unikalnych akcji.
  final int actions;

  /// Maksymalna liczba wykonanych operacji.
  final int maxExecutions;

  /// Liczba wykonanych operacji - kasowana raz na miesiąc.
  final int usedExecutions;

  /// Liczba dostępnych obszarów logicznych.
  final int areas;

  /// Liczba dostępnych szablonów dostępu.
  final int templates;

  /// Liczba kodów QR przypisanych do projektu.
  final int qrCodes;

  /// **NOWE POLE:** Liczba dostępnych typów prac.
  final int workTypes;

  /// Data i godzina wygaśnięcia licencji (jako Firestore `Timestamp`).
  final Timestamp validityTime;

  /// Opcjonalny opis licencji.
  final String description;

  /// Licencja w trybie testowym (początkowym).
  final bool testMode;

  /// ID subskrypcji Stripe.
  final String? stripeSubscriptionId;

  /// Status subskrypcji Stripe.
  final String? stripeSubscriptionStatus;

  /// ID klienta Stripe.
  final String? stripeCustomerId;

  /// Data utworzenia licencji.
  final Timestamp creationTime;

  /// Konstruktor.
  License({
    required this.licenseId,
    required this.projectId,
    required this.ownerId,
    required this.actions,
    required this.maxExecutions,
    required this.usedExecutions,
    required this.areas,
    required this.templates,
    required this.qrCodes,
    required this.workTypes, // Dodano workTypes
    required this.validityTime,
    required this.testMode,
    required this.creationTime,
    this.description = '',
    this.stripeSubscriptionId,
    this.stripeSubscriptionStatus,
    this.stripeCustomerId,
  });

  /// Metoda copyWith.
  License copyWith({
    String? licenseId,
    String? projectId,
    String? ownerId,
    int? actions,
    int? maxExecutions,
    int? usedExecutions,
    int? areas,
    int? templates,
    int? qrCodes,
    int? workTypes, // Dodano workTypes
    Timestamp? validityTime,
    String? description,
    bool? testMode,
    String? stripeSubscriptionId,
    String? stripeSubscriptionStatus,
    String? stripeCustomerId,
    Timestamp? creationTime,
  }) {
    return License(
      licenseId: licenseId ?? this.licenseId,
      projectId: projectId ?? this.projectId,
      ownerId: ownerId ?? this.ownerId,
      actions: actions ?? this.actions,
      maxExecutions: maxExecutions ?? this.maxExecutions,
      usedExecutions: usedExecutions ?? this.usedExecutions,
      areas: areas ?? this.areas,
      templates: templates ?? this.templates,
      qrCodes: qrCodes ?? this.qrCodes,
      workTypes: workTypes ?? this.workTypes, // Dodano workTypes
      validityTime: validityTime ?? this.validityTime,
      description: description ?? this.description,
      testMode: testMode ?? this.testMode,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripeSubscriptionStatus: stripeSubscriptionStatus ?? this.stripeSubscriptionStatus,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      creationTime: creationTime ?? this.creationTime,
    );
  }

  /// Fabryczna metoda z dokumentu Firestore.
  factory License.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null || data is! Map<String, dynamic>) {
      throw StateError('License.fromFirestore: Document data is not a Map<String, dynamic>: ${doc.id}');
    }

    final validityTimestamp = data['validityTime'];
    if (validityTimestamp is! Timestamp) {
      throw StateError('License.fromFirestore: validityTime is not a Timestamp in document: ${doc.id}');
    }

    final creationTimestamp = data['creationTime'];
    if (creationTimestamp is! Timestamp) {
      throw StateError('License.fromFirestore: creationTime is not a Timestamp in document: ${doc.id}');
    }

    return License(
      licenseId: data['licenseId'] ?? doc.id,
      projectId: data['projectId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      actions: (data['actions'] ?? 0) as int,
      maxExecutions: (data['maxExecutions'] ?? 0) as int,
      usedExecutions: (data['usedExecutions'] ?? 0) as int,
      areas: (data['areas'] ?? 0) as int,
      templates: (data['templates'] ?? 0) as int,
      qrCodes: (data['qrCodes'] ?? 0) as int,
      workTypes: (data['workTypes'] ?? 0) as int, // Dodano workTypes z wartością domyślną 0
      validityTime: validityTimestamp,
      testMode: data['testMode'] ?? true,
      description: data['description'] ?? '',
      stripeSubscriptionId: data['stripeSubscriptionId'] as String?,
      stripeSubscriptionStatus: data['stripeSubscriptionStatus'] as String?,
      stripeCustomerId: data['stripeCustomerId'] as String?,
      creationTime: creationTimestamp,
    );
  }

  /// Fabryczna metoda z mapy.
  factory License.fromMap(Map<String, dynamic> data,) {
    final validityTimestamp = data['validityTime'];
    if (validityTimestamp is! Timestamp) {
      throw StateError('License.fromMap: validityTime is not a Timestamp.');
    }
    final creationTimestamp = data['creationTime'];
    if (creationTimestamp is! Timestamp) {
      throw StateError('License.fromMap: creationTime is not a Timestamp.');
    }

    return License(
      licenseId: data['licenseId'] ?? '',
      projectId: data['projectId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      actions: (data['actions'] ?? 0) as int,
      maxExecutions: (data['maxExecutions'] ?? 0) as int,
      usedExecutions: (data['usedExecutions'] ?? 0) as int,
      areas: (data['areas'] ?? 0) as int,
      templates: (data['templates'] ?? 0) as int,
      qrCodes: (data['qrCodes'] ?? 0) as int,
      workTypes: (data['workTypes'] ?? 0) as int, // Dodano workTypes z wartością domyślną 0
      testMode: (data['testMode'] ?? true),
      validityTime: validityTimestamp,
      description: data['description'] ?? '',
      stripeSubscriptionId: data['stripeSubscriptionId'] as String?,
      stripeSubscriptionStatus: data['stripeSubscriptionStatus'] as String?,
      stripeCustomerId: data['stripeCustomerId'] as String?,
      creationTime: creationTimestamp,
    );
  }

  /// Zwraca mapę do Firestore.
  Map<String, dynamic> toMap() {
    return {
      'licenseId': licenseId,
      'projectId': projectId,
      'ownerId': ownerId,
      'actions': actions,
      'maxExecutions': maxExecutions,
      'usedExecutions': usedExecutions,
      'areas': areas,
      'templates': templates,
      'qrCodes': qrCodes,
      'workTypes': workTypes, // Dodano workTypes
      'testMode': testMode,
      'validityTime': validityTime,
      'description': description,
      'stripeSubscriptionId': stripeSubscriptionId,
      'stripeSubscriptionStatus': stripeSubscriptionStatus,
      'stripeCustomerId': stripeCustomerId,
      'creationTime': creationTime,
    };
  }

  /// Zwraca `true` jeżeli licencja jest w trybie testowym.
  bool get isTestMode => testMode;

  /// Zwraca true tylko jeśli:
  /// - licencja jest wciąż ważna czasowo
  /// - liczba użyć nie przekroczyła limitu
  /// - (po 30 dniach od utworzenia) subskrypcja Stripe musi być aktywna (jeśli istnieje)
  bool get isValid {
    final DateTime now = DateTime.now();
    final DateTime thirtyDaysAfterCreation = creationTime.toDate().add(Duration(days: 30));
    final bool withinTime = validityTime.toDate().isAfter(now);
    final bool withinUsage = usedExecutions < maxExecutions;
    final bool isWithinTrial = now.isBefore(thirtyDaysAfterCreation);
    // Updated to include 'trialing' and 'past_due' as potentially valid states for a subscription,
    // depending on business logic. 'past_due' might still allow service for a grace period.
    final bool isStripeActive = stripeSubscriptionStatus == 'active' ||
        stripeSubscriptionStatus == 'trialing' ||
        stripeSubscriptionStatus == 'past_due';

    if (isWithinTrial) {
      return withinTime && withinUsage;
    } else {
      // If a stripe subscription ID exists, its status MUST be active (or trialing/past_due)
      // for the license to be valid after the initial 30-day period.
      if (stripeSubscriptionId != null && stripeSubscriptionId!.isNotEmpty) {
        return withinTime && withinUsage && isStripeActive;
      }
      // If no stripe subscription ID exists after the trial period,
      // the license might be considered invalid or operate under different rules.
      // For now, assuming it's valid if other conditions met, but this might need adjustment
      // based on specific business requirements for licenses without Stripe subscriptions post-trial.
      // If a license *must* have an active Stripe subscription after 30 days,
      // then this should return 'false' or 'withinTime && withinUsage && false' (effectively false).
      // Based on the original logic: "Jeśli brak ID subskrypcji po okresie próbnym"
      // it seems it was intended to still be valid based on time/usage if no Stripe ID.
      return withinTime && withinUsage;
    }
  }

  /// Zwraca datę ważności jako `DateTime`.
  DateTime get validUntil => validityTime.toDate();

  /// Zwraca datę utworzenia jako `DateTime`.
  DateTime get createdAt => creationTime.toDate();
}