// models/app_data.dart

import 'package:flutter/material.dart';

import 'information_category.dart';

class AppData {
  final String appTitle = 'work time register';
  final double appWidth = 500.0;
  final double iconSizeSmall = 20.0;
  final double iconSizeMedium = 30.0;
  final double iconSizeBig = 40.0;
// Przykładowa lista dostępnych ról. W rzeczywistej aplikacji może pochodzić z konfiguracji.
  final List<String> availableProjectRoles = ['ADMINISTRATOR', 'PRACOWNIK', 'KIEROWNIK', 'OBSERWATOR'];
  final List<Color> colorsList = [
    Colors.amber,
    Colors.grey,
    const Color.fromARGB(255, 92, 92, 92),
    Colors.black54,
    Colors.black,
    ...Colors.primaries,
  ];
  final List<IconData> iconsList = [
    Icons.clear,
    Icons.notifications_active_outlined,
    Icons.door_sliding_outlined,
    Icons.garage_outlined,
    Icons.key,
    Icons.sensor_door_outlined,
    Icons.alarm,
    Icons.lightbulb,
    Icons.light,
    Icons.arrow_circle_up_outlined,
    Icons.arrow_circle_down_outlined,
    Icons.arrow_circle_left_outlined,
    Icons.arrow_circle_right_outlined,
    Icons.wb_twilight_sharp,
    Icons.lock_open,
    Icons.lock_outline,
    Icons.camera_outdoor,
    Icons.bathroom,
    Icons.camera_alt_outlined,
    Icons.wifi,
    Icons.logo_dev,
    Icons.build,
    Icons.shopify,
    Icons.directions_bike,
    Icons.electric_bike,
    Icons.motorcycle,
    Icons.local_shipping,
    Icons.email,
    Icons.data_thresholding,
    Icons.verified_user,
    Icons.manage_accounts,
    Icons.calendar_month,
    Icons.home,
    Icons.airplane_ticket,
    Icons.perm_identity,
    Icons.camera_indoor,
    Icons.camera_outdoor,
    Icons.account_balance_wallet,
    Icons.door_back_door,
    Icons.lock_outline,
    Icons.contact_mail,
    Icons.attachment_outlined,
    Icons.diamond,
    Icons.cloud,
    Icons.miscellaneous_services,
    Icons.sailing,
    Icons.moving,
    Icons.fiber_dvr,
    Icons.fiber_pin,
    Icons.phone_android,
    Icons.security,
    Icons.moving,
    Icons.sell,
    Icons.apartment,
    Icons.grass,
    Icons.house,
    Icons.doorbell_outlined,
    Icons.password,
  ];


  AppData();

  int getNumbersOfIcons() => iconsList.length;
  IconData getIconData(int index) => iconsList[index];
  Color getColor(int index) => colorsList[index];
  int getNumbersOfColors() => colorsList.length;
}

final appData = AppData(); // Globalna instancja dla dostępu do stałych danych