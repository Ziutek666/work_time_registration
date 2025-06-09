import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/user_auth_service.dart'; // Upewnij się, że ten import jest poprawny
import '../../widgets/dialogs.dart'; // Upewnij się, że ten import jest poprawny

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _isLoadingResend = false;
  bool _isLoadingLogout = false;

  @override
  void initState() {
    super.initState();
    // Wyślij email weryfikacyjny przy pierwszym załadowaniu ekranu,
    // ale tylko jeśli kontekst jest dostępny (mounted).
    // Użycie addPostFrameCallback zapewnia, że build jest zakończony.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sendVerificationEmail(context, showSuccess: true);
      }
    });
  }

  Future<void> _sendVerificationEmail(BuildContext context, {bool showSuccess = false}) async {
    if (!mounted) return; // Sprawdź, czy widget jest nadal w drzewie
    setState(() {
      _isLoadingResend = true;
    });
    try {
      await userAuthService.sendEmailVerification();
      if (showSuccess && mounted) {
        final email = userAuthService.currentUser?.email;
        await showSuccessDialog(context,'Wysyłanie e-maila', '✅ E-mail weryfikacyjny został wysłany na adres ${email ?? "Twój adres e-mail"}.');
      } else if (mounted) {
        // Można dodać SnackBar dla ponownego wysłania, jeśli dialog nie jest pożądany za każdym razem
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ E-mail weryfikacyjny został wysłany ponownie.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, "Błąd wysyłania", '❌ Błąd wysyłania e-maila: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingResend = false;
        });
      }
    }
  }

  Future<void> _logoutAndGoToAuth() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLogout = true;
    });
    try {
      await userAuthService.signOut();
      if (mounted) {
        // Sprawdź, czy kontekst GoRoutera jest nadal prawidłowy
        if (GoRouter.of(context).routerDelegate.navigatorKey.currentContext != null) {
          context.go('/auth');
        }
      }
    } catch (e) {
      if (mounted) {
        await showErrorDialog(context, "Błąd wylogowania", '❌ Wystąpił błąd podczas wylogowywania: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        // Nie resetujemy _isLoadingLogout, bo następuje przekierowanie
        // Jeśli jednak przekierowanie by nie następowało, trzeba by zresetować
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      // AppBar może nie być potrzebny, jeśli nie ma opcji powrotu z tego ekranu
      // Jeśli jest, można go dodać podobnie jak w RegistrationScreen.
      // Dla tego przykładu zakładam brak AppBar, aby użytkownik skupił się na weryfikacji.
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.8),
              theme.colorScheme.secondary.withOpacity(0.6)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480), // Nieco szersza karta
              child: Card(
                elevation: 8.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(
                        Icons.mark_email_unread_outlined,
                        size: 80,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 24.0),
                      Text(
                        'Zweryfikuj swój adres e-mail',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        'Wysłaliśmy link weryfikacyjny na Twój adres e-mail: ${userAuthService.currentUser?.email ?? "adres e-mail"}. '
                            'Kliknij w link, aby aktywować swoje konto. Jeśli nie widzisz e-maila, sprawdź folder spam.',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5, // Lepsza czytelność dłuższego tekstu
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      _isLoadingResend
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton.icon(
                        icon: const Icon(Icons.send_outlined),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        onPressed: () => _sendVerificationEmail(context),
                        label: const Text('Wyślij e-mail ponownie'),
                      ),
                      const SizedBox(height: 16.0),
                      _isLoadingLogout
                          ? const Center(child: SizedBox(height: 48)) // Placeholder, żeby uniknąć skoku UI
                          : TextButton.icon(
                        icon: Icon(Icons.logout, color: colorScheme.error.withOpacity(0.8)),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          textStyle: textTheme.titleSmall,
                        ),
                        onPressed: _logoutAndGoToAuth,
                        label: const Text('Wyloguj się i wróć do logowania'),
                      ),
                      const SizedBox(height: 24.0),
                      Text(
                        "Pamiętaj: Po kliknięciu linku weryfikacyjnego w e-mailu, może być konieczne ponowne uruchomienie aplikacji lub odświeżenie, aby zmiany zostały uwzględnione.",
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
                      )
                    ],
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
