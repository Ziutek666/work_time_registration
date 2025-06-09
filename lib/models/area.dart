// lib/features/areas/presentation/screens/areas_screen.dart
// Ten plik zawierał AreasScreen, ale poniżej jest tylko model Area
// dla przejrzystości i zgodnie z prośbą o modyfikację modelu.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Dodano dla ThemeData, ColorScheme, TextTheme w AreasScreen
import 'package:go_router/go_router.dart';
import 'package:work_time_registration/models/project.dart';

import '../services/area_service.dart';
import '../widgets/dialogs.dart';
import 'license.dart'; // Dodano dla GoRouter w AreasScreen

// Importy modeli i serwisów dla AreasScreen (niebezpośrednio dla Area, ale dla kontekstu pliku)
// import '../../models/license.dart';
// import '../../models/project.dart';
// import '../../services/area_service.dart';
// import '../../../widgets/dialogs.dart';


/// Model reprezentujący obszar (area) w systemie.
/// Obszar należy do konkretnego projektu i właściciela.
/// Może mieć przypisanych użytkowników, status aktywności oraz powiązane typy pracy.
class Area {
  final String projectId; // ID projektu, do którego należy obszar
  final String ownerId; // ID właściciela obszaru
  final String areaId; // ID obszaru (klucz dokumentu)
  final String name; // Nazwa obszaru
  final String description; // Opis obszaru
  bool active; // Czy obszar jest aktywny
  List<AreaUser> users; // Lista użytkowników przypisanych do obszaru
  final List<String> workTypesIds; // <<<--- NOWE POLE: Lista ID powiązanych typów pracy

  Area({
    required this.name,
    required this.areaId,
    required this.projectId,
    required this.ownerId,
    this.active = false,
    this.description = '',
    this.users = const [],
    List<String>? workTypesIds, // <<<--- DODANO DO KONSTRUKTORA
  }) : this.workTypesIds = workTypesIds ?? const []; // Domyślnie pusta lista

  /// Tworzy kopię obiektu Area z opcjonalnymi zmianami pól.
  Area copyWith({
    String? projectId,
    String? ownerId,
    String? areaId,
    String? name,
    String? description,
    bool? active,
    List<AreaUser>? users,
    List<String>? workTypesIds, // <<<--- DODANO DO COPYWITH
  }) {
    return Area(
      projectId: projectId ?? this.projectId,
      ownerId: ownerId ?? this.ownerId,
      areaId: areaId ?? this.areaId,
      name: name ?? this.name,
      description: description ?? this.description,
      active: active ?? this.active,
      users: users ?? this.users,
      workTypesIds: workTypesIds ?? this.workTypesIds, // <<<--- LOGIKA DLA WORKTYPESIDS
    );
  }

  /// Tworzy instancję Area na podstawie dokumentu Firestore.
  factory Area.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) { // Poprawiono typ DocumentSnapshot
    final data = doc.data();
    if (data == null) {
      throw StateError("Brak danych dla Area z dokumentu Firestore: ${doc.id}");
    }
    // Dodajemy ID dokumentu do mapy danych, jeśli areaId nie jest tam jeszcze obecne
    final mapWithId = {
      'areaId': doc.id, // Używamy ID dokumentu jako areaId
      ...data,
    };
    return Area.fromMap(mapWithId);
  }

  /// Tworzy instancję Area na podstawie mapy.
  factory Area.fromMap(Map<String, dynamic> data) {
    final usersList = <AreaUser>[];

    if (data['users'] != null && data['users'] is List) {
      for (var userMap in (data['users'] as List)) {
        if (userMap is Map<String, dynamic>) {
          try {
            usersList.add(AreaUser.fromMap(userMap));
          } catch (e) {
            debugPrint('Błąd parsowania AreaUser z mapy: $e, dane: $userMap');
            // Można dodać dalszą obsługę błędu, np. pominięcie błędnego użytkownika
          }
        } else {
          debugPrint('Ostrzeżenie: Nieprawidłowe dane użytkownika na liście użytkowników obszaru: $userMap');
        }
      }
    }

    return Area(
      name: data['name'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      areaId: data['areaId'] as String? ?? '', // Odczyt areaId z mapy
      description: data['description'] as String? ?? '',
      active: data['active'] as bool? ?? false,
      users: usersList,
      workTypesIds: List<String>.from(data['workTypesIds'] as List<dynamic>? ?? const []), // <<<--- ODCZYT Z MAPY
    );
  }


  /// Zwraca mapę do zapisu w Firestore.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'projectId': projectId,
      'ownerId': ownerId,
      'areaId': areaId, // Zapisujemy areaId, chociaż często jest to ID dokumentu
      'description': description,
      'active': active,
      'users': users.map((user) => user.toMap()).toList(),
      'workTypesIds': workTypesIds, // <<<--- DODANO DO MAPY
    };
  }
}

/// Model użytkownika przypisanego do obszaru.
/// Przechowuje dane identyfikacyjne oraz godzinę wejścia.
class AreaUser {
  final String userId; // ID użytkownika
  final String name; // Imię i nazwisko użytkownika
  final String email; // Email użytkownika
  final DateTime entryTime; // Czas wejścia do obszaru

  AreaUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.entryTime,
  });

  /// Tworzy instancję AreaUser z mapy (np. z dokumentu Firestore).
  factory AreaUser.fromMap(Map<String, dynamic> map) {
    return AreaUser(
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      entryTime: (map['entryTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Konwertuje obiekt AreaUser na mapę do zapisu w Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'entryTime': Timestamp.fromDate(entryTime),
    };
  }
}
