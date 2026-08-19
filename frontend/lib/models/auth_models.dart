/// User model representing a user in the system.
class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final bool isActive;
  final bool isVerified;
  final bool isGuest;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.isActive,
    required this.isVerified,
    required this.isGuest,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      isActive: json['is_active'] as bool,
      isVerified: json['is_verified'] as bool,
      isGuest: json['is_guest'] as bool,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'is_active': isActive,
      'is_verified': isVerified,
      'is_guest': isGuest,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get fullName => '$firstName $lastName';
}

/// Token pair returned by authentication endpoints.
class TokenPair {
  final String accessToken;
  final String refreshToken;
  final User? user;

  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    this.user,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? '',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      if (user != null) 'user': user!.toJson(),
    };
  }
}

class RegistrationResult {
  final bool verificationRequired;

  const RegistrationResult({
    required this.verificationRequired,
  });

  factory RegistrationResult.fromJson(Map<String, dynamic> json) {
    return RegistrationResult(
      verificationRequired: json['verification_required'] as bool? ?? true,
    );
  }
}

/// Login request payload.
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) {
    return LoginRequest(
      email: json['email'] as String,
      password: json['password'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

/// Registration request payload.
class RegisterRequest {
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  const RegisterRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) {
    return RegisterRequest(
      email: json['email'] as String,
      password: json['password'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
    };
  }
}

/// Refresh token request payload.
class RefreshTokenRequest {
  final String refreshToken;

  const RefreshTokenRequest({
    required this.refreshToken,
  });

  factory RefreshTokenRequest.fromJson(Map<String, dynamic> json) {
    return RefreshTokenRequest(
      refreshToken: json['refresh_token'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'refresh_token': refreshToken,
    };
  }
}

/// Password reset request payload.
class PasswordResetRequest {
  final String email;

  const PasswordResetRequest({
    required this.email,
  });

  factory PasswordResetRequest.fromJson(Map<String, dynamic> json) {
    return PasswordResetRequest(
      email: json['email'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
    };
  }
}

/// Password reset confirm request payload.
class PasswordResetConfirmRequest {
  final String token;
  final String newPassword;

  const PasswordResetConfirmRequest({
    required this.token,
    required this.newPassword,
  });

  factory PasswordResetConfirmRequest.fromJson(Map<String, dynamic> json) {
    return PasswordResetConfirmRequest(
      token: json['token'] as String,
      newPassword: json['new_password'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'new_password': newPassword,
    };
  }
}

/// Update user request payload.
class UpdateUserRequest {
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  const UpdateUserRequest({
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  factory UpdateUserRequest.fromJson(Map<String, dynamic> json) {
    return UpdateUserRequest(
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }
}

/// Change password request payload.
class ChangePasswordRequest {
  final String oldPassword;
  final String newPassword;

  const ChangePasswordRequest({
    required this.oldPassword,
    required this.newPassword,
  });

  factory ChangePasswordRequest.fromJson(Map<String, dynamic> json) {
    return ChangePasswordRequest(
      oldPassword: json['old_password'] as String,
      newPassword: json['new_password'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'old_password': oldPassword,
      'new_password': newPassword,
    };
  }
}

/// Convert guest request payload.
class ConvertGuestRequest {
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  const ConvertGuestRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  factory ConvertGuestRequest.fromJson(Map<String, dynamic> json) {
    return ConvertGuestRequest(
      email: json['email'] as String,
      password: json['password'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
    };
  }
}

/// Claim account request payload.
class ClaimAccountRequest {
  final String password;
  final String firstName;
  final String lastName;

  const ClaimAccountRequest({
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  factory ClaimAccountRequest.fromJson(Map<String, dynamic> json) {
    return ClaimAccountRequest(
      password: json['password'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
    };
  }
}
