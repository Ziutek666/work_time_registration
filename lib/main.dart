import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Import dla lokalizacji
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'firebase_options.dart'; // Plik generowany przez FlutterFire CLI
import 'router/app_router.dart'; // Założenie, że ten plik istnieje i konfiguruje appRouter

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  WidgetsFlutterBinding.ensureInitialized();

  // ZMIANA: Inicjalizacja danych o strefach czasowych
  tz.initializeTimeZones();
  // Opcjonalnie, ale to dobra praktyka - ustawienie domyślnej lokalnej strefy czasowej
  tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));

  // Initialize App Check!
  const reCaptchaV3SiteKey = '6LfYi24rAAAAACNrcPILqXEvdklRvawgX_typzux';
  await FirebaseAppCheck.instance.activate(
    // Set the appropriate provider for the web platform (using your reCAPTCHA site key)
    webProvider: ReCaptchaV3Provider(reCaptchaV3SiteKey),

    // Set the provider for Android. Play Integrity is generally recommended for production.
    // During development, you might use AndroidProvider.debug initially.
    androidProvider: AndroidProvider.playIntegrity,

    // Set the provider for Apple platforms (iOS/macOS). App Attest is more secure where available.
    // During development, you might use AppleProvider.debug initially.
    appleProvider: AppleProvider.appAttest,
  );

  // Inicjalizacja formatowania dat dla języka polskiego
  await initializeDateFormatting('pl_PL', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Użycie GoogleFonts do zastosowania czcionki Inter w całym motywie
    final textTheme = Theme
        .of(context)
        .textTheme;
    final interTextTheme = GoogleFonts.interTextTheme(textTheme);

    return MaterialApp.router(
      routerConfig: appRouter,
      // Zakładając, że appRouter jest poprawnie skonfigurowany
      title: 'Rejestracja Czasu Pracy',
      // Zmieniono tytuł na bardziej opisowy

      // --- KONFIGURACJA LOKALIZACJI ---
      locale: const Locale('pl', 'PL'),
      // Ustawienie domyślnego języka na polski
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        // Teraz powinno być zdefiniowane
        GlobalWidgetsLocalizations.delegate,
        // Teraz powinno być zdefiniowane
        GlobalCupertinoLocalizations.delegate,
        // Teraz powinno być zdefiniowane
        // Tutaj możesz dodać własne delegaty lokalizacji dla tekstów specyficznych dla aplikacji
      ],
      supportedLocales: const [
        Locale('pl', 'PL'), // Polski
        Locale('en', 'US'), // Angielski (jako przykład, jeśli potrzebny)
        // Dodaj inne języki, które wspiera Twoja aplikacja
      ],
      // --- KONIEC KONFIGURACJI LOKALIZACJI ---

      theme: ThemeData(
        primarySwatch: Colors.indigo,
        // Możesz zostawić lub użyć ColorScheme
        fontFamily: GoogleFonts
            .inter()
            .fontFamily,
        // Ustawienie domyślnej rodziny czcionek
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light, // Możesz dostosować jasność
        ),
        textTheme: interTextTheme,
        // Zastosowanie motywu tekstowego Inter
        useMaterial3: true,
        appBarTheme: AppBarTheme( // Spójny styl AppBar
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          titleTextStyle: interTextTheme.titleLarge?.copyWith(
              color: Colors.white, fontWeight: FontWeight.bold),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        dialogTheme: DialogTheme( // Spójny styl dla dialogów
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0)),
          titleTextStyle: interTextTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold),
        ),
        cardTheme: CardTheme( // Spójny styl dla kart
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        inputDecorationTheme: InputDecorationTheme( // Spójny styl dla pól wprowadzania
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData( // Spójny styl dla przycisków
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            )
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            )
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}