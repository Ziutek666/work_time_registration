import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Dla Timestamp
import 'package:work_time_registration/models/app_data.dart';
import '../../../widgets/dialogs.dart';
import '../../models/area.dart';
import '../../models/project.dart';
import '../../models/user_app.dart';
import '../../services/area_service.dart';
import '../../services/project_member_service.dart';
import '../../services/user_service.dart';

class AddProjectMemberScreen extends StatefulWidget {
  final Project project;

  const AddProjectMemberScreen({
    super.key,
    required this.project,
  });

  @override
  State<AddProjectMemberScreen> createState() => _AddProjectMemberScreenState();
}

class _AddProjectMemberScreenState extends State<AddProjectMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  UserApp? _searchedUser;
  bool _isSearchingUser = false;
  String? _searchError;

  final Set<String> _selectedRoles = {};
  // NOWE ZMIENNE STANU DLA OBSZARÓW
  List<String> _selectedAreaIds = [];
  List<Area> _availableAreas = [];
  bool _isLoadingAreas = false;
  bool _expandAreasSection = false;


  bool _isSaving = false;


  @override
  void initState() {
    super.initState();
    _loadAvailableAreas(); // Załaduj dostępne obszary przy inicjalizacji
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // NOWA METODA DO ŁADOWANIA DOSTĘPNYCH OBSZARÓW
  Future<void> _loadAvailableAreas() async {
    if (!mounted) return;
    setState(() => _isLoadingAreas = true);
    try {
      // Założenie: masz AreaService i metodę getAreasByProject
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


  Future<void> _findUserByEmail() async {
    if (_emailController.text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchError = "Proszę wprowadzić adres email.";
          _searchedUser = null;
        });
      }
      return;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      if (mounted) {
        setState(() {
          _searchError = "Niepoprawny format adresu email.";
          _searchedUser = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearchingUser = true;
        _searchedUser = null;
        _searchError = null;
      });
    }
    try {
      final user = await userService.getUserByExactEmail(_emailController.text.trim());

      if (mounted) {
        if (user != null) {
          final currentMembers = await projectMemberService.getMembersByProjectId(widget.project.projectId);
          final isAlreadyMember = currentMembers.any((pm) => pm.userId == user.uid);

          if (isAlreadyMember) {
            setState(() {
              _searchError = "Ten użytkownik jest już członkiem projektu.";
              _searchedUser = null;
            });
          } else {
            setState(() {
              _searchedUser = user;
            });
          }
        } else {
          setState(() {
            _searchError = "Nie znaleziono użytkownika o podanym adresie email.";
            _searchedUser = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Błąd wyszukiwania użytkownika po emailu: $e');
      if (mounted) {
        setState(() {
          _searchError = "Wystąpił błąd podczas wyszukiwania: ${e.toString()}";
          _searchedUser = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingUser = false;
        });
      }
    }
  }

  void _clearSearchedUser() {
    if (mounted) {
      setState(() {
        _searchedUser = null;
        _emailController.clear();
        _searchError = null;
      });
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

  // NOWA METODA DO PRZEŁĄCZANIA WYBRANYCH OBSZARÓW
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


  Future<void> _addMemberToProject() async {
    if (_isSaving) return;
    if (_searchedUser == null) {
      await showErrorDialog(context, 'Brak użytkownika', 'Proszę najpierw znaleźć i wybrać użytkownika.');
      return;
    }
    if (_selectedRoles.isEmpty) {
      await showErrorDialog(context, 'Brak ról', 'Proszę wybrać przynajmniej jedną rolę dla użytkownika.');
      return;
    }

    setState(() { _isSaving = true; });

    try {
      await projectMemberService.addProjectMember(
        projectId: widget.project.projectId,
        userId: _searchedUser!.uid!,
        roles: _selectedRoles.toList(),
        areaIds: _selectedAreaIds, // <<<--- PRZEKAZANIE WYBRANYCH ID OBSZARÓW
        dateAdded: Timestamp.now(),
      );

      if (mounted) {
        await showSuccessDialog(
          context,
          'Dodano członka!',
          'Użytkownik ${_searchedUser!.displayName ?? _searchedUser!.email ?? _searchedUser!.uid} został dodany do projektu "${widget.project.name}" z rolami: ${_selectedRoles.join(', ')}.',
        );
        context.pop(true);
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd podczas dodawania członka do projektu: $e\n$stackTrace');
      if (mounted) {
        await showErrorDialog(context, 'Błąd zapisu', 'Wystąpił błąd: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
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
          onPressed: _isSaving ? null : () => context.pop(false),
        ),
        title: Text(
          'Dodaj Członka do Projektu',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isSaving)
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
          else
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Dodaj Członka',
              onPressed: _addMemberToProject,
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
        child: AbsorbPointer(
          absorbing: _isSaving,
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
                            'Dodawanie Członka do: ${widget.project.name}',
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24.0),
                          _buildSectionTitle(textTheme, "Wyszukaj Użytkownika po Emailu"),
                          _buildUserEmailSearchField(theme),
                          if (_isSearchingUser)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_searchError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                              child: Text(_searchError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                            )
                          else if (_searchedUser != null)
                              _buildSelectedUserInfo(theme, _searchedUser!),

                          const SizedBox(height: 24.0),
                          _buildSectionTitle(textTheme, "Przypisz Role"),
                          _buildRolesSelection(theme),

                          const SizedBox(height: 24.0), // Odstęp przed nową sekcją
                          _buildSectionTitle(textTheme, "Dostęp do Obszarów (Opcjonalnie)"),
                          _buildAreasSelection(theme), // <<<--- NOWA SEKCJA

                          const SizedBox(height: 32.0),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('Dodaj Członka do Projektu'),
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
                            onPressed: (_isSaving || _searchedUser == null || _selectedRoles.isEmpty) ? null : _addMemberToProject,
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

  Widget _buildUserEmailSearchField(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: "Adres email użytkownika",
              hintText: "Wprowadź pełny adres email",
              prefixIcon: Icon(Icons.email_outlined, color: theme.colorScheme.primary.withOpacity(0.7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Proszę wprowadzić adres email.';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Niepoprawny format adresu email.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _findUserByEmail(),
            enabled: !_isSaving && _searchedUser == null,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text("Znajdź"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          onPressed: (_isSaving || _searchedUser != null) ? null : _findUserByEmail,
        ),
      ],
    );
  }

  Widget _buildSelectedUserInfo(ThemeData theme, UserApp user) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      child: Card(
        elevation: 2,
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: theme.colorScheme.primary, width: 1),
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
          trailing: IconButton(
            icon: Icon(Icons.highlight_remove_outlined, color: theme.colorScheme.error),
            tooltip: "Anuluj wybór użytkownika",
            onPressed: _clearSearchedUser,
          ),
        ),
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
            "Wybierz role dla użytkownika w tym projekcie:",
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        if (_searchedUser == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Najpierw znajdź i wybierz użytkownika, aby przypisać role.",
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.outline),
            ),
          )
        else
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: AppData().availableProjectRoles.map((role) {
              final isSelected = _selectedRoles.contains(role);
              return ChoiceChip(
                label: Text(role),
                selected: isSelected,
                onSelected: _isSaving ? null : (selected) {
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

  // NOWY WIDGET DO WYBORU OBSZARÓW
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
            Wrap( // Używamy Wrap dla lepszego układu checkboxów, jeśli jest ich wiele
              spacing: 8.0,
              runSpacing: 0.0,
              children: _availableAreas.map((area) {
                final isSelected = _selectedAreaIds.contains(area.areaId);
                return SizedBox( // Ograniczenie szerokości dla CheckboxListTile w Wrap
                  width: MediaQuery.of(context).size.width * 0.4, // Przykładowa szerokość
                  child: CheckboxListTile(
                    title: Text(area.name, style: theme.textTheme.titleSmall?.copyWith(overflow: TextOverflow.ellipsis)),
                    value: isSelected,
                    onChanged: _isSaving || _searchedUser == null ? null : (bool? value) {
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