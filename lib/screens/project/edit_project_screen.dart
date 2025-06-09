import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/license.dart'; // Upewnij się, że ścieżka jest poprawna
import '../../models/project.dart'; // Upewnij się, że ścieżka jest poprawna
import '../../services/project_service.dart'; // Upewnij się, że ścieżka jest poprawna
import '../../services/license_service.dart'; // Dodano import dla LicenseService
import '../../widgets/dialogs.dart'; // Upewnij się, że ścieżka jest poprawna


class EditProjectScreen extends StatefulWidget {
  final Project project;
  final License? license; // Zmieniono na nullable, na wypadek gdyby licencja mogła nie istnieć

  const EditProjectScreen({super.key, required this.project, this.license}); // Dodano super.key

  @override
  _EditProjectScreenState createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isUpdating = false;
  bool _isDeleting = false;

  // Instancje serwisów
  final ProjectService projectService = ProjectService();
  final LicenseService licenseService = LicenseService(); // Dodano instancję LicenseService

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.project.name; // Usunięto ?? '' bo nazwa projektu jest wymagana
    _descriptionController.text = widget.project.description;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateProject() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUpdating = true;
      });
      final projectName = _nameController.text.trim();
      final projectDescription = _descriptionController.text.trim();
      final projectId = widget.project.projectId;

      // Sprawdzenie, czy nazwa lub opis faktycznie się zmieniły
      if (projectName == widget.project.name && projectDescription == widget.project.description) {
        if (mounted) {
          // Użyj showAlertDialog lub odpowiednika, jeśli istnieje w dialogs.dart
          await showInfoDialog(context, 'Informacja', 'Nie wprowadzono żadnych zmian w danych projektu.');
          setState(() {
            _isUpdating = false;
          });
        }
        return;
      }


      if (projectId.isNotEmpty) {
        try {
          await projectService.updateProject(projectId, name: projectName, description: projectDescription);
          if (mounted) {
            await showSuccessDialog(context, 'Sukces!', 'Zapisano zmiany w projekcie "${projectName}".');
            context.pop(true); // Przekaż true, aby poprzedni ekran odświeżył dane
          }
        } catch (e, stackTrace) {
          if (mounted) {
            await showErrorDialog(context, 'Błąd aktualizacji', 'Wystąpił błąd podczas aktualizacji projektu: ${e.toString()}');
          }
          debugPrint('Błąd przy aktualizacji projektu: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      } else {
        if (mounted) {
          await showErrorDialog(context, 'Błąd danych', 'Brak identyfikatora projektu. Nie można zapisać zmian.');
        }
      }
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _deleteProject() async {
    final bool? confirmed = await showDeleteConfirmationDialog(
      context,
      'Potwierdź usunięcie projektu',
      'Czy na pewno chcesz usunąć projekt "${widget.project.name}"${widget.license != null ? " oraz powiązaną z nim licencję" : ""}? Tej operacji nie można cofnąć.',
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() {
        _isDeleting = true;
      });
      try {
        await projectService.deleteProject(widget.project.projectId);
        // Jeśli istnieje licencja powiązana z projektem, również ją usuń
        if (widget.license != null) {
          await licenseService.deleteLicense(widget.license!.licenseId);
        }
        if (mounted) {
          await showSuccessDialog(context, 'Sukces!', 'Projekt "${widget.project.name}" został usunięty.');
          context.go('/my-projects'); // Wróć do listy projektów i odśwież ją
        }
      } catch (e, stackTrace) {
        if (mounted) {
          await showErrorDialog(context, 'Błąd usuwania', 'Wystąpił błąd podczas usuwania projektu: ${e.toString()}');
        }
        debugPrint('Błąd przy usuwaniu projektu: $e');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        if (mounted) {
          setState(() {
            _isDeleting = false;
          });
        }
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
          tooltip: "Anuluj edycję",
          onPressed: () {
            if (!_isUpdating && !_isDeleting) {
              context.pop();
            }
          },
        ),
        title: Text(
          'Edytuj projekt',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isUpdating || _isDeleting)
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
          else ...[
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: "Zapisz zmiany",
              onPressed: _updateProject,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: "Usuń projekt",
              onPressed: _deleteProject,
            ),
            if (widget.license != null) // Pokaż tylko jeśli licencja istnieje
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: "Zarządzaj subskrypcją",
                onPressed: () {
                  if (widget.license != null) {
                    // Przekaż obiekt licencji do ekranu subskrypcji
                    context.push('/buySubscription', extra: widget.license);
                  } else {
                    // Można pokazać komunikat, jeśli z jakiegoś powodu licencja jest null
                    showErrorDialog(context, "Brak licencji", "Nie można zarządzać subskrypcją, ponieważ licencja nie została znaleziona.");
                  }
                },
              ),
          ],
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
              constraints: const BoxConstraints(maxWidth: 500),
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Edytuj dane projektu',
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
                            hintText: 'Wpisz nową nazwę projektu',
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
                            hintText: 'Zaktualizuj opis projektu',
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
                          icon: const Icon(Icons.save_alt_outlined),
                          label: const Text('Zapisz zmiany'),
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
                          onPressed: _isUpdating || _isDeleting ? null : _updateProject,
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