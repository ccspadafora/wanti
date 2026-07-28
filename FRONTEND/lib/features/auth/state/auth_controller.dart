import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../models/user_model.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required ApiClient api,
    required AuthRepository repository,
  })  : _api = api,
        _repo = repository {
    _api.onRefreshNeeded = () => _api.refreshAccessToken();
  }

  final ApiClient _api;
  final AuthRepository _repo;

  UserModel? user;
  bool loading = true;
  String? pendingEmailToken;
  String? pendingOtpCode;
  String? lastPassword;

  bool get isAuthenticated => _api.hasSession && user != null;
  bool get needsEmailVerification =>
      user != null && user!.emailVerifiedAt == null;
  bool get needsPhoneVerification =>
      user != null &&
      user!.emailVerifiedAt != null &&
      user!.phoneVerifiedAt == null;

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();
    await _api.loadTokens();
    if (_api.hasSession) {
      try {
        user = await _repo.me();
      } catch (_) {
        await _api.clearTokens();
        user = null;
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String idType,
    required String idNumber,
    required String phone,
    required String city,
  }) async {
    final reg = await _repo.register(
      email: email,
      password: password,
      fullName: fullName,
      idType: idType,
      idNumber: idNumber,
      phone: phone,
      city: city,
    );
    pendingEmailToken = reg['debug_email_token']?.toString();
    lastPassword = password;
    final login = await _repo.login(email: email, password: password);
    await _api.saveTokens(access: login.access, refresh: login.refresh);
    user = login.user;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _repo.login(email: email, password: password);
    await _api.saveTokens(access: result.access, refresh: result.refresh);
    user = result.user;
    try {
      user = await _repo.me();
    } catch (_) {}
    lastPassword = password;
    notifyListeners();
  }

  Future<void> verifyEmail({String? token}) async {
    final t = token ?? pendingEmailToken;
    if (t == null || t.isEmpty) {
      throw ApiException(
        message: 'No hay token de verificación. Tocá "Reenviar enlace".',
      );
    }
    await _repo.verifyEmail(t);
    user = await _repo.me();
    pendingEmailToken = null;
    notifyListeners();
  }

  Future<void> resendEmail() async {
    pendingEmailToken = await _repo.resendEmailVerification();
    notifyListeners();
  }

  Future<void> requestOtp({String channel = 'WHATSAPP'}) async {
    pendingOtpCode = await _repo.requestOtp(channel: channel);
    notifyListeners();
  }

  Future<void> verifyOtp(String code) async {
    user = await _repo.verifyOtp(code);
    pendingOtpCode = null;
    notifyListeners();
  }

  Future<void> refreshMe() async {
    user = await _repo.me();
    notifyListeners();
  }

  Future<void> updateProfile({
    String? fullName,
    String? city,
    String? profilePhotoUrl,
  }) async {
    user = await _repo.updateProfile(
      fullName: fullName,
      city: city,
      profilePhotoUrl: profilePhotoUrl,
    );
    notifyListeners();
  }

  Future<String> changeEmail({
    required String newEmail,
    required String password,
  }) {
    return _repo.changeEmail(newEmail: newEmail, password: password);
  }

  Future<({String detail, String? debugCode})> changePhone({
    required String newPhone,
    required String password,
  }) {
    return _repo.changePhone(newPhone: newPhone, password: password);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _repo.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    lastPassword = newPassword;
  }

  Future<void> logout() async {
    await _repo.logout(_api.refreshToken);
    user = null;
    pendingEmailToken = null;
    pendingOtpCode = null;
    lastPassword = null;
    notifyListeners();
  }
}
