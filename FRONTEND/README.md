# Wanti App (Flutter)

App móvil del reverse marketplace Wanti.

## Requisitos

- Flutter 3.38+
- Backend corriendo en `http://127.0.0.1:8000` (ver `BACKEND/`)

## Correr

```bash
cd FRONTEND
flutter pub get

# iOS Simulator / macOS
flutter run

# Android Emulator (usa 10.0.2.2 automáticamente)
flutter run

# Dispositivo físico en la misma red
flutter run --dart-define=API_BASE_URL=http://192.168.1.X:8000
```

## Pantallas

- Welcome, Crear cuenta, Iniciar sesión
- Confirmar email, OTP celular, Cuenta verificada
- Home (necesidades activas)
- Publicar necesidad (3 pasos)

En **DEBUG** local, el backend devuelve `debug_email_token` y `debug_code` para completar verificación sin Twilio/email real.
