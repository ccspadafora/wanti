import '../../../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String idType,
    required String idNumber,
    required String phone,
    required String city,
  }) {
    return _api.post(
      '/auth/register/',
      auth: false,
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'id_type': idType,
        'id_number': idNumber.replaceAll(RegExp(r'[.\s-]'), ''),
        'phone': phone.replaceAll(' ', ''),
        'city': city,
      },
    );
  }

  Future<({String access, String refresh, UserModel user})> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/login/',
      auth: false,
      body: {'email': email, 'password': password},
    );
    final user = UserModel.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    return (
      access: data['access'].toString(),
      refresh: data['refresh'].toString(),
      user: user,
    );
  }

  Future<UserModel> me() async {
    final data = await _api.get('/users/me/');
    return UserModel.fromJson(data);
  }

  Future<void> verifyEmail(String token) async {
    await _api.post('/auth/verify-email/', auth: false, body: {'token': token});
  }

  Future<String?> resendEmailVerification() async {
    final data = await _api.post('/auth/resend-email-verification/');
    return data['debug_email_token']?.toString();
  }

  Future<String?> requestOtp({String channel = 'WHATSAPP'}) async {
    final data = await _api.post('/auth/otp/request/', body: {'channel': channel});
    return data['debug_code']?.toString();
  }

  Future<UserModel> verifyOtp(String code) async {
    final data = await _api.post('/auth/otp/verify/', body: {'code': code});
    final me = await this.me();
    return me.copyWith(
      phoneVerifiedAt: data['phone_verified_at']?.toString() ?? me.phoneVerifiedAt,
      isFullyVerified: data['is_fully_verified'] == true || me.isFullyVerified,
      status: data['status']?.toString() ?? me.status,
    );
  }

  Future<void> logout(String? refresh) async {
    if (refresh != null) {
      try {
        await _api.post('/auth/logout/', body: {'refresh': refresh});
      } catch (_) {}
    }
    await _api.clearTokens();
  }

  Future<UserModel> updateProfile({
    String? fullName,
    String? city,
    String? profilePhotoUrl,
  }) async {
    final body = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (city != null) 'city': city,
      if (profilePhotoUrl != null) 'profile_photo_url': profilePhotoUrl,
    };
    final data = await _api.patch('/users/me/', body: body);
    return UserModel.fromJson(data);
  }

  Future<String> changeEmail({
    required String newEmail,
    required String password,
  }) async {
    final data = await _api.post(
      '/users/me/change-email/',
      body: {'new_email': newEmail, 'password': password},
    );
    return data['detail']?.toString() ?? 'Enviamos un correo de confirmación';
  }

  Future<({String detail, String? debugCode})> changePhone({
    required String newPhone,
    required String password,
    String channel = 'WHATSAPP',
  }) async {
    final data = await _api.post(
      '/users/me/change-phone/',
      body: {
        'new_phone': newPhone.replaceAll(' ', ''),
        'password': password,
        'channel': channel,
      },
    );
    return (
      detail: data['detail']?.toString() ?? 'Enviamos un OTP al nuevo número',
      debugCode: data['debug_code']?.toString(),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/users/me/change-password/',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  Future<String?> requestPasswordReset(String email) async {
    final data = await _api.post(
      '/auth/password/reset-request/',
      auth: false,
      body: {'email': email.trim()},
    );
    return data['debug_token']?.toString();
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/password/reset-confirm/',
      auth: false,
      body: {'token': token, 'new_password': newPassword},
    );
  }
}
