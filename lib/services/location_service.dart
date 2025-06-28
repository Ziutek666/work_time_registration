import 'package:geolocator/geolocator.dart';

/// Serwis do obsługi funkcji związanych z lokalizacją.
class LocationService {
  /// Określa aktualną pozycję urządzenia.
  ///
  /// Gdy usługi lokalizacyjne nie są włączone lub uprawnienia
  /// są odrzucone, zostanie rzucony `Exception` z komunikatem dla użytkownika.
  static Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Sprawdź, czy usługi lokalizacyjne są włączone na urządzeniu.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Usługi lokalizacyjne są wyłączone. Proszę włączyć GPS.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Odmówiono uprawnień do lokalizacji. Nie można pobrać pozycji.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Uprawnienia są trwale odrzucone.
      return Future.error(
          'Uprawnienia do lokalizacji zostały trwale odrzucone. Proszę włączyć je w ustawieniach aplikacji.');
    }

    // Gdy uprawnienia są przyznane, pobierz pozycję.
    return await Geolocator.getCurrentPosition();
  }
}