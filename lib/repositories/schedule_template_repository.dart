import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/schedule_template_exceptions.dart';
import '../models/schedule_template.dart';


abstract class IScheduleTemplateRepository {
  Future<ScheduleTemplate> getScheduleTemplateById(String templateId);
  Future<List<ScheduleTemplate>> getAllTemplatesForOwner(String ownerId);
  Future<String> createScheduleTemplate(ScheduleTemplate template);
  Future<void> updateScheduleTemplate(ScheduleTemplate template);
  Future<void> deleteScheduleTemplate(String templateId);
  Future<List<ScheduleTemplate>> getTemplatesForProject(String projectId);
}

class ScheduleTemplateRepository implements IScheduleTemplateRepository {
  final FirebaseFirestore _firestore;

  // Kolekcja w Firestore dla szablonów harmonogramów
  static const String _collectionPath = 'schedule_templates';

  ScheduleTemplateRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<ScheduleTemplate> get _templatesCollection =>
      _firestore.collection(_collectionPath).withConverter<ScheduleTemplate>(
        fromFirestore: (snapshot, _) => ScheduleTemplate.fromFirestore(snapshot),
        toFirestore: (template, _) => template.toMap(),
      );

  @override
  Future<String> createScheduleTemplate(ScheduleTemplate template) async {
    try {
      final docRef = await _templatesCollection.add(template);
      return docRef.id;
    } on FirebaseException catch (e) {
      throw ScheduleTemplateOperationException('Błąd podczas tworzenia szablonu: ${e.message}');
    }
  }

  @override
  Future<void> deleteScheduleTemplate(String templateId) async {
    try {
      await _templatesCollection.doc(templateId).delete();
    } on FirebaseException catch (e) {
      throw ScheduleTemplateOperationException('Błąd podczas usuwania szablonu: ${e.message}');
    }
  }

  @override
  Future<List<ScheduleTemplate>> getAllTemplatesForOwner(String ownerId) async {
    try {
      final querySnapshot = await _templatesCollection
          .where('ownerId', isEqualTo: ownerId)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } on FirebaseException catch (e) {
      throw ScheduleTemplateOperationException('Błąd podczas pobierania szablonów: ${e.message}');
    }
  }

  @override
  Future<ScheduleTemplate> getScheduleTemplateById(String templateId) async {
    try {
      final doc = await _templatesCollection.doc(templateId).get();
      if (!doc.exists) {
        throw ScheduleTemplateNotFoundException();
      }
      return doc.data()!;
    } on FirebaseException catch (e) {
      throw ScheduleTemplateOperationException('Błąd podczas pobierania szablonu: ${e.message}');
    }
  }

  @override
  Future<void> updateScheduleTemplate(ScheduleTemplate template) async {
    try {
      if (template.templateId.isEmpty) {
        throw ScheduleTemplateValidationException('ID szablonu nie może być puste podczas aktualizacji.');
      }
      await _templatesCollection.doc(template.templateId).update(template.toMap());
    } on FirebaseException catch (e) {
      throw ScheduleTemplateOperationException('Błąd podczas aktualizacji szablonu: ${e.message}');
    }
  }

  // W klasie ScheduleTemplateRepository
  @override
  Future<List<ScheduleTemplate>> getTemplatesForProject(String projectId) async {
    try {
      final querySnapshot = await _templatesCollection
          .where('projectId', isEqualTo: projectId)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } on FirebaseException catch (e) {
      throw ScheduleTemplateOperationException('Błąd podczas pobierania szablonów dla projektu: ${e.message}');
    }
  }
}