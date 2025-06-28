import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/license.dart';
import '../../services/license_service.dart';
import '../../services/user_service.dart';

class AdministrationMenuScreen extends StatefulWidget {
  const AdministrationMenuScreen({super.key});

  @override
  State<AdministrationMenuScreen> createState() => _AdministrationMenuScreenState();
}

class _AdministrationMenuScreenState extends State<AdministrationMenuScreen> {
  License? _license;
  bool _isLoadingLicense = true;
  String? _licenseError;

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  Future<void> _loadLicense() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLicense = true;
      _licenseError = null;
    });

    try {
      final ownerId = await userService.uid;
      if (ownerId == null) {
        throw Exception('Nie można zidentyfikować właściciela.');
      }

      _license = await licenseService.getLicenseForOwner(ownerId);

    } catch (e) {
      if (mounted) {
        _licenseError = 'Błąd ładowania licencji: ${e.toString()}';
        debugPrint(_licenseError);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLicense = false;
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
          tooltip: "Wróć",
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          "Panel Administracyjny",
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
              theme.colorScheme.primary.withOpacity(0.7),
              theme.colorScheme.secondary.withOpacity(0.5),
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
          icon: Icons.business_center_outlined,
          title: 'Moje projekty',
          onTap: () => context.go('/my-projects'),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          theme: theme,
          icon: Icons.history_outlined,
          title: 'Historia',
          onTap: () => context.go('/admin-history-menu'),
        ),
        const SizedBox(height: 12),
        _buildMenuOption(
          theme: theme,
          icon: Icons.supervised_user_circle_outlined,
          title: 'Pracownicy',
          onTap: () => context.go('/members-screen'),
        ),
        _buildLicenseSection(theme),
      ],
    );
  }

  Widget _buildLicenseSection(ThemeData theme) {
    if (_isLoadingLicense) {
      return const Padding(
        padding: EdgeInsets.only(top: 24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_license == null) {
      // Jeśli nie ma licencji (lub wystąpił błąd), nie pokazuj tej sekcji
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            "Licencja i subskrypcja",
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white.withOpacity(0.8), // Lepszy kontrast na gradiencie
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
            context.push('/buySubscription', extra: _license);
          },
        ),
      ],
    );
  }

  // POPRAWKA: Pełna implementacja funkcji budującej przycisk menu
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
        splashColor: colorScheme.primary.withOpacity(0.1),
      ),
    );
  }
}