import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Założenie: importy są poprawne i pliki istnieją w projekcie.
import '../../exceptions/project_exception.dart';
import '../../models/license.dart';
import '../../models/project.dart';
import '../../services/license_service.dart';
import '../../services/project_service.dart';
import '../../services/user_service.dart';
import '../../widgets/dialogs.dart'; // Dla showSuccessDialog, showErrorDialog, showAlertDialog

class MyProjectsScreen extends StatefulWidget {
  const MyProjectsScreen({super.key});

  @override
  _MyProjectsScreenState createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends State<MyProjectsScreen> {
  List<Project> projects = [];
  Map<String, License> licenses = {};
  bool licenceInTestModeExist = false;
  bool dataLoaded = false;
  bool _isDeleting = false; // Flaga do śledzenia stanu usuwania

  final ProjectService projectService = ProjectService();
  final LicenseService licenseService = LicenseService(); // Używamy instancji serwisu
  final UserService userService = UserService();

  @override
  void initState() {
    super.initState();
    _getProjectsAndLicenses();
  }

  Future<void> _getProjectsAndLicenses() async {
    if (!mounted) return;
    setState(() {
      dataLoaded = false;
      licenceInTestModeExist = false;
      licenses.clear();
      projects.clear();
    });

    try {
      String? currentUserId = userService.uid;
      if (currentUserId == null || currentUserId.isEmpty) {
        if (mounted) {
          await showErrorDialog(context, 'Błąd użytkownika', 'Nie można zidentyfikować użytkownika.');
          setState(() => dataLoaded = true);
        }
        return;
      }

      projects = await projectService.getProjectsByOwner(currentUserId);

      for (var project in projects) {
        final license = await licenseService.getLicenseForProject(project.projectId);
        if (license != null) {
          if (mounted) {
            setState(() {
              licenses[project.projectId] = license;
              if (license.testMode) {
                licenceInTestModeExist = true;
              }
            });
          }
        }
      }
      if (mounted) {
        setState(() {
          dataLoaded = true;
        });
      }
    } on ProjectException catch (e) {
      if (mounted) {
        debugPrint('ProjectException podczas pobierania danych: ${e.message}');
        setState(() {
          dataLoaded = true;
          projects.clear(); // Pozwól UI wyświetlić "brak projektów"
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        await showErrorDialog(context, 'Błąd pobierania danych', 'Wystąpił błąd podczas pobierania projektów i licencji: ${e.toString()}');
        setState(() {
          dataLoaded = true;
        });
      }
      debugPrint('Nieobsłużony błąd przy pobieraniu projektów i licencji: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _deleteProject(BuildContext context, Project project) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          title: const Text('Potwierdź usunięcie'),
          content: Text('Czy na pewno chcesz usunąć projekt "${project.name}"${licenses[project.projectId] != null ? " oraz powiązaną z nim licencję" : ""}? Tej operacji nie można cofnąć.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Anuluj'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              child: const Text('Usuń'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() {
        _isDeleting = true; // Pokaż wskaźnik ładowania na pełnym ekranie
      });

      try {
        // Usuń projekt
        await projectService.deleteProject(project.projectId);

        // Sprawdź i usuń licencję, jeśli istnieje
        final license = licenses[project.projectId];
        if (license != null) {
          await licenseService.deleteLicense(license.licenseId);
        }

        if (mounted) {
          await showSuccessDialog(context,'Usuwanie projektu', 'Projekt "${project.name}" został pomyślnie usunięty.');
          // Odśwież listę projektów po usunięciu
          await _getProjectsAndLicenses();
        }
      } catch (e) {
        if (mounted) {
          await showErrorDialog(context, 'Błąd usuwania', 'Nie udało się usunąć projektu: ${e.toString()}');
        }
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
        leading: context.canPop()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Wróć",
          onPressed: () => context.pop(),
        )
            : null,
        title: Text(
          'Moje projekty',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "Utwórz nowy projekt",
            onPressed: () async {
              await _createNewProject(context);
            },
          ),
        ],
      ),
      body: Stack( // Używamy Stack, aby móc wyświetlić wskaźnik ładowania na całym ekranie
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.7), // Lżejszy gradient
                  theme.colorScheme.secondary.withOpacity(0.5)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: dataLoaded
                ? _projectsList(theme)
                : _loadingIndicator(theme),
          ),
          if (_isDeleting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Usuwanie projektu..."),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _loadingIndicator(ThemeData theme) {
    return Center(
      child: Card(
        elevation: 8, // Większy cień dla wyróżnienia
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                "Ładowanie danych...",
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _projectsList(ThemeData theme) {
    if (projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_off_outlined, size: 64, color: theme.colorScheme.primary.withOpacity(0.8)),
                  const SizedBox(height: 20),
                  Text(
                    'Nie posiadasz jeszcze żadnych projektów.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kliknij ikonę "+" w prawym górnym rogu, aby dodać nowy.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return RefreshIndicator( // Dodano RefreshIndicator
        onRefresh: _getProjectsAndLicenses,
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surface,
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            final license = licenses[project.projectId];
            return _buildProjectItem(context, project, license, theme);
          },
        ),
      );
    }
  }

  Widget _buildProjectItem(BuildContext context, Project project, License? license, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Card(
      elevation: 5.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.25)),
      ),
      child: InkWell(
        onTap: () async {
          await _showProjectMenu(context, project);
        },
        borderRadius: BorderRadius.circular(16.0),
        splashColor: colorScheme.primary.withOpacity(0.1),
        highlightColor: colorScheme.primary.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0), // Lekkie obniżenie ikony
                    child: Icon(Icons.folder_special_outlined, color: colorScheme.primary, size: 38),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (project.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              project.description,
                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _getLicenseStatusWidget(license, theme),
              const Divider(height: 24.0, thickness: 0.8, indent: 8, endIndent: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.edit_outlined, color: colorScheme.secondary, size: 20),
                    label: Text('Edytuj', style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await _editProject(context, project);
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
                    label: Text('Usuń', style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await _deleteProject(context, project);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _showProjectMenu(BuildContext context, Project project) async {
    if (!mounted) return;
    // Przekazujemy dodatkowe dane do nowej trasy
    await context.push('/project-menu', extra: {
      'project': project,
      'license': licenses[project.projectId],
    });
  }

  Future<void> _editProject(BuildContext context, Project project) async {
    if (!mounted) return;
    final result = await context.push('/edit-project', extra: {
      'project': project,
      'license': licenses[project.projectId],
    }) as bool?; // Oczekujemy bool? jako wynik
    if (result == true && mounted) { // Sprawdzamy czy wynik to true
      await _getProjectsAndLicenses(); // Odśwież listę
    }
  }

  Future<void> _createNewProject(BuildContext context) async {
    if (licenceInTestModeExist) {
      if (mounted) {
        // Użycie showAlertDialog z dialogs.dart dla spójności
        await showAlertDialog(
          context,
          'Ograniczenie tworzenia projektu',
          'Można mieć tylko jeden projekt z licencją w wersji testowej.',
        );
      }
      return;
    }
    if (!mounted) return;
    final result = await context.push('/create-project') as bool?;
    if (result == true && mounted) {
      await _getProjectsAndLicenses();
    }
  }

  String formatDate(Timestamp timestamp) {
    return DateFormat('dd.MM.yyyy', 'pl_PL').format(timestamp.toDate()); // Dodano lokalizację dla formatu
  }

  Widget _getLicenseStatusWidget(License? license, ThemeData theme) {
    final TextTheme textTheme = theme.textTheme;
    // Używamy bodySmall dla statusu licencji, aby był mniej dominujący
    TextStyle? statusStyle = textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500);

    if (license == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 16),
          const SizedBox(width: 6),
          Text('Brak licencji!', style: statusStyle?.copyWith(color: theme.colorScheme.error)),
        ],
      );
    }

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (license.testMode) {
      if (!license.isValid) {
        statusColor = Colors.orange.shade800;
        statusIcon = Icons.warning_amber_rounded;
        statusText = 'Licencja testowa wygasła: ${formatDate(license.validityTime)}';
      } else {
        statusColor = Colors.green.shade700;
        statusIcon = Icons.timelapse_rounded;
        statusText = 'Licencja testowa do: ${formatDate(license.validityTime)}';
      }
    } else {
      if (!license.isValid) {
        statusColor = theme.colorScheme.error;
        statusIcon = Icons.cancel_outlined;
        statusText = 'Licencja wygasła: ${formatDate(license.validityTime)}';
      } else {
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle_outline_rounded;
        statusText = 'Aktywna licencja do: ${formatDate(license.validityTime)}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), // Zwiększony padding
      decoration: BoxDecoration(
          color: statusColor.withOpacity(0.12), // Nieco intensywniejsze tło
          borderRadius: BorderRadius.circular(8.0), // Bardziej zaokrąglone rogi dla tagu
          border: Border.all(color: statusColor.withOpacity(0.3), width: 0.8) // Subtelna ramka
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Aby kontener nie rozciągał się na całą szerokość
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(statusText, style: statusStyle?.copyWith(color: statusColor), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
