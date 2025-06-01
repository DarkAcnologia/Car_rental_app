// Заглушка для отключения входа через Apple

class SignInWithApple {
  static Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    List<dynamic>? scopes,
    String? nonce,
  }) async {
    throw UnimplementedError('Apple Sign-In is disabled in this build.');
  }
}

class AppleIDAuthorizationScopes {
  static const email = 'email';
  static const fullName = 'fullName';
}

class AuthorizationCredentialAppleID {
  final String identityToken;
  final String authorizationCode;
  final String? email;
  final String? givenName;
  final String? familyName;

  AuthorizationCredentialAppleID({
    required this.identityToken,
    required this.authorizationCode,
    this.email,
    this.givenName,
    this.familyName,
  });
}
