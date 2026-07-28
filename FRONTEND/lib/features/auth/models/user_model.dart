class UserModel {
  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.status,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
    this.isFullyVerified = false,
    this.canPublish = false,
    this.role = 'USER',
    this.profilePhotoUrl,
    this.ratingAverage,
  });

  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String city;
  final String status;
  final String? emailVerifiedAt;
  final String? phoneVerifiedAt;
  final bool isFullyVerified;
  final bool canPublish;
  final String role;
  final String? profilePhotoUrl;
  final double? ratingAverage;

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName : parts.first;
  }

  String get maskedPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return phone;
    final last = digits.substring(digits.length - 4);
    final prefix = phone.startsWith('+') ? phone.split(' ').first : '+57';
    return '$prefix *** $last';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      emailVerifiedAt: json['email_verified_at']?.toString(),
      phoneVerifiedAt: json['phone_verified_at']?.toString(),
      isFullyVerified: json['is_fully_verified'] == true,
      canPublish: json['can_publish'] == true,
      role: json['role']?.toString() ?? 'USER',
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      ratingAverage: double.tryParse(json['rating_average']?.toString() ?? ''),
    );
  }

  UserModel copyWith({
    String? email,
    String? fullName,
    String? phone,
    String? city,
    String? emailVerifiedAt,
    String? phoneVerifiedAt,
    bool? isFullyVerified,
    bool? canPublish,
    String? status,
    String? profilePhotoUrl,
    double? ratingAverage,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      status: status ?? this.status,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      isFullyVerified: isFullyVerified ?? this.isFullyVerified,
      canPublish: canPublish ?? this.canPublish,
      role: role,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      ratingAverage: ratingAverage ?? this.ratingAverage,
    );
  }
}
