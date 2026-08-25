import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';

/// Push via OneSignal. Sin App ID (dart-define) queda desactivado.
class PushService {
  PushService(this._api);

  final ApiClient _api;
  bool _initialized = false;
  String? _boundUserId;
  void Function(Map<String, dynamic> data)? onNotificationOpened;

  static String get appId => ApiConfig.oneSignalAppId;

  bool get isConfigured => appId.isNotEmpty;

  Future<void> initialize() async {
    if (_initialized || !isConfigured) return;
    try {
      OneSignal.Debug.setLogLevel(kDebugMode ? OSLogLevel.verbose : OSLogLevel.warn);
      OneSignal.initialize(appId);
      OneSignal.Notifications.addClickListener((event) {
        final raw = event.notification.additionalData;
        if (raw == null || onNotificationOpened == null) return;
        onNotificationOpened!(Map<String, dynamic>.from(raw));
      });
      await OneSignal.Notifications.requestPermission(true);
      _initialized = true;
    } catch (e, st) {
      debugPrint('OneSignal init failed: $e\n$st');
    }
  }

  /// Vincula el usuario autenticado (external_id = UUID) y registra el subscription id.
  Future<void> bindUser(String userId) async {
    if (!isConfigured) return;
    await initialize();
    if (!_initialized) return;
    if (_boundUserId == userId) return;
    try {
      await OneSignal.login(userId);
      _boundUserId = userId;
      await _registerSubscription(userId);
    } catch (e, st) {
      debugPrint('OneSignal login failed: $e\n$st');
    }
  }

  Future<void> unbindUser() async {
    if (!isConfigured || !_initialized) return;
    try {
      await OneSignal.logout();
    } catch (_) {}
    _boundUserId = null;
  }

  Future<void> _registerSubscription(String userId) async {
    final subId = OneSignal.User.pushSubscription.id;
    if (subId == null || subId.isEmpty) return;
    final platform = Platform.isIOS
        ? 'IOS'
        : Platform.isAndroid
            ? 'ANDROID'
            : 'WEB';
    try {
      await _api.post(
        '/notifications/device-tokens/',
        body: {
          'token': subId,
          'platform': platform,
          'device_id': userId,
        },
      );
    } catch (e) {
      debugPrint('Device token register failed: $e');
    }
  }

  /// Rutas sugeridas según payload del backend.
  static String? routeForPayload(Map<String, dynamic> data) {
    final matchId = data['match_id']?.toString();
    if (matchId != null && matchId.isNotEmpty) {
      return '/home?tab=alerts';
    }
    final needId = data['need_id']?.toString();
    if (needId != null && needId.isNotEmpty) {
      return '/home?needId=$needId';
    }
    final unlockId = data['unlock_id']?.toString();
    if (unlockId != null && unlockId.isNotEmpty) {
      return '/contacts/$unlockId';
    }
    final disputeId = data['dispute_id']?.toString();
    if (disputeId != null && disputeId.isNotEmpty) {
      return '/disputes/$disputeId';
    }
    return '/notifications';
  }
}
