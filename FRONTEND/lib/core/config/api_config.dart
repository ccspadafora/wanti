import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Producción EC2. Override con --dart-define=API_BASE_URL=...
  static const productionBaseUrl = 'http://67.202.17.248';

  /// OneSignal App ID. Override con --dart-define=ONESIGNAL_APP_ID=...
  /// Vacío = push desactivado en el cliente.
  static const oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    // Release en dispositivo físico: servidor remoto (10.0.2.2 solo sirve en emulador).
    if (kReleaseMode) return productionBaseUrl;
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static String get apiV1 => '$baseUrl/api/v1';
}
