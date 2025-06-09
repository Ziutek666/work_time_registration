import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminHistoryMenuScreen extends StatefulWidget {
  const AdminHistoryMenuScreen({super.key});

  @override
  State<AdminHistoryMenuScreen> createState() => _AdminHistoryMenuScreenState();
}

class _AdminHistoryMenuScreenState extends State<AdminHistoryMenuScreen> {
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
        // Przycisk powrotu - dostosuj nawigację, jeśli ten ekran jest częścią głębszego stosu
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Wróć",
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // Domyślnie wróć do ekranu głównego, jeśli nie ma dokąd wrócić
              context.go('/');
            }
          },
        ),
        title: Text(
          'Historia i Rejestry',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.6),
              // Użycie primaryContainer dla subtelniejszego tła
              theme.colorScheme.secondaryContainer.withOpacity(0.4),
              // Użycie secondaryContainer
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _menuButtons(theme),
      ),
    );
  }

  Widget _menuButtons(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        _buildMenuOption(
          theme: theme,
          icon: Icons.history_rounded, // Ikona dla historii czasu pracy
          title: 'Rejestr czasu pracy',
          onTap: () {
            // Upewnij się, że masz zdefiniowaną trasę '/user-work-history'
            // która prowadzi do UserWorkHistoryScreen
            context.push('/admin-work-history');
          },
        ),
        _buildMenuOption(
          theme: theme,
          icon: Icons.history_rounded, // Ikona dla historii czasu pracy
          title: 'Rejestr informacji',
          onTap: () {
            // Upewnij się, że masz zdefiniowaną trasę '/user-work-history'
            // która prowadzi do UserWorkHistoryScreen
            context.push('/admin-info-history');
          },
        ),
        // Możesz dodać więcej opcji w przyszłości
      ],
    );
  }

  Widget _buildMenuOption({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Card(
      elevation: 3.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary, size: 26),
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18,
            color: colorScheme.primary.withOpacity(0.8)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 14.0, horizontal: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        tileColor: colorScheme.surface,
        // Użycie koloru surface z motywu
        splashColor: colorScheme.primary.withOpacity(0.1),
      ),
    );
  }
}