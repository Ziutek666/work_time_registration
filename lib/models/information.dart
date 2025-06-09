import 'package:cloud_firestore/cloud_firestore.dart';
class Information {
  final String informationId;
  final String projectId;
  String title;
  String content;

  final String categoryId;

  final bool requiresDecision;
  final bool textResponseRequiredOnDecision;

  bool? decision;
  String? textResponse;

  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final bool adminRead;
  final bool showOnStart;
  final bool showOnStop;

  Information({
    required this.informationId,
    required this.projectId,
    required this.title,
    required this.content,
    required this.categoryId,
    required this.createdAt,
    this.updatedAt,
    this.requiresDecision = false,
    this.textResponseRequiredOnDecision = false,
    this.decision,
    this.textResponse,
    // List<UserAction>? acceptedBy, // USUNIĘTO
    // List<UserAction>? declinedBy, // USUNIĘTO
    this.adminRead = false,
    this.showOnStart = false,
    this.showOnStop = false,
  });

  factory Information.fromMap(Map<String, dynamic> data) {
    return Information(
      informationId: data['informationId'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      requiresDecision: data['requiresDecision'] as bool? ?? false,
      textResponseRequiredOnDecision: data['textResponseRequiredOnDecision'] as bool? ?? false,
      decision: data['decision'] as bool?,
      textResponse: data['textResponse'] as String?,
      // Usunięto odczyt 'acceptedBy' i 'declinedBy'
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
      adminRead: data['adminRead'] as bool? ?? false,
      showOnStart: data['showOnStart'] as bool? ?? false,
      showOnStop: data['showOnStop'] as bool? ?? false,
    );
  }

  factory Information.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError("Missing data for Information fromFirestore, docId: ${doc.id}");
    }
    final mapData = {'informationId': doc.id, ...data};
    return Information.fromMap(mapData);
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'requiresDecision': requiresDecision,
      'textResponseRequiredOnDecision': textResponseRequiredOnDecision,
      'decision': decision,
      'textResponse': textResponse,
      // Usunięto zapis 'acceptedBy' i 'declinedBy'
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      'adminRead': adminRead,
      'showOnStart': showOnStart,
      'showOnStop': showOnStop,
    };
  }

  Information copyWith({
    String? informationId,
    String? projectId,
    String? title,
    String? content,
    String? categoryId,
    bool? requiresDecision,
    bool? textResponseRequiredOnDecision,
    bool? decision,
    String? textResponse,
    bool? clearTextResponse,
    // List<UserAction>? acceptedBy, // USUNIĘTO
    // List<UserAction>? declinedBy, // USUNIĘTO
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool? setUpdatedAtToNull,
    bool? adminRead,
    bool? showOnStart,
    bool? showOnStop,
  }) {
    return Information(
      informationId: informationId ?? this.informationId,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      requiresDecision: requiresDecision ?? this.requiresDecision,
      textResponseRequiredOnDecision: textResponseRequiredOnDecision ?? this.textResponseRequiredOnDecision,
      decision: decision ?? this.decision,
      textResponse: clearTextResponse == true ? null : (textResponse ?? this.textResponse),
      // Usunięto 'acceptedBy' i 'declinedBy' z konstruktora
      createdAt: createdAt ?? this.createdAt,
      updatedAt: setUpdatedAtToNull == true ? null : (updatedAt ?? this.updatedAt),
      adminRead: adminRead ?? this.adminRead,
      showOnStart: showOnStart ?? this.showOnStart,
      showOnStop: showOnStop ?? this.showOnStop,
    );
  }

// USUNIĘTO METODY: addAcceptance, addRejection
}