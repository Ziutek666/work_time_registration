import 'dart:io'; // Potrzebne dla typu File
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import dla Firebase Storage
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Potrzebne dla debugPrint
// Zakładamy, że userService jest instancją klasy kompatybilnej z UserRepository
// lub samego UserRepository, który dostarcza metodę saveUser.
import 'package:work_time_registration/services/user_service.dart';
import '../exceptions/auth_exceptions.dart';
import '../models/user_app.dart'; // Import modelu UserApp

class UserAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // Instancja Firebase Storage

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    if (!email.contains('@')) {
      throw AuthException('Nieprawidłowy adres email');
    }
    if (password.length < 6) {
      throw AuthException('Hasło musi mieć minimum 6 znaków');
    }
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  Future<UserCredential?> registerWithEmailAndPassword(String email, String password) async {
    if (!email.contains('@')) {
      throw AuthException('Nieprawidłowy adres email');
    }
    if (password.length < 6) {
      throw AuthException('Hasło musi mieć minimum 6 znaków');
    }
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw e;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  bool get isLoggedIn => _auth.currentUser != null;

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  String? get email => _auth.currentUser?.email;

  String? get uid => _auth.currentUser?.uid;

  String? get displayName => _auth.currentUser?.displayName;

  String? get photoURL => _auth.currentUser?.photoURL;

  Future<void> sendEmailVerification() async {
    if (_auth.currentUser != null && !_auth.currentUser!.emailVerified) {
      await _auth.currentUser!.sendEmailVerification();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (email.isEmpty) {
      throw AuthException("Adres email nie może być pusty.");
    }
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> saveDisplayName(String displayName) async {
    if (displayName.trim().length < 3) {
      throw AuthException('Nieprawidłowa nazwa użytkownika (minimum 3 znaki).');
    }
    if (_auth.currentUser != null) {
      await _auth.currentUser!.updateDisplayName(displayName.trim());
      await _auth.currentUser?.reload();
    } else {
      throw AuthException("Użytkownik nie jest zalogowany. Nie można zaktualizować nazwy.");
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    if (displayName.trim().length < 3) {
      throw AuthException('Nieprawidłowa nazwa użytkownika (minimum 3 znaki).');
    }
    if (_auth.currentUser != null) {
      await _auth.currentUser!.updateDisplayName(displayName.trim());
      await _auth.currentUser?.reload();

      final String? currentUid = _auth.currentUser?.uid;
      if (currentUid != null) {
        UserApp userToUpdate = UserApp(uid: currentUid, displayName: displayName.trim(), updatedAt: DateTime.now());
        await userService.updateUserData(userToUpdate);
      }
    } else {
      throw AuthException("Użytkownik nie jest zalogowany. Nie można zaktualizować nazwy.");
    }
  }

  Future<void> updateEmail(String newEmail) async {
    if (!newEmail.contains('@')) {
      throw AuthException('Nieprawidłowy format adresu email.');
    }
    if (_auth.currentUser != null) {
      try {
        debugPrint('UserAuthService: Attempting to update email to $newEmail');
        await _auth.currentUser!.verifyBeforeUpdateEmail(newEmail.trim());
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          throw AuthException('Ten adres e-mail jest już używany przez inne konto.');
        } else if (e.code == 'requires-recent-login') {
          throw AuthException('Ta operacja wymaga niedawnego zalogowania. Proszę zalogować się ponownie i spróbować jeszcze raz.');
        }
        throw e;
      }
    } else {
      throw AuthException("Użytkownik nie jest zalogowany. Nie można zaktualizować adresu e-mail.");
    }
  }

  Future<void> updatePhotoURLAndUpload({File? imageFile, Uint8List? imageBytes, String? fileName}) async {
    if (currentUser == null) {
      throw AuthException('Użytkownik nie jest zalogowany. Nie można zaktualizować zdjęcia.');
    }
    // Sprawdzenie, czy dostarczono odpowiednie dane dla platformy
    if (!kIsWeb && imageFile == null) {
      throw AuthException('Brak pliku obrazu dla platformy mobilnej/desktopowej.');
    }
    if (kIsWeb && imageBytes == null) {
      throw AuthException('Brak danych obrazu dla platformy web.');
    }

    try {
      final String userId = currentUser!.uid;
      // Użyj przekazanej nazwy pliku (ważne dla web do określenia MIME type) lub wygeneruj unikalną
      final String uniqueFileName = fileName ?? 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = _storage.ref().child('profile_pictures').child(userId).child(uniqueFileName);
      UploadTask uploadTask;

      if (kIsWeb) {
        // Dla web używamy putData z Uint8List
        if (imageBytes == null) throw AuthException('Brak danych obrazu dla platformy web.'); // Zabezpieczenie
        String mimeType = 'image/jpeg'; // Domyślny typ MIME
        if (fileName != null) {
          final extension = fileName.split('.').last.toLowerCase();
          if (extension == 'png') mimeType = 'image/png';
          else if (extension == 'gif') mimeType = 'image/gif';
          else if (extension == 'webp') mimeType = 'image/webp';
          // Dodaj więcej typów MIME w razie potrzeby
        }
        debugPrint('UserAuthService (Web): Uploading data with MIME type: $mimeType, FileName: $uniqueFileName');
        uploadTask = storageRef.putData(imageBytes, SettableMetadata(contentType: mimeType));
      } else {
        // Dla platform mobilnych/desktopowych używamy putFile
        if (imageFile == null) throw AuthException('Brak pliku obrazu dla platformy mobilnej/desktopowej.'); // Zabezpieczenie
        debugPrint('UserAuthService (Mobile/Desktop): Uploading file, FileName: $uniqueFileName');
        uploadTask = storageRef.putFile(imageFile!); // Dodano ! po imageFile, bo sprawdziliśmy, że nie jest null
      }

      // Oczekiwanie na zakończenie wgrywania
      TaskSnapshot snapshot = await uploadTask;
      // Pobranie URL do pobrania wgranego zdjęcia
      final String newPhotoURL = await snapshot.ref.getDownloadURL();

      // Aktualizacja photoURL w profilu FirebaseAuth
      await currentUser!.updatePhotoURL(newPhotoURL);

      // Aktualizacja photoURL i updatedAt w Twojej bazie danych użytkowników (np. Firestore)
      UserApp userToUpdate = UserApp(uid: userId, photoURL: newPhotoURL, updatedAt: DateTime.now());
      await userService.updateUserData(userToUpdate); // Używamy saveUser

      // Odświeżenie danych zalogowanego użytkownika
      await currentUser!.reload();
      debugPrint('UserAuthService: Profile photo updated successfully. New URL: $newPhotoURL');

    } on FirebaseException catch (e) {
      debugPrint('UserAuthService: Firebase error during photo upload: Code: ${e.code}, Message: ${e.message}');
      throw AuthException('Błąd podczas wgrywania zdjęcia: ${e.message}');
    } catch (e) {
      debugPrint('UserAuthService: Generic error during photo upload: ${e.toString()}');
      if (e.toString().contains('Platform._operatingSystem')) {
        debugPrint('UserAuthService: Detected Platform._operatingSystem error despite kIsWeb check. Investigate.');
      }
      throw AuthException('Nie udało się zaktualizować zdjęcia profilowego: ${e.toString()}');
    }
  }
}

final userAuthService = UserAuthService();
