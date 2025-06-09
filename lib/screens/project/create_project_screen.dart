import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/license_service.dart'; // Założenie: Poprawny import
import '../../services/project_service.dart'; // Założenie: Poprawny import
import '../../services/user_service.dart';   // Założenie: Poprawny import
import '../../widgets/dialogs.dart';      // Założenie: Poprawny import

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key}); // Dodano super.key

  @override
  _CreateProjectScreenState createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isCreating = false; // Flaga do śledzenia stanu tworzenia

  // Instancje serwisów - upewnij się, że są poprawnie inicjalizowane
  // Możesz je przekazywać przez konstruktor lub używać globalnych instancji,
  // jeśli tak jest w Twoim projekcie.
  final ProjectService projectService = ProjectService();
  final LicenseService licenseService = LicenseService();
  final UserService userService = UserService();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createProject() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isCreating = true; // Pokaż wskaźnik ładowania
      });

      final projectName = _nameController.text.trim();
      final projectDescription = _descriptionController.text.trim();

      debugPrint('Tworzenie projektu o nazwie: $projectName, opis: $projectDescription');
      var uid = userService.uid;

      if (uid != null && uid.isNotEmpty) {
        try {
          var projectId = await projectService.createProject(
            uid,
            projectName,
            description: projectDescription,
          );

          // Tworzenie licencji dla projektu (licencja testowa na 1 miesiąc)
          DateTime now = DateTime.now();
          DateTime monthLater = DateTime(now.year, now.month + 1, now.day, now.hour, now.minute);
          Timestamp validityTime = Timestamp.fromDate(monthLater);

          await licenseService.createLicense(
            projectId: projectId,
            ownerId: uid,
            validityTime: validityTime,
            // Domyślne wartości dla licencji testowej, np.:
            actions: 8,
            maxExecutions: 1000,
            usedExecutions: 0,
            areas: 4,
            templates: 4,
            qrCodes: 4,
            workTypes: 4, // Dodane z poprzednich zmian
            testMode: true,
            description: 'Licencja testowa',
          );

          if (mounted) {
            await showSuccessDialog(context, 'Sukces!', 'Utworzono nowy projekt "$projectName" oraz przypisano licencję testową.');
            // Przekaż true, aby poprzedni ekran wiedział, że ma odświeżyć dane
            context.pop(true);
          }
        } catch (e, stackTrace) {
          if (mounted) {
            await showErrorDialog(context, 'Błąd tworzenia projektu', 'Wystąpił błąd: ${e.toString()}');
          }
          debugPrint('Błąd podczas tworzenia projektu lub licencji: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      } else {
        if (mounted) {
          await showErrorDialog(context, 'Błąd użytkownika', 'Brak identyfikatora użytkownika. Nie można utworzyć projektu.');
        }
      }

      if (mounted) {
        setState(() {
          _isCreating = false; // Ukryj wskaźnik ładowania
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Anuluj",
          onPressed: () {
            if (!_isCreating) { // Zapobiegaj powrotowi podczas tworzenia
              context.pop();
            }
          },
        ),
        title: Text(
          'Utwórz nowy projekt',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isCreating)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: colorScheme.onPrimary,
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: "Zapisz projekt",
              onPressed: _createProject,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.7),
              theme.colorScheme.secondary.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500), // Ograniczenie szerokości karty
              child: Card(
                elevation: 8.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Aby karta nie rozciągała się niepotrzebnie
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Dane projektu', // Dodatkowy nagłówek w karcie
                          style: textTheme.headlineSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24.0),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nazwa projektu *',
                            hintText: 'Wpisz nazwę dla swojego projektu',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            prefixIcon: Icon(Icons.folder_outlined, color: colorScheme.primary),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nazwa projektu jest wymagana.';
                            }
                            if (value.trim().length < 3) {
                              return 'Nazwa musi mieć co najmniej 3 znaki.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20.0),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Opis projektu (opcjonalnie)',
                            hintText: 'Dodaj krótki opis projektu',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            prefixIcon: Icon(Icons.description_outlined, color: colorScheme.primary.withOpacity(0.7)),
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                        const SizedBox(height: 32.0),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Utwórz projekt'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            elevation: 4.0,
                          ),
                          onPressed: _isCreating ? null : _createProject, // Wyłącz przycisk podczas tworzenia
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
