import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; // Do formatowania daty
import '../../../widgets/dialogs.dart';
import '../../models/license.dart';
import '../../models/project.dart';
import '../../models/project_member.dart';
import '../../models/user_app.dart';
import '../../services/project_member_service.dart';
import '../../services/user_service.dart'; // Dla showErrorDialog itp.

class ProjectMembersScreen extends StatefulWidget {
  final Project project;
  final License? license; // Można dodać, jeśli potrzebne dla logiki limitów itp.

  const ProjectMembersScreen({
    super.key,
    required this.project,
    this.license,
  });

  @override
  State<ProjectMembersScreen> createState() => _ProjectMembersScreenState();
}

class _ProjectMembersScreenState extends State<ProjectMembersScreen> {
  List<ProjectMember> _projectMembers = [];
  Map<String, UserApp> _memberDetails = {}; // Mapa userId -> UserApp
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false; // Ogólna flaga dla operacji (ładowanie, dodawanie)

  // Założenie: serwisy są dostępne globalnie lub przez DI
  // final ProjectMemberService projectMemberService = ProjectMemberService();
  // final UserService userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadProjectMembers();
  }

  Future<void> _loadProjectMembers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isProcessing = true;
      _memberDetails.clear(); // Wyczyść szczegóły użytkowników przy odświeżaniu
    });

    try {
      _projectMembers = await projectMemberService.getMembersByProjectId(widget.project.projectId);

      if (mounted && _projectMembers.isNotEmpty) {
        // Pobierz szczegóły użytkowników dla każdego członka
        final userIds = _projectMembers.map((member) => member.userId).toSet().toList();
        if (userIds.isNotEmpty) {
          final users = await userService.getUsersByIds(userIds);
          for (var user in users) {
            _memberDetails[user.uid??''] = user;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Błąd przy pobieraniu członków projektu: $e\n$stackTrace');
      if (mounted) {
        final errorMessageText = 'Nie udało się załadować członków projektu: ${e.toString()}';
        setState(() {
          _isLoading = false;
          _errorMessage = errorMessageText;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _navigateToAddMember() async {
    // Nawigacja do ekranu dodawania członka do projektu.
    // Ten ekran powinien pozwolić wybrać użytkownika i przypisać mu role.
    // Przekazujemy projectId, aby wiedzieć, do którego projektu dodajemy.
    // Przykład trasy: '/projects/${widget.project.projectId}/add-member'
    // lub specjalny ekran wyboru użytkownika.
    // Po pomyślnym dodaniu, ekran powinien zwrócić true.
    final result = await context.push<bool>(
      '/add_project_member_to_project', // Zdefiniuj tę trasę
      extra: widget.project, // Przekazujemy cały projekt, może się przydać
    );

    if (result == true && mounted) {
      _loadProjectMembers(); // Odśwież listę
    }
  }

  Future<void> _navigateToEditMember(ProjectMember member) async {
    // Nawigacja do ekranu edycji członkostwa (np. zmiana ról).
    // Przekazujemy obiekt ProjectMember lub jego ID (membershipId).
    // Przykład trasy: '/edit_project_member/${member.id}'
    final result = await context.push<bool>(
      '/edit_project_member', // Zdefiniuj tę trasę
      extra: {'projectMember': member, 'project': widget.project}, // Przekazujemy członkostwo i projekt
    );

    if (result == true && mounted) {
      _loadProjectMembers(); // Odśwież listę
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
          tooltip: "Wróć do menu projektu",
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Text(
          'Członkowie: ${widget.project.name}',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isLoading && _isProcessing)
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
              icon: const Icon(Icons.refresh),
              tooltip: 'Odśwież listę',
              onPressed: _isProcessing ? null : _loadProjectMembers,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : _navigateToAddMember,
        tooltip: 'Dodaj nowego członka',
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Dodaj członka'),
        backgroundColor: colorScheme.tertiary,
        foregroundColor: colorScheme.onTertiary,
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
        child: _buildBodyContent(theme),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading && _isProcessing) { // Stan początkowego ładowania
      return Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text("Ładowanie członków projektu...", style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error, size: 50),
                const SizedBox(height: 16),
                Text(
                  'Wystąpił błąd',
                  style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Spróbuj ponownie'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary),
                  onPressed: _loadProjectMembers,
                )
              ],
            ),
          ),
        ),
      );
    }

    if (_projectMembers.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 60, color: theme.colorScheme.primary.withOpacity(0.7)),
                const SizedBox(height: 20),
                Text(
                  'Brak członków w projekcie',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Naciśnij przycisk "+" aby dodać nowego członka do tego projektu.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProjectMembers,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _projectMembers.length,
        itemBuilder: (context, index) {
          final member = _projectMembers[index];
          final userDetail = _memberDetails[member.userId];
          return _buildProjectMemberItem(member, userDetail, theme);
        },
      ),
    );
  }

  Widget _buildProjectMemberItem(ProjectMember member, UserApp? userDetail, ThemeData theme) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    String displayName = userDetail?.displayName ?? 'Użytkownik (${member.userId.substring(0, 6)}...)';
    String email = userDetail?.email ?? 'Brak adresu email';
    String rolesString = member.roles.isNotEmpty ? member.roles.map((r) => r.toUpperCase()).join(', ') : 'Brak ról';

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: _isProcessing ? null : () => _navigateToEditMember(member),
        borderRadius: BorderRadius.circular(12.0),
        splashColor: colorScheme.primary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: userDetail?.photoURL != null && userDetail!.photoURL!.isNotEmpty
                    ? ClipOval(child: Image.network(userDetail.photoURL!, fit: BoxFit.cover, width: 40, height: 40,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.person_outline, size: 24),
                ))
                    : Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U', style: textTheme.titleMedium),
                radius: 22,
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      email,
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6.0),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 4.0,
                      children: member.roles.map((role) {
                        return Chip(
                          label: Text(role.toUpperCase(), style: textTheme.labelSmall?.copyWith(color: colorScheme.primary)),
                          backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      'Dołączył: ${_formatTimestamp(member.dateAdded)}',
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Icon(Icons.arrow_forward_ios_rounded, size: 18, color: colorScheme.primary.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }
}