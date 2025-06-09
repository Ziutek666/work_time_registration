import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Założenie: importy są poprawne i pliki istnieją w projekcie.
import '../../models/license.dart';
import '../../models/project.dart';
// import 'package:qr_code_scanner/qr_code_scanner.dart'; // Jeśli jest potrzebny, odkomentuj

class ProjectMenuScreen extends StatefulWidget {
  final Project project;
  final License? license; // Zmieniono na nullable, aby było spójne z EditProjectScreen
  const ProjectMenuScreen({
    super.key, // Dodano super.key
    required this.project,
    this.license, // Licencja może być opcjonalna
  }) : super();

  @override
  _ProjectMenuScreenState createState() => _ProjectMenuScreenState();
}

class _ProjectMenuScreenState extends State<ProjectMenuScreen> {
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
          tooltip: "Wróć do listy projektów",
          onPressed: () {
            // Domyślnie wraca do poprzedniego ekranu, czyli listy projektów
            if (context.canPop()) {
              context.pop();
            } else {
              // Jeśli nie można wrócić (np. bezpośrednie wejście), idź do my-projects
              context.go('/my-projects');
            }
          },
        ),
        title: Text(
          widget.project.name, // Nazwa projektu jako tytuł
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
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
        child: _menuButtons(theme), // Przekazanie theme do metody budującej menu
      ),
    );
  }

  Widget _menuButtons(ThemeData theme) {
    // Używamy ListView dla lepszego przewijania i możliwości dodania wielu opcji
    return ListView(
      padding: const EdgeInsets.all(16.0), // Zwiększony padding dla całego ListView
      children: <Widget>[
        _buildMenuOption(
          theme: theme,
          icon: Icons.work_history_outlined,
          title: 'Zdarzenia czasu pracy',
          onTap: () => context.push('/work_types_screen', extra: {
            'project': widget.project,
            'license': widget.license,
          }),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          theme: theme,
          icon: Icons.info_outline, // Zmieniona ikona
          title: 'Informacje dla pracowników', // Zmieniona nazwa dla spójności
          onTap: () => context.push('/informations', extra: {
            'project': widget.project,
            'license': widget.license,
          }),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          theme: theme,
          icon: Icons.map_outlined, // Bardziej pasująca ikona
          title: 'Lokalizacje', // Zmieniona nazwa dla spójności
          onTap: () => context.push('/areas', extra: {
            'project': widget.project,
            'license': widget.license,
          }),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          theme: theme,
          icon: Icons.supervised_user_circle_sharp, // Bardziej pasująca ikona
          title: 'Pracownicy',
          onTap: () => context.push('/project_members', extra: {
            'project': widget.project,
            'license': widget.license,
          }),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          theme: theme,
          icon: Icons.history_edu_outlined, // Bardziej pasująca ikona
          title: 'Historia zdarzeń (Logi)', // Zmieniona nazwa dla spójności
          onTap: () => context.push('/adminLogs', extra: widget.project),
        ),
        if (widget.license != null) ...[ // Sekcja licencji tylko jeśli licencja istnieje
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              "Licencja i subskrypcja",
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildMenuOption(
            theme: theme,
            icon: Icons.payment_outlined,
            title: 'Zarządzaj subskrypcją',
            onTap: () {
              if (widget.license != null) {
                context.push('/buySubscription', extra: widget.license);
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildMenuOption({
    required ThemeData theme, // Przekazanie theme
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Card(
      elevation: 3.0, // Subtelniejszy cień
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)), // Delikatna ramka
      ),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary, size: 26), // Nieco mniejsza ikona
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500, // Standardowa grubość
            color: colorScheme.onSurface,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: colorScheme.primary.withOpacity(0.8)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0), // Dopasowany padding
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        tileColor: colorScheme.surface, // Kolor tła kafelka
        splashColor: colorScheme.primary.withOpacity(0.1), // Kolor efektu tapnięcia
      ),
    );
  }
}