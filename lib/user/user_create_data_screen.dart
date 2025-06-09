import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/dialogs.dart';
import '../services/user_service.dart'; // Upewnij się, że ten import jest poprawny

class UserCreateDataScreen extends StatefulWidget {
  const UserCreateDataScreen({super.key});

  @override
  State<UserCreateDataScreen> createState() => _UserCreateDataScreenState();
}

class _UserCreateDataScreenState extends State<UserCreateDataScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false; // Dodane do obsługi stanu ładowania przycisku

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveUserData(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Rozpocznij ładowanie
      });
      String name = _nameController.text.trim();
      try {
        // Nie używamy już dialogu ładowania, ponieważ przycisk będzie miał wskaźnik
        await userService.createNewUser(name);
        if (mounted) {
          // Sprawdź, czy kontekst jest nadal prawidłowy przed użyciem
          if (GoRouter.of(context).routerDelegate.navigatorKey.currentContext != null) {
            context.go('/');
          }
        }
      } catch (e) {
        if (mounted) {
          await showErrorDialog(context, 'Błąd zapisu danych', 'Wystąpił błąd zapisu danych: ${e.toString()}');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false; // Zakończ ładowanie
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        // Tło z gradientem, analogiczne do LoginScreen
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
            padding: const EdgeInsets.all(24.0), // Padding wokół karty
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450), // Ograniczenie szerokości karty
              child: Card(
                elevation: 8.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0), // Wewnętrzny padding karty
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Aby karta dopasowała się do zawartości
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Logo - opcjonalnie, można dodać nad tytułem
                        SizedBox(
                          height: 80, // Dostosuj wysokość logo
                          child: const Image(
                            fit: BoxFit.contain, // Użyj contain dla lepszego dopasowania
                            image: AssetImage('icons/Icon-192.png'), // Upewnij się, że asset istnieje
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        Text(
                          'Uzupełnij swoje dane', // Tytuł analogiczny do LoginScreen
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Wprowadź swoją nazwę użytkownika, abyśmy mogli Cię lepiej poznać.', // Podtytuł/instrukcja
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32.0),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nazwa użytkownika',
                            hintText: 'np. Jan Kowalski',
                            prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nazwa użytkownika jest wymagana.';
                            }
                            if (value.trim().length < 3) {
                              return 'Nazwa musi mieć co najmniej 3 znaki.';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_isLoading) {
                              _saveUserData(context);
                            }
                          },
                        ),
                        const SizedBox(height: 24.0),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          onPressed: () {
                            _saveUserData(context);
                          },
                          child: const Text('Zapisz i kontynuuj'),
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
