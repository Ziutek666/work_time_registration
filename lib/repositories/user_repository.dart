import 'package:cloud_firestore/cloud_firestore.dart';

import '../exceptions/user_exceptions.dart';
import '../models/user_app.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserApp?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserApp.fromFirestore(doc);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('email_lowercase', isEqualTo: email.toLowerCase()) // Wyszukuj po email_lowercase
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      // Zwracamy dane pierwszego znalezionego dokumentu
      // return querySnapshot.docs.first.data(); - to zwraca Map, a potrzebujemy UserApp
      // Zamiast tego, użyjmy fromFirestore, aby od razu dostać obiekt UserApp
      final userDoc = querySnapshot.docs.first;
      // Sprawdźmy, czy UserApp.fromFirestore jest zdefiniowane i działa poprawnie
      try {
        // Zakładamy, że UserApp.fromFirestore przyjmuje DocumentSnapshot<Map<String, dynamic>>
        // Jeśli UserApp.fromFirestore oczekuje Map<String, dynamic>, to:
        // return UserApp.fromJson({...userDoc.data(), 'uid': userDoc.id});
        // Dla uproszczenia, jeśli UserApp.fromFirestore jest OK:
        final userApp = UserApp.fromFirestore(userDoc);
        // Zwracamy mapę, bo taka jest sygnatura oryginalnej metody getUserByEmail w UserService
        // Ale dla searchUsersInFirestore będziemy zwracać List<UserApp>
        return userApp.toMap(); // Lub dostosuj sygnaturę getUserByEmail w UserService
      } catch (e) {
        print("Błąd konwersji UserApp.fromFirestore w getUserByEmail: $e");
        return null;
      }
    }
    return null;
  }

  Future<void> saveUser(UserApp user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> updateUser(UserApp user) async {
    await _firestore.collection('users').doc(user.uid).update(user.toMap());
  }

  Future<List<UserApp>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    List<UserApp> users = [];
    List<List<String>> chunks = [];
    for (var i = 0; i < uids.length; i += 10) {
      chunks.add(uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10));
    }
    for (var chunk in chunks) {
      final querySnapshot = await _firestore.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
      users.addAll(querySnapshot.docs.map((doc) => UserApp.fromFirestore(doc)).toList());
    }
    return users;
  }

  /// Wyszukuje użytkowników w Firestore na podstawie zapytania (query).
  /// Jeśli query wygląda jak email, szuka dokładnego dopasowania w `email_lowercase`.
  /// W przeciwnym razie, próbuje dopasować do `displayName_lowercase` (jako prefix).
  Future<List<UserApp>> searchUsersInFirestore(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }
    final String lowercaseQuery = query.toLowerCase();
    List<UserApp> results = [];
    Set<String> foundUserIds = {};

    try {
      // Sprawdź, czy query to potencjalnie email
      bool isEmailQuery = lowercaseQuery.contains('@') && lowercaseQuery.contains('.');

      if (isEmailQuery) {
        // Wyszukiwanie po email_lowercase (dokładne dopasowanie)
        final emailQuerySnapshot = await _firestore
            .collection('users')
            .where('email_lowercase', isEqualTo: lowercaseQuery)
            .limit(1) // Oczekujemy jednego wyniku dla dokładnego emaila
            .get();

        for (var doc in emailQuerySnapshot.docs) {
          if (!foundUserIds.contains(doc.id)) {
            results.add(UserApp.fromFirestore(doc));
            foundUserIds.add(doc.id);
          }
        }
      } else {
        // Wyszukiwanie po displayName_lowercase (prefix matching)
        // To zapytanie wymaga odpowiedniego indeksu w Firestore
        final nameQuerySnapshot = await _firestore
            .collection('users')
            .where('displayName_lowercase', isGreaterThanOrEqualTo: lowercaseQuery)
            .where('displayName_lowercase', isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
            .limit(10)
            .get();

        for (var doc in nameQuerySnapshot.docs) {
          if (!foundUserIds.contains(doc.id)) {
            results.add(UserApp.fromFirestore(doc));
            foundUserIds.add(doc.id);
          }
        }
      }
      print('UserRepository: Znaleziono ${results.length} użytkowników dla "$query"');
      return results;
    } on FirebaseException catch (e, s) {
      print('UserRepository: Błąd Firestore podczas wyszukiwania użytkowników: $e\n$s');
      throw UserFetchException('Błąd bazy danych podczas wyszukiwania użytkowników: ${e.message}');
    } catch (e,s) {
      print('UserRepository: Nieznany błąd podczas wyszukiwania użytkowników: $e\n$s');
      throw UserFetchException('Nieoczekiwany błąd podczas wyszukiwania użytkowników.');
    }
  }
}
final userRepository = UserRepository();