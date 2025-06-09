import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/user_auth_service.dart'; // Upewnij się, że ten import jest poprawny
import '../../widgets/dialogs.dart'; // Upewnij się, że ten import jest poprawny

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false;


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Rejestracja użytkownika
  Future<void> _register() async {
    FocusScope.of(context).unfocus(); // Schowaj klawiaturę
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        await userAuthService.registerWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        context.go('/');
      } catch (e) {
        if (mounted) {
          await showErrorDialog(context, 'Błąd Rejestracji', 'Wystąpił błąd rejestracji: ${e.toString()}');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // Opcjonalnie: można pokazać SnackBar zamiast zmieniać _hidePassword
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Proszę poprawić błędy w formularzu.')),
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      // AppBar dla przycisku powrotu, jeśli jest potrzebny
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Przezroczysty AppBar
        elevation: 0, // Usuń cień
      ),
      extendBodyBehindAppBar: true, // Aby tło gradientowe było widoczne pod AppBar
      body: Container(
        // Tło z gradientem, analogiczne do UserCreateDataScreen
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
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Logo - opcjonalnie
                        SizedBox(
                          height: 80,
                          child: const Image(
                            fit: BoxFit.contain,
                            image: AssetImage('icons/Icon-192.png'), // Upewnij się, że asset istnieje
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        Text(
                          'Utwórz nowe konto',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Dołącz do nas, wypełniając poniższy formularz.',
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32.0),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Adres e-mail',
                            hintText: 'ty@example.com',
                            prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email jest wymagany';
                            }
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value)) {
                              return 'Nieprawidłowy adres email';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 20.0),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          decoration: InputDecoration(
                            labelText: 'Hasło',
                            hintText: 'Minimum 6 znaków',
                            prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: colorScheme.primary.withOpacity(0.7),
                              ),
                              onPressed: () {
                                setState(() {
                                  _hidePassword = !_hidePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Hasło jest wymagane';
                            }
                            if (value.length < 6) {
                              return 'Hasło musi mieć co najmniej 6 znaków.';
                            }
                            if (_confirmPasswordController.text.isNotEmpty && value != _confirmPasswordController.text) {
                              return 'Hasła muszą być jednakowe';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 20.0),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _hideConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Potwierdź hasło',
                            hintText: 'Wpisz hasło ponownie',
                            prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _hideConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: colorScheme.primary.withOpacity(0.7),
                              ),
                              onPressed: () {
                                setState(() {
                                  _hideConfirmPassword = !_hideConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Potwierdzenie hasła jest wymagane';
                            }
                            if (value != _passwordController.text) {
                              return 'Hasła muszą być jednakowe';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_isLoading) {
                              _register();
                            }
                          },
                        ),
                        const SizedBox(height: 32.0),
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
                          onPressed: _register,
                          child: const Text('Zarejestruj się'),
                        ),
                        const SizedBox(height: 16.0),
                        TextButton(
                          onPressed: _isLoading ? null : () {
                            GoRouter.of(context).go('/auth'); // Przejdź do ekranu logowania
                          },
                          child: Text(
                            'Masz już konto? Zaloguj się',
                            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
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