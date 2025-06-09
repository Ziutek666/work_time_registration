import 'dart:async';
import 'dart:io'; // Potrzebne dla typu File
import 'dart:typed_data'; // Potrzebne dla Uint8List
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Import dla kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import dla ImagePicker
import '../../services/user_auth_service.dart'; // Upewnij się, że ścieżka jest poprawna
import '../../widgets/dialogs.dart'; // Upewnij się, że ścieżka jest poprawna
import 'package:go_router/go_router.dart';

class EditUserScreen extends StatefulWidget {
  const EditUserScreen({super.key});
  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<User?>? _idTokenSubscription;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {});
      }
    });
    _idTokenSubscription = FirebaseAuth.instance.idTokenChanges().listen((User? user) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _idTokenSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleChangePhoto() async {
    // Zmniejszenie jakości obrazu może pomóc zredukować rozmiar pliku
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image != null) {
      debugPrint('Image picked: path: ${image.path}, name: ${image.name}, mimeType: ${image.mimeType}');
      if (!mounted) return;
      // Wyświetl dialog ładowania
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      try {
        if (kIsWeb) {
          debugPrint('Platform is Web. Reading bytes...');
          final Uint8List imageBytes = await image.readAsBytes();
          debugPrint('Bytes read (${imageBytes.length} bytes). Calling updatePhotoURLAndUpload for Web with fileName: ${image.name}');
          await userAuthService.updatePhotoURLAndUpload(
            imageBytes: imageBytes,
            fileName: image.name,
          );
        } else {
          debugPrint('Platform is Mobile/Desktop. Creating File from path: ${image.path}');
          await userAuthService.updatePhotoURLAndUpload(
            imageFile: File(image.path),
            fileName: image.name,
          );
        }
        debugPrint('Photo upload process finished successfully in _handleChangePhoto.');

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Zamknij dialog ładowania
          await showSuccessDialog(context,'Zdjęcie profilowe', '✅ Zdjęcie profilowe zostało zaktualizowane.');
          setState(() {}); // Odśwież UI, aby pokazać nowe zdjęcie
        }
      } catch (e) {
        debugPrint('Error in _handleChangePhoto: ${e.toString()}');
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          await showErrorDialog(context, "Błąd zmiany zdjęcia", '❌ Nie udało się zaktualizować zdjęcia: ${e.toString()}');
        }
      }
    } else {
      debugPrint('No image selected.');
    }
  }


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final currentUser = userAuthService.currentUser; // Pobierz aktualnego użytkownika

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/'); // Domyślna nawigacja, jeśli nie można wrócić
            }
          },
        ),
        title: Text(
          'Konto użytkownika',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Wyloguj",
            onPressed: () async {
              await _logOut(context);
            },
          ),
        ],
      ),
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
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 8.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: _userDataOptions(currentUser),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _userDataOptions(User? currentUser) {
    final String currentDisplayName = currentUser?.displayName ?? 'Brak nazwy';
    final String currentUserEmail = currentUser?.email ?? 'Brak adresu email';
    final String? currentPhotoURL = currentUser?.photoURL;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _handleChangePhoto,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                backgroundImage: currentPhotoURL != null && currentPhotoURL.isNotEmpty
                    ? NetworkImage(currentPhotoURL)
                    : null,
                child: currentPhotoURL == null || currentPhotoURL.isEmpty
                    ? Icon(
                  Icons.person_outline,
                  size: 50,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
                    : null,
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.edit, size: 20, color: Colors.white),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          currentDisplayName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        Text(
          currentUserEmail,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        _buildUserDataOption(
          context: context,
          icon: Icons.photo_camera_outlined,
          title: 'Zmień zdjęcie profilowe',
          onTap: _handleChangePhoto,
        ),
        const SizedBox(height: 12),
        _buildUserDataOption(
          context: context,
          icon: Icons.badge_outlined,
          title: 'Zmień nazwę użytkownika',
          onTap: () async {
            await _showUpdateNameDialog(context);
          },
        ),
        const SizedBox(height: 12),
        _buildUserDataOption(
          context: context,
          icon: Icons.email_outlined,
          title: 'Zmień adres email',
          onTap: () async {
            await _showUpdateEmailDialog(context);
          },
        ),
        const SizedBox(height: 12),
        _buildUserDataOption(
          context: context,
          icon: Icons.lock_reset_outlined,
          title: 'Zresetuj hasło',
          onTap: () async {
            var email = userAuthService.currentUser?.email;
            if (email != null) {
              try {
                await userAuthService.sendPasswordResetEmail(email);
                if (mounted) await showSuccessDialog(context,'Reset hasła', '✅ Wysłano e-mail do zmiany hasła na adres $email');
              } catch (e) {
                if (mounted) await showErrorDialog(context, "Błąd wysyłania", '❌ Błąd wysyłania e-maila: ${e.toString()}');
              }
            } else {
              if (mounted) await showErrorDialog(context, "Brak adresu email", 'Nie można wysłać linku do resetowania hasła, ponieważ adres e-mail nie jest znany.');
            }
          },
        ),
      ],
    );
  }

  Widget _buildUserDataOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    IconData actionIcon = Icons.arrow_forward_ios_rounded,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Card(
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary, size: 26),
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        trailing: Icon(actionIcon, size: 20, color: colorScheme.primary.withOpacity(0.8)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    );
  }

  Future<void> _logOut(BuildContext context) async {
    await userAuthService.signOut();
    if (mounted) {
      if (GoRouter.of(context).routerDelegate.navigatorKey.currentContext != null) {
        context.go('/auth');
      }
    }
  }

  Future<void> _showUpdateNameDialog(BuildContext context) async {
    final nameController = TextEditingController(text: userAuthService.currentUser?.displayName ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Zmień nazwę użytkownika'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nowa nazwa',
                hintText: 'Wpisz nową nazwę użytkownika',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nazwa nie może być pusta.';
                }
                if (value.trim().length < 3) {
                  return 'Nazwa musi mieć co najmniej 3 znaki.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Anuluj'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Zapisz'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final displayName = nameController.text.trim();
                  try {
                    await userAuthService.updateDisplayName(displayName);
                    if (mounted) {
                      Navigator.of(dialogContext).pop();
                      await showSuccessDialog(context,'Nazwa użytkownika', '✅ Zmieniono nazwę użytkownika.');
                    }
                  } catch (e) {
                    if (mounted) {
                      await showErrorDialog(dialogContext, "Błąd zmiany nazwy", '❌ Nie udało się zmienić nazwy: ${e.toString()}');
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showUpdateEmailDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: userAuthService.currentUser?.email ?? '');

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Zmień adres email'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Nowy email',
                hintText: 'Wpisz nowy adres email',
                border: OutlineInputBorder(),
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
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Anuluj'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Zapisz'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newEmail = emailController.text.trim();
                  if (newEmail == userAuthService.currentUser?.email) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nowy adres e-mail jest taki sam jak obecny.'))
                    );
                    return;
                  }
                  try {
                    await userAuthService.updateEmail(newEmail);
                    if (mounted) {
                      Navigator.of(dialogContext).pop();
                      await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext alertContext) => AlertDialog(
                          title: const Text('Weryfikacja nowego adresu email'),
                          content: Text('Na adres $newEmail został wysłany link weryfikacyjny. Proszę potwierdzić nowy adres e-mail, a następnie zalogować się ponownie, aby zmiany zostały zastosowane.'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('OK, wyloguj mnie'),
                              onPressed: () async {
                                Navigator.of(alertContext).pop();
                                await _logOut(context);
                              },
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      await showErrorDialog(dialogContext, "Błąd zmiany emaila", '❌ Nie udało się zmienić adresu e-mail: ${e.toString()}');
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}