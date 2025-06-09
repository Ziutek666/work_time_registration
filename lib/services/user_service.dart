import 'package:firebase_auth/firebase_auth.dart';
import 'package:work_time_registration/services/user_auth_service.dart';
import '../exceptions/auth_exceptions.dart' as auth_ex;
import '../exceptions/user_exceptions.dart';
import '../models/user_app.dart';
import '../models/wtr_settings.dart';
import '../repositories/user_repository.dart';

class UserService {
  // Statyczna zmienna do śledzenia, czy dane użytkownika zostały już załadowane
  static UserApp? _cachedUser;
  static bool _dataChecked = false;

  /// Sprawdza, czy dane użytkownika istnieją i są aktualne. Pobiera z bazy tylko raz na sesję.
  Future<bool> doesUserDataExist() async {
    final String? uid = userAuthService.currentUser?.uid;
    if (uid != null) {
      final User? firebaseUser = userAuthService.currentUser;
      if (firebaseUser != null) {
        if (!_dataChecked || _cachedUser?.uid != uid) {
          // Pobierz dane z bazy tylko jeśli jeszcze nie sprawdzono lub zmienił się użytkownik');
          try {
            _cachedUser = await userRepository.getUser(uid);
            _dataChecked = true;
          } catch (e) {
            print('Błąd podczas sprawdzania istnienia danych użytkownika: $e');
            return false; // W przypadku błędu zakładamy, że danych nie ma lub nie można ich zweryfikować
          }
        }

        if (_cachedUser != null) {
          // Sprawdź, czy dane w pamięci podręcznej są aktualne');
          if (firebaseUser.displayName != _cachedUser!.displayName ||
              firebaseUser.email != _cachedUser!.email) {
            // Aktualizuj bazę danych w tle, aby nie blokować nawigacji
            _updateUserDataFromFirebase(firebaseUser, _cachedUser!);
            return true; // Dane istniały, ale były nieaktualne (aktualizacja w tle)
          }
          // Dane istnieją i są aktualne (w pamięci podręcznej)');
          return true; // Dane istnieją i są aktualne (w pamięci podręcznej)
        } else {
          return false; // Dane nie istnieją w bazie
        }
      }
    }
    _cachedUser = null;
    _dataChecked = false;
    return false; // Jeśli nie ma zalogowanego użytkownika
  }

  // Metoda do aktualizacji danych użytkownika w bazie danych
  Future<void> _updateUserDataFromFirebase(User firebaseUser, UserApp cachedUser) async {
    UserApp updatedUserApp = cachedUser.copyWith(
      displayName: firebaseUser.displayName,
      email: firebaseUser.email,
    );
    try {
      await userRepository.updateUser(updatedUserApp);
      _cachedUser = updatedUserApp; // Aktualizuj pamięć podręczną
      print('Dane użytkownika zaktualizowane z Firebase Auth w tle.');
    } catch (e) {
      print('Błąd podczas aktualizacji danych użytkownika z Firebase: $e');
      // Możesz zdecydować się na bardziej zaawansowaną obsługę błędów tutaj
    }
  }

  Future<UserApp?> getCurrentUser() async {
    final String? uid = userAuthService.currentUser?.uid;
    if (uid != null) {
      if (_cachedUser?.uid == uid && _cachedUser != null) {
        return _cachedUser;
      } else {
        try {
          _cachedUser = await userRepository.getUser(uid);
          _dataChecked = true;
          return _cachedUser;
        } on UserNotFoundException {
          return null; // Użytkownik nie znaleziony w bazie danych
        } catch (e) {
          print('Błąd podczas pobierania bieżącego użytkownika: $e');
          return null;
        }
      }
    }
    _cachedUser = null;
    _dataChecked = false;
    return null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final user = await userRepository.getUserByEmail(email);
      if (user != null) {
        return user;
      } else {
        return null; // Użytkownik o podanym emailu nie znaleziony
      }
    } catch (e) {
      print('Błąd podczas pobierania użytkownika po emailu: $e');
      return null;
    }
  }

  Future<void> createNewUser(String name) async {
    try {
      await userAuthService.saveDisplayName(name);
      final uid = userAuthService.uid;
      final email = userAuthService.email;
      final displayName = userAuthService.displayName;
      final photoURL = userAuthService.photoURL;

      if (uid != null && email != null && displayName != null) {
        var wtrSettings = WtrSettings.defaultSettings(); // Użycie nowej metody fabrycznej
        var userApp = UserApp(
          uid: uid,
          email: email,
          displayName: displayName,
          photoURL: photoURL,
          wtrSettings: wtrSettings,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          email_lowercase: email.toLowerCase(),
          displayName_lowercase: displayName.toLowerCase(),
        );

        await saveUserData(userApp);
      } else {
        throw Exception('Nie udało się uzyskać pełnych danych użytkownika (uid, email, displayName) po aktualizacji nazwy w Firebase Auth.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveUserData(UserApp user) async {
    final String? uid = userAuthService.currentUser?.uid;
    if (uid != null) {
      final UserApp updatedUser = user.copyWith(uid: uid);
      try {
        print('nowy saveUser');
        await userRepository.saveUser(updatedUser);
        _cachedUser = updatedUser;
        _dataChecked = true;
      } on UserUpdateException catch (e) {
        print('Błąd podczas zapisywania danych użytkownika: $e');
        throw e;
      } catch (e) {
        print('Nieznany błąd podczas zapisywania danych użytkownika: $e');
        throw e;
      }
    } else {
      throw Exception('Nie można zapisać danych użytkownika, brak zalogowanego użytkownika.');
    }
  }
  Future<void> updateUserData(UserApp userChanges) async {
    final String? currentUid = userAuthService.currentUser?.uid;
    if (currentUid == null) {
      throw Exception('Brak zalogowanego użytkownika. Nie można zaktualizować danych.');
    }
    // UID w userChanges może być null, jeśli obiekt reprezentuje tylko zmiany.
    // Używamy currentUid jako źródła prawdy dla ID dokumentu.
    if (userChanges.uid != null && userChanges.uid != currentUid) {
      throw Exception('Próba aktualizacji danych innego użytkownika (UID nie pasuje).');
    }

    try {
      // 1. Pobierz aktualny, pełny stan użytkownika z bazy (lub cache, jeśli pewny)
      UserApp? existingUser = _cachedUser?.uid == currentUid ? _cachedUser : await userRepository.getUser(currentUid);

      UserApp userToUpdate;

      if (existingUser != null) {
        // 2. Scal zmiany z 'userChanges' z istniejącym obiektem 'existingUser'
        userToUpdate = existingUser.copyWith(
          // Aktualizuj tylko te pola, które są faktycznie przekazywane w userChanges
          // Jeśli userChanges.displayName jest null, copyWith użyje existingUser.displayName
            displayName: userChanges.displayName, // Zakładamy, że jeśli jest null, nie chcemy zmieniać
            email: userChanges.email,             // Podobnie dla email, choć email zmienia się przez Firebase Auth
            photoURL: userChanges.photoURL,
            wtrSettings: userChanges.wtrSettings, // Jeśli userChanges.wtrSettings jest null, zachowa istniejące
            updatedAt: DateTime.now(),           // Zawsze aktualizuj 'updatedAt'

            // Upewnij się, że pola lowercase są aktualizowane, jeśli główne pola się zmieniły
            displayName_lowercase: (userChanges.displayName ?? existingUser.displayName)?.toLowerCase(),
            email_lowercase: (userChanges.email ?? existingUser.email)?.toLowerCase(),

            // createdAt nie powinno się zmieniać podczas aktualizacji
            createdAt: existingUser.createdAt
        );
      } else {
        // Ten przypadek jest mniej prawdopodobny, jeśli użytkownik jest zalogowany i aktualizuje swoje dane.
        // Oznaczałoby to, że nie ma wpisu w bazie 'users' dla zalogowanego użytkownika.
        // Można rzucić błąd lub spróbować utworzyć nowy wpis na podstawie userChanges.
        print('UserService: Istniejące dane użytkownika nie znalezione dla $currentUid podczas aktualizacji. Tworzenie na podstawie userChanges.');
        userToUpdate = UserApp(
          uid: currentUid,
          displayName: userChanges.displayName,
          email: userChanges.email, // Powinno być zsynchronizowane z Firebase Auth
          photoURL: userChanges.photoURL,
          wtrSettings: userChanges.wtrSettings ?? WtrSettings.defaultSettings(),
          createdAt: userChanges.createdAt ?? DateTime.now(), // Lub pobierz, jeśli to możliwe
          updatedAt: DateTime.now(),
          displayName_lowercase: userChanges.displayName?.toLowerCase(),
          email_lowercase: userChanges.email?.toLowerCase(),
        );
      }

      await userRepository.updateUser(userToUpdate);
      _cachedUser = userToUpdate; // Zaktualizuj cache kompletnym, scalonym obiektem

    } on UserUpdateException catch (e) {
      print('Błąd podczas aktualizacji danych użytkownika (UserUpdateException): $e');
      throw e;
    } catch (e) {
      print('Nieznany błąd podczas aktualizacji danych użytkownika: $e');
      rethrow;
    }
  }
  Future<void> updateUserData_old(UserApp user) async {
    final String? currentUid = userAuthService.currentUser?.uid;
    if (currentUid == null) {
      throw Exception('Brak zalogowanego użytkownika.');
    }
    if (user.uid != currentUid) {
      throw Exception('Próba aktualizacji danych innego użytkownika.');
    }
    try {
      await userRepository.updateUser(user);
      _cachedUser = user;
    } on UserUpdateException catch (e) {
      print('Błąd podczas aktualizacji danych użytkownika: $e');
      throw e;
    } catch (e) {
      print('Nieznany błąd podczas aktualizacji danych użytkownika: $e');
      rethrow;
    }
  }

  Future<UserApp?> getUserData(String uid) async {
    if (_cachedUser?.uid == uid) {
      return _cachedUser;
    } else {
      try {
        return await userRepository.getUser(uid);
      } on UserNotFoundException {
        return null;
      } catch (e) {
        print('Błąd podczas pobierania danych użytkownika: $e');
        return null;
      }
    }
  }

  Future<List<UserApp>> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }
    try {
      // Zakładamy, że UserRepository ma metodę searchUsersInFirestore
      // która wykonuje odpowiednie zapytanie do bazy danych.
      // To zapytanie może być złożone i wymagać indeksów w Firestore.
      // Przykład: wyszukiwanie po `displayName` i `email`.
      // Dla uproszczenia, nie implementujemy tutaj logiki "case-insensitive"
      // ani wyszukiwania po fragmentach - to powinno być zrobione w repozytorium.
      print('UserService: Wyszukiwanie użytkowników dla zapytania: "$query"');
      final results = await userRepository.searchUsersInFirestore(query.toLowerCase());
      print('UserService: Znaleziono ${results.length} użytkowników dla zapytania "$query"');
      return results;
    } catch (e, stackTrace) {
      print('UserService: Błąd podczas wyszukiwania użytkowników: $e\n$stackTrace');
      // Można rzucić bardziej specyficzny wyjątek lub zwrócić pustą listę
      throw UserFetchException('Wystąpił błąd podczas wyszukiwania użytkowników: ${e.toString()}');
      // return [];
    }
  }

  Future<UserApp?> getUserByExactEmail(String email) async { // Zmieniono nazwę i typ zwracany
    if (email.trim().isEmpty) return null;
    try {
      // Wykorzystujemy zmodyfikowaną metodę z repozytorium
      final List<UserApp> users = await userRepository.searchUsersInFirestore(email.toLowerCase());
      if (users.isNotEmpty) {
        // Zakładamy, że email jest unikalny, więc bierzemy pierwszy wynik
        return users.first;
      }
      return null;
    } catch (e) {
      print('UserService: Błąd podczas pobierania użytkownika po dokładnym emailu: $e');
      throw UserFetchException('Wystąpił błąd podczas wyszukiwania użytkownika po emailu: ${e.toString()}');
    }
  }
  // *** NOWA FUNKCJA ***
  /// Pobiera listę użytkowników na podstawie listy ich ID.
  /// Zwraca pustą listę w przypadku błędu lub gdy nie znaleziono użytkowników.
  Future<List<UserApp>> getUsersByIds(List<String> uids) async {
    final validUids = uids.where((uid) => uid.isNotEmpty).toSet().toList();

    if (validUids.isEmpty) {
      print('UserService: fetchUsersByIds called with an empty or invalid list of UIDs.');
      return [];
    }

    try {
      print('UserService: Fetching users by IDs: $validUids');
      final users = await userRepository.getUsersByIds(validUids);
      // Nie aktualizujemy tutaj _cachedUser, ponieważ dotyczy to potencjalnie wielu użytkowników,
      // a _cachedUser jest tylko dla bieżącego.
      return users;
    } on UserFetchException catch (e, s) {
      print('UserService: UserFetchException while fetching users by IDs: $e\n$s');
      throw UserFetchException('Wystąpił błąd podczas pobierania użytkowników: $e');
      return []; // Zwróć pustą listę w przypadku błędu z repozytorium
    } catch (e, s) {
      print('UserService: Unexpected error while fetching users by IDs: $e\n$s');
      throw UserFetchException('Wystąpił błąd podczas pobierania użytkowników: $e');
      return []; // Zwróć pustą listę w przypadku innego błędu
    }
  }
  // *** KONIEC NOWEJ FUNKCJI ***
  String? get displayName => _cachedUser?.displayName ?? userAuthService.displayName;
  String? get email => _cachedUser?.email ?? userAuthService.email;
  String? get uid => _cachedUser?.uid ?? userAuthService.uid;

  get currentUser => getCurrentUser();
}

final  userService = UserService();