import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/members_exceptions.dart';
import '../models/member.dart';

class MembersRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference<Member> _membersRef;

  MembersRepository() {
    _membersRef = _firestore.collection('members').withConverter<Member>(
      // Konwertery pozostają bez zmian, ponieważ model Member
      // prawidłowo obsługuje mapowanie danych z i do Firestore.
      fromFirestore: (snapshot, _) => Member.fromFirestore(snapshot),
      toFirestore: (member, _) => member.toMap(),
    );
  }

  /// Tworzy unikalne ID dokumentu na podstawie ID użytkownika i ID właściciela.
  String _createDocId(String userId, String ownerId) => '${userId}_${ownerId}';

  /// Pobiera pojedynczy dokument członkostwa na podstawie userId i ownerId.
  /// Zwraca `null`, jeśli dokument nie istnieje.
  Future<Member?> getMembership({required String userId, required String ownerId}) async {
    final docId = _createDocId(userId, ownerId);
    try {
      final docSnapshot = await _membersRef.doc(docId).get();
      return docSnapshot.data(); // .data() elegancko zwraca null, jeśli docSnapshot.exists jest false
    } catch (e) {
      throw MembersDataException('Nie udało się pobrać danych członkostwa ($docId): $e');
    }
  }

  /// Pobiera listę wszystkich pracowników dla danego `ownerId`.
  /// Ta funkcja pozostaje bez zmian, ponieważ jej zapytanie jest poprawne.
  Future<List<Member>> getMembersByOwner(String ownerId) async {
    if (ownerId.isEmpty) {
      return [];
    }
    try {
      final querySnapshot = await _membersRef.where('ownerId', isEqualTo: ownerId).get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw MembersDataException('Nie udało się pobrać pracowników dla właściciela o ID $ownerId: $e');
    }
  }

  /// Tworzy nowy lub nadpisuje istniejący dokument członkostwa.
  Future<void> setMembership(Member member) async {
    final docId = _createDocId(member.userId, member.ownerId);
    try {
      // Używamy wygenerowanego docId zamiast pola z obiektu
      await _membersRef.doc(docId).set(member, SetOptions(merge: true));
    } catch (e) {
      throw MembersDataException('Nie udało się zapisać danych członkostwa dla ID $docId: $e');
    }
  }

  /// Dodaje nowy, unikalny rekord członkostwa.
  /// Rzuca wyjątek, jeśli członkostwo już istnieje.
  Future<void> addMembership(Member member) async {
    final docId = _createDocId(member.userId, member.ownerId);
    try {
      final docRef = _membersRef.doc(docId);
      final snapshot = await docRef.get();
      if (snapshot.exists) {
        throw MemberAlreadyExistsException('Pracownik (userId: ${member.userId}) jest już przypisany do tej firmy (ownerId: ${member.ownerId}).');
      }
      await docRef.set(member);
    } catch (e) {
      // Przekaż dalej wyjątek MemberAlreadyExistsException lub opakuj inny błąd
      if (e is MemberAlreadyExistsException) rethrow;
      throw MembersDataException('Nie udało się dodać nowego członkostwa dla ID $docId: $e');
    }
  }
  /// NOWA METODA: Pobiera wszystkie wpisy członkostwa dla danego użytkownika (we wszystkich firmach).
  Future<List<Member>> getMembershipsForUser(String userId) async {
    try {
      final querySnapshot = await _membersRef.where('userId', isEqualTo: userId).get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw MembersDataException('Nie udało się pobrać wszystkich członkostw dla użytkownika o ID $userId: $e');
    }
  }
  /// Aktualizuje konkretne pola w dokumencie członkostwa.
  Future<void> updateMembershipData({required String userId, required String ownerId, required Map<String, dynamic> data}) async {
    final docId = _createDocId(userId, ownerId);
    try {
      await _membersRef.doc(docId).update(data);
    } catch (e) {
      throw MembersUpdateException(docId, e.toString());
    }
  }

  /// Usuwa dokument członkostwa z bazy danych.
  Future<void> deleteMembership({required String userId, required String ownerId}) async {
    final docId = _createDocId(userId, ownerId);
    try {
      await _membersRef.doc(docId).delete();
    } catch (e) {
      throw MembersDataException('Nie udało się usunąć członkostwa o ID $docId: $e');
    }
  }
}