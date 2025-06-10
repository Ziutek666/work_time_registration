import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdministrationMenuScreen extends StatefulWidget {
  // Ten ekran nie wymaga przekazywania danych w konstruktorze,
  // ale zachowujemy standardowy wzorzec.
  const AdministrationMenuScreen({super.key});

  @override
  State<AdministrationMenuScreen> createState() => _AdministrationMenuScreenState();
}

class _AdministrationMenuScreenState extends State<AdministrationMenuScreen> {
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
        // Zakładając, że ten ekran jest częścią większej nawigacji,
        // dodajemy przycisk powrotu.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Wróć",
          onPressed: () {
            // Logika powrotu, np. do ekranu głównego
            if (context.canPop()) {
              context.pop();
            } else {
              // Jeśli nie można wrócić, przejdź do zdefiniowanej ścieżki (np. home)
              context.go('/');
            }
          },
        ),
        title: Text(
          "Panel Administracyjny", // Tytuł ekranu
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        // Utrzymanie spójnego tła z gradientem
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
        child: _menuButtons(theme), // Budowanie menu
      ),
    );
  }

  Widget _menuButtons(ThemeData theme) {
    // ListView zapewnia elastyczność i możliwość przewijania
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        _buildMenuOption(
          theme: theme,
          icon: Icons.business_center_outlined, // Ikona dla projektów
          title: 'Moje projekty',
          // Nawigacja do ekranu z listą projektów
          onTap: () => context.go('/my-projects'),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          theme: theme,
          icon: Icons.history_outlined, // Ikona dla historii
          title: 'Historia',
          // Docelowa ścieżka dla historii, np. logi ogólne
          onTap: () => context.go('/admin-history-menu'),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          theme: theme,
          icon: Icons.supervised_user_circle_outlined, // Ikona dla pracowników
          title: 'Pracownicy',
          // Docelowa ścieżka dla zarządzania pracownikami
          onTap: () => context.go('/employees-management'),
        ),
      ],
    );
  }

  // Ta metoda jest w pełni reużywalna i skopiowana z Twojego przykładu,
  // aby zapewnić jednolity wygląd i działanie przycisków w całej aplikacji.
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
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: colorScheme.primary.withOpacity(0.8)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        tileColor: colorScheme.surface,
        splashColor: colorScheme.primary.withOpacity(0.1),
      ),
    );
  }
}