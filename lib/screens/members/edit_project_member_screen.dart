import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; // Do formatowania daty
import 'package:work_time_registration/models/app_data.dart';
import '../../../widgets/dialogs.dart';
import '../../models/area.dart';
import '../../models/project.dart';
import '../../models/project_member.dart';
import '../../models/user_app.dart';
import '../../services/area_service.dart';
import '../../services/project_member_service.dart';
import '../../services/user_service.dart';

class EditProjectMemberScreen extends StatefulWidget {
  final Project project;
  final ProjectMember projectMember;

  const EditProjectMemberScreen({
    super.key,
    required this.project,
    required this.projectMember,
  });

  @override
  State<EditProjectMemberScreen> createState() => _EditProjectMemberScreenState();
}

class _EditProjectMemberScreenState extends State<EditProjectMemberScreen> {
  final _formKey = GlobalKey<FormState>();

  UserApp? _memberUserApp;
  late Set<String> _selectedRoles;
  late List<String> _selectedAreaIds;
  bool _isLoadingUserDetails = true;
  bool _isLoadingAreas = false;
  bool _isProcessing = false;

  List<Area> _availableAreas = [];
  bool _expandAreasSection = false;

  // Założenie: userService i areaService są dostępne globalnie lub przez DI
  final UserService userService = UserService();
  final AreaService areaService = AreaService();


  @override
  void initState() {
    super.initState();
    _selectedRoles = Set<String>.from(widget.projectMember.roles);
    _selectedAreaIds = List<String>.from(widget.projectMember.areaIds);
    _loadUserDetails();
    _loadAvailableAreas();
  }

  Future<void> _loadUserDetails() async {
    if (!mounted) return;
    setState(() => _isLoadingUserDetails = true);
    try {
      _memberUserApp = await userService.getUserData(widget.projectMember.userId);
    } catch (e) {
      debugPrint("Błąd ładowania danych użytkownika: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Nie udało się załadować danych użytkownika: ${e.toString()}"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingUserDetails = false);
      }
    }
  }

  Future<void> _loadAvailableAreas() async {
    if (!mounted) return;
    setState(() => _isLoadingAreas = true);
    try {
      _availableAreas = await areaService.getAreasByProject(widget.project.projectId);
    } catch (e) {
      debugPrint("Błąd ładowania dostępnych obszarów: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Nie udało się załadować listy obszarów: ${e.toString()}"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAreas = false);
      }
    }
  }


  void _toggleRole(String role) {
    if (mounted) {
      setState(() {
        if (_selectedRoles.contains(role)) {
          _selectedRoles.remove(role);
        } else {
          _selectedRoles.add(role);
        }
      });
    }
  }

  void _toggleAreaId(String areaId) {
    if (mounted) {
      setState(() {
        if (_selectedAreaIds.contains(areaId)) {
          _selectedAreaIds.remove(areaId);
        } else {
          _selectedAreaIds.add(areaId);
        }
      });
    }
  }

  Future<void> _updateMemberRolesAndAreas() async {
    if (_isProcessing) return;

    final originalRoles = Set<String>.from(widget.projectMember.roles);
    final originalAreaIds = Set<String>.from(widget.projectMember.areaIds);

    bool rolesChanged = !(originalRoles.length == _selectedRoles.length && originalRoles.containsAll(_selectedRoles));
    bool areasChanged = !(originalAreaIds.length == _selectedAreaIds.length && originalAreaIds.containsAll(_selectedAreaIds));


    if (!rolesChanged && !areasChanged) {
      await showInfoDialog(context, 'Informacja', 'Nie wprowadzono żadnych zmian w rolach ani dostępach do obszarów.');
      return;
    }
    if (_selectedRoles.isEmpty) {
      await showErrorDialog(context, 'Brak ról', 'Użytkownik musi mieć przypisaną przynajmniej jedną rolę.');
      return;
    }

    setState(() { _isProcessing = true; });

    try {
      await projectMemberService.updateProjectMemberDetails(
        projectId: widget.project.projectId,
        userId: widget.projectMember.userId,
        newRoles: rolesChanged ? _selectedRoles.toList() : null, // Przekaż null, jeśli role się nie zmieniły
        newAreaIds: areasChanged ? _selectedAreaIds : null,   // Przekaż null, jeśli obszary się nie zmieniły
      );

      if (mounted) {
        await showSuccessDialog(
          context,
          'Zaktualizowano Członka!',
          'Dane członka ${_memberUserApp?.displayName ?? widget.projectMember.userId} zostały zaktualizowane.',
        );
        context.pop(true);
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd podczas aktualizacji danych członka projektu: $e\n$stackTrace');
      if (mounted) {
        await showErrorDialog(context, 'Błąd Zapisu', 'Wystąpił błąd: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() { _isProcessing = false; });
      }
    }
  }

  Future<void> _removeMemberFromProject() async {
    if (_isProcessing) return;

    final bool? confirmed = await showDeleteConfirmationDialog(
      context,
      'Potwierdź Usunięcie Członka',
      'Czy na pewno chcesz usunąć użytkownika ${_memberUserApp?.displayName ?? widget.projectMember.userId} z projektu "${widget.project.name}"? Tej operacji nie można cofnąć.',
    );

    if (confirmed == true) {
      setState(() { _isProcessing = true; });
      try {
        await projectMemberService.removeProjectMember(
          widget.project.projectId,
          widget.projectMember.userId,
        );
        if (mounted) {
          await showSuccessDialog(
            context,
            'Usunięto Członka!',
            'Użytkownik ${_memberUserApp?.displayName ?? widget.projectMember.userId} został usunięty z projektu.',
          );
          context.pop(true);
        }
      } catch (e, stackTrace) {
        debugPrint('Błąd podczas usuwania członka z projektu: $e\n$stackTrace');
        if (mounted) {
          await showErrorDialog(context, 'Błąd Usuwania', 'Wystąpił błąd: ${e.toString()}');
        }
      } finally {
        if (mounted) {
          setState(() { _isProcessing = false; });
        }
      }
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(timestamp.toDate());
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
          onPressed: _isProcessing ? null : () => context.pop(false),
        ),
        title: Text(
          'Edytuj Członka Projektu',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Zapisz Zmiany',
              onPressed: _updateMemberRolesAndAreas,
            ),
            IconButton(
              icon: Icon(Icons.person_remove_outlined, color: colorScheme.onErrorContainer),
              tooltip: 'Usuń Członka z Projektu',
              onPressed: _removeMemberFromProject,
            ),
          ]
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
        child: AbsorbPointer(
          absorbing: _isProcessing,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  elevation: 8.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Edycja Członka w Projekcie:',
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            widget.project.name,
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24.0),
                          _buildSectionTitle(textTheme, "Informacje o Użytkowniku"),
                          _isLoadingUserDetails
                              ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                              : _memberUserApp != null
                              ? _buildUserInfoCard(theme, _memberUserApp!)
                              : Card(
                            elevation: 0,
                            color: theme.colorScheme.errorContainer.withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                "Nie udało się załadować danych użytkownika. Spróbuj ponownie później.",
                                style: textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12.0),
                          Text(
                            'Data dołączenia: ${_formatTimestamp(widget.projectMember.dateAdded)}',
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 24.0),
                          _buildSectionTitle(textTheme, "Przypisane Role"),
                          _buildRolesSelection(theme),

                          const SizedBox(height: 24.0),
                          _buildSectionTitle(textTheme, "Dostęp do Obszarów"),
                          _buildAreasSelection(theme),

                          const SizedBox(height: 32.0),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save_alt_outlined),
                            label: const Text('Zapisz Zmiany'),
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
                            onPressed: (_isProcessing || _selectedRoles.isEmpty) ? null : _updateMemberRolesAndAreas,
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
      ),
    );
  }

  Widget _buildSectionTitle(TextTheme textTheme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(ThemeData theme, UserApp user) {
    return Card(
      elevation: 1,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          child: user.photoURL != null && user.photoURL!.isNotEmpty
              ? ClipOval(child: Image.network(user.photoURL!, fit: BoxFit.cover, width: 38, height: 38,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 22),
          ))
              : Text(user.displayName?.isNotEmpty == true ? user.displayName![0].toUpperCase() : (user.email?[0].toUpperCase() ?? "U"), style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary)),
          radius: 22,
        ),
        title: Text(user.displayName ?? 'Brak nazwy', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(user.email ?? 'Brak emaila', style: theme.textTheme.bodySmall),
      ),
    );
  }

  Widget _buildRolesSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Wybierz role dla tego użytkownika w projekcie:",
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: AppData().availableProjectRoles.map((role) {
            final isSelected = _selectedRoles.contains(role);
            return ChoiceChip(
              label: Text(role),
              selected: isSelected,
              onSelected: _isProcessing ? null : (selected) {
                _toggleRole(role);
              },
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              avatar: isSelected ? Icon(Icons.check_circle_outline, color: theme.colorScheme.primary, size: 18) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
                side: BorderSide(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.5),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAreasSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(theme.textTheme, "Dostęp do Obszarów"),
            IconButton(
              icon: Icon(_expandAreasSection ? Icons.keyboard_arrow_up_outlined : Icons.keyboard_arrow_down_outlined),
              tooltip: _expandAreasSection ? 'Zwiń listę obszarów' : 'Rozwiń listę obszarów',
              color: theme.colorScheme.primary,
              onPressed: () => setState(() => _expandAreasSection = !_expandAreasSection),
            ),
          ],
        ),
        if (_expandAreasSection) ...[
          const SizedBox(height: 8.0),
          Text(
            'Zaznacz obszary, do których użytkownik będzie miał dostęp lub specjalne uprawnienia.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12.0),
          if (_isLoadingAreas)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
          else if (_availableAreas.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Center(child: Text('Brak zdefiniowanych obszarów w tym projekcie.', style: theme.textTheme.bodyMedium)),
            )
          else
            Wrap(
              spacing: 8.0,
              runSpacing: 0.0,
              children: _availableAreas.map((area) {
                final isSelected = _selectedAreaIds.contains(area.areaId);
                return SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: CheckboxListTile(
                    title: Text(area.name, style: theme.textTheme.titleSmall),
                    value: isSelected,
                    onChanged: _isProcessing ? null : (bool? value) {
                      if (value != null) {
                        _toggleAreaId(area.areaId);
                      }
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: theme.colorScheme.tertiary,
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8.0),
        ],
      ],
    );
  }
}