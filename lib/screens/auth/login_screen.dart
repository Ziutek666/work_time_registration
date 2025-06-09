import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Nadal potrzebne dla FirebaseAuthException
import 'package:go_router/go_router.dart'; // Import GoRouter do nawigacji
import '../../exceptions/auth_exceptions.dart';
import '../../services/user_auth_service.dart'; // Import Twoich niestandardowych wyjątków

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _message = '';
  bool _isLoading = false;

  // Instancja Twojego serwisu
  final UserAuthService _authService = userAuthService; // Użycie globalnej instancji

  // Walidacja emaila
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Proszę podać adres e-mail.';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return 'Proszę podać poprawny adres e-mail.';
    }
    return null;
  }

  // Walidacja hasła
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Proszę podać hasło.';
    }
    if (value.length < 6) {
      return 'Hasło musi mieć co najmniej 6 znaków.';
    }
    return null;
  }

  Future<void> _submitLoginForm() async {
    FocusScope.of(context).unfocus(); // Schowaj klawiaturę
    setState(() {
      _message = '';
    });

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        // Logowanie za pomocą UserAuthService
        await _authService.signInWithEmailAndPassword(email, password);
        context.pushReplacement('/');
      } on AuthException catch (e) { // Przechwytywanie Twojego niestandardowego wyjątku
        if (mounted) {
          setState(() {
            _message = e.message;
          });
        }
      } on FirebaseAuthException catch (e) { // Przechwytywanie wyjątków Firebase
        String errorMessage;
        switch (e.code) {
          case 'user-not-found':
          case 'INVALID_LOGIN_CREDENTIALS':
            errorMessage = 'Nie znaleziono użytkownika lub nieprawidłowe hasło.';
            break;
          case 'wrong-password': // Starszy kod, może nadal występować
            errorMessage = 'Nieprawidłowe hasło.';
            break;
          case 'invalid-email':
            errorMessage = 'Adres e-mail jest nieprawidłowy.';
            break;
          default:
            errorMessage = 'Wystąpił błąd logowania: ${e.message}';
        }
        if (mounted) {
          setState(() {
            _message = errorMessage;
          });
        }
      } catch (e) { // Ogólne błędy
        if (mounted) {
          setState(() {
            _message = 'Wystąpił nieoczekiwany błąd: ${e.toString()}';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _message = 'Proszę poprawić błędy w formularzu.';
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (_validateEmail(email) != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aby zresetować hasło, wpisz najpierw poprawny adres e-mail w polu e-mail.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    _message = '';

    try {
      print('Resetting password for email: $email');
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link do resetowania hasła został wysłany na Twój e-mail (jeśli konto istnieje).'), backgroundColor: Colors.green),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _message = e.message);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _message = 'Błąd resetowania hasła: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Wystąpił nieoczekiwany błąd podczas resetowania hasła. ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
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
            child: Card(
              elevation: 8.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
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
                        'Witaj z powrotem!',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        'Zaloguj się, aby kontynuować.',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32.0),

                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Adres e-mail',
                          hintText: 'ty@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20.0),

                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Hasło',
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: _validatePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _isLoading ? null : _submitLoginForm(),
                      ),
                      const SizedBox(height: 12.0),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          child: const Text('Zapomniałeś hasła?'),
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      if (_message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            _message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                        onPressed: _submitLoginForm,
                        child: const Text('Zaloguj się'),
                      ),
                      const SizedBox(height: 20.0),

                      TextButton(
                        onPressed: _isLoading ? null : () {
                          // Nawigacja do ekranu rejestracji
                          GoRouter.of(context).go('/registration');
                        },
                        child: const Text('Nie masz konta? Zarejestruj się'),
                      ),
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
