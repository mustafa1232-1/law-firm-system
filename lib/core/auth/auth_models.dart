class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.roles,
    this.firmId,
  });

  final String id;
  final String email;
  final List<String> roles;
  final String? firmId;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['sub'] ?? json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      roles: ((json['roles'] as List?) ?? const []).map((e) => e.toString()).toList(),
      firmId: json['firmId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sub': id,
      'email': email,
      'roles': roles,
      'firmId': firmId,
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
      user: AuthUser.fromJson((json['user'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }
}

class AuthState {
  const AuthState({
    required this.isBootstrapping,
    required this.isSubmitting,
    required this.session,
    required this.errorMessage,
  });

  final bool isBootstrapping;
  final bool isSubmitting;
  final AuthSession? session;
  final String? errorMessage;

  bool get isAuthenticated => session != null;

  AuthState copyWith({
    bool? isBootstrapping,
    bool? isSubmitting,
    AuthSession? session,
    bool clearSession = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      session: clearSession ? null : (session ?? this.session),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  static const initial = AuthState(
    isBootstrapping: true,
    isSubmitting: false,
    session: null,
    errorMessage: null,
  );
}
